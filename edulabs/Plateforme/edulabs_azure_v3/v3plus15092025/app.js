// app.js — Backend Express (auth + UI API) — appelle l'orchestrateur existant
import 'dotenv/config';
import express from 'express';
import session from 'express-session';
import bcrypt from 'bcrypt';
import Database from 'better-sqlite3';
import path from 'path';
import { fileURLToPath } from 'url';
import morgan from 'morgan';
import helmet from 'helmet';

// ==== Guacamole REST helpers ====
const GUAC_API_BASE = process.env.GUAC_API_BASE || 'http://192.168.1.19:8080/guacamole';
const GUAC_DS = process.env.GUAC_DS || 'mysql';
const GUAC_ADMIN_USER = process.env.GUAC_ADMIN_USER;
const GUAC_ADMIN_PASS = process.env.GUAC_ADMIN_PASS;
const GUAC_USER_PASS = process.env.GUAC_USER_PASS || 'student123!';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

// ----------------------- Config -----------------------
const PORT = process.env.PORT || 4000;
const SESSION_SECRET = process.env.SESSION_SECRET || 'dev-secret-change-me';
const ORCH_URL = process.env.ORCH_URL || 'http://localhost:3000';
const GUAC_URL = process.env.GUAC_URL || 'http://localhost:8080/guacamole';


// ----------- supprimer la connexion Guac Helper--------------
async function guacDeleteConnection(connectionId) {
    const { token, cookie } = await guacAdminLogin();
    const r = await fetch(`${GUAC_API_BASE}/api/session/data/${GUAC_DS}/connections/${connectionId}?token=${token}`, {
        method: 'DELETE',
        headers: { Cookie: cookie }
    });
    if (!r.ok && r.status !== 404) {
        throw new Error(`Guac delete connection failed ${r.status}`);
    }
}

// ----------------------- DB ---------------------------
const db = new Database(path.join(__dirname, 'db.sqlite'));
db.exec(`
  PRAGMA journal_mode=WAL;
  CREATE TABLE IF NOT EXISTS users (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    username TEXT UNIQUE NOT NULL,
    password_hash TEXT NOT NULL,
    role TEXT NOT NULL DEFAULT 'user'
  );
  CREATE TABLE IF NOT EXISTS lab_instances (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    username TEXT NOT NULL,
    lab_key TEXT NOT NULL,
    lab_id TEXT,
    ip TEXT,
    status TEXT NOT NULL DEFAULT 'idle',
    expires_at TEXT,
    created_at TEXT NOT NULL DEFAULT (datetime('now')),
    UNIQUE(username, lab_key)
  );
`);

// ----------------------- Seed Users -------------------
const seedUser = (username, password, role = 'user') => {
    const exists = db.prepare('SELECT 1 FROM users WHERE username = ?').get(username);
    if (!exists) {
        const hash = bcrypt.hashSync(password, 10);
        db.prepare('INSERT INTO users (username, password_hash, role) VALUES (?, ?, ?)').run(username, hash, role);
        console.log(`[seed] user créé: ${username} (${role})`);
    }
};
seedUser(process.env.ADMIN_USER || 'admin', process.env.ADMIN_PASS || 'admin123', 'admin');
seedUser('student', 'student123', 'user');

const LAB_CATALOG = [
    { key: 'lab1', title: 'Lab 1 — Débian cplane' },
    { key: 'lab2', title: 'Lab 2 — App' },
    { key: 'lab3', title: 'Lab 3 — Backup' }
];
const ensureLabRowsForUser = (username) => {
    const insert = db.prepare('INSERT OR IGNORE INTO lab_instances (username, lab_key) VALUES (?, ?)');
    LAB_CATALOG.forEach(l => insert.run(username, l.key));
};

// ----------------------- App --------------------------
const app = express();
app.use(helmet());
app.use(morgan('tiny'));
app.use(express.json());
app.use(session({
    secret: SESSION_SECRET,
    resave: false,
    saveUninitialized: false,
    cookie: {
        httpOnly: true,
        sameSite: 'lax',
        secure: false
    }
}));

// Auth middleware
const requireAuth = (req, res, next) => {
    if (req.session?.user) return next();
    return res.status(401).json({ error: 'unauthorized' });
};

// ----------------------- Routes Auth ------------------
app.post('/api/login', async (req, res) => {
    const { username, password } = req.body || {};
    if (!username || !password) return res.status(400).json({ error: 'missing credentials' });

    const row = db.prepare('SELECT * FROM users WHERE username = ?').get(username);
    if (!row) return res.status(401).json({ error: 'invalid credentials' });

    const ok = await bcrypt.compare(password, row.password_hash);
    if (!ok) return res.status(401).json({ error: 'invalid credentials' });

    req.session.user = { username: row.username, role: row.role };
    ensureLabRowsForUser(row.username);
    res.json({ user: req.session.user });
});

app.get('/api/me', (req, res) => {
    if (!req.session?.user) return res.status(200).json({ user: null });
    res.json({ user: req.session.user });
});

app.post('/api/logout', (req, res) => {
    req.session.destroy(() => res.json({ ok: true }));
});

// ----------------------- Catalog & Status -------------
app.get('/api/catalog', requireAuth, (req, res) => {
    res.json({ labs: LAB_CATALOG });
});

app.get('/api/labs/status', requireAuth, async (req, res) => {
    const username = req.session.user.username;
    const rows = db.prepare(
        'SELECT id, lab_key, lab_id, ip, status, expires_at FROM lab_instances WHERE username = ?'
    ).all(username);

    let orchStatus = {};
    try {
        const resp = await fetch(`${ORCH_URL}/labs/status`);
        if (resp.ok) orchStatus = await resp.json();
    } catch (e) {
        console.warn("Orchestrator unreachable", e.message);
    }

    // Resync
    rows.forEach(r => {
        if (r.status === 'deleting' && (!orchStatus[r.lab_id] || orchStatus[r.lab_id].status === 'deleted')) {
            db.prepare(`
        UPDATE lab_instances 
        SET status='idle', lab_id=NULL, ip=NULL, expires_at=NULL 
        WHERE id=?
      `).run(r.id);
            r.status = 'idle';
            r.lab_id = null;
            r.ip = null;
            r.expires_at = null;
        }
    });

    const map = Object.fromEntries(rows.map(r => [r.lab_key, r]));
    res.json({ status: map });
});


// ----------------------- Actions Labs -----------------
app.post('/api/labs/:labKey/start', requireAuth, async (req, res) => {
    const { labKey } = req.params;
    const durationMinutes = Number(req.body?.durationMinutes) || 60;
    const username = req.session.user.username;

    const inst = db.prepare('SELECT * FROM lab_instances WHERE username = ? AND lab_key = ?').get(username, labKey);
    if (!inst) return res.status(404).json({ error: 'lab key not found' });
    if (inst.status === 'running') return res.status(409).json({ error: 'lab already running', lab_id: inst.lab_id });

    try {
        const resp = await fetch(`${ORCH_URL}/start`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ owner: username, durationMinutes })
        });
        if (!resp.ok) throw new Error(`orchestrator /start failed: ${resp.status}`);
        const data = await resp.json();

        db.prepare(`UPDATE lab_instances SET lab_id = ?, ip = ?, status = 'running', expires_at = ? WHERE id = ?`)
            .run(data.lab_id, data.ip, data.expires_at, inst.id);

        try {
            await guacEnsureUser({ username });
            let existing = await guacFindConnectionIdByName(data.lab_id);
            if (!existing) {
                existing = await guacCreateSshConnectionAndGrant({
                    connName: data.lab_id,
                    hostname: data.ip,
                    port: 22,
                    sshUser: 'student',
                    sshPass: 'Motdepassefort123!',
                    username
                });
                console.log(`[guac] connexion SSH créée: ${existing}`);
            } else {
                console.log(`[guac] connexion déjà existante: ${existing}`);
            }
        } catch (ge) {
            console.error(`[guac] erreur intégration:`, ge);
        }

        res.status(201).json({ ok: true, lab_id: data.lab_id, ip: data.ip, expires_at: data.expires_at });
    } catch (e) {
        console.error(e);
        res.status(502).json({ error: 'provisioning failed' });
    }
});

app.post('/api/labs/:labKey/stop', requireAuth, async (req, res) => {
    const { labKey } = req.params;
    const username = req.session.user.username;
    const inst = db.prepare('SELECT * FROM lab_instances WHERE username = ? AND lab_key = ?').get(username, labKey);
    if (!inst) return res.status(404).json({ error: 'lab key not found' });
    if (inst.status !== 'running' || !inst.lab_id) return res.status(409).json({ error: 'lab not running' });

    try {
        // Appel orchestrateur
        const resp = await fetch(`${ORCH_URL}/stop`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ lab_name: inst.lab_id })
        });
        if (!resp.ok) throw new Error(`orchestrator /stop failed: ${resp.status}`);

        // Supprimer la connexion Guac associée
        const connId = await guacFindConnectionIdByName(inst.lab_id);
        if (connId) {
            await guacDeleteConnection(connId);
            console.log(`[guac] Connexion supprimée pour lab_id=${inst.lab_id} (id=${connId})`);
        }

        // Réinitialiser l'entrée dans lab_instances
        db.prepare(`
      UPDATE lab_instances 
      SET status='idle', lab_id=NULL, ip=NULL, expires_at=NULL 
      WHERE id = ?
    `).run(inst.id);

        res.json({ ok: true, status: 'idle' });
    } catch (e) {
        console.error(e);
        res.status(502).json({ error: 'stop failed' });
    }
});




// ----------------------- OpenEnv ----------------------
app.get('/api/labs/:labKey/open', requireAuth, async (req, res) => {
    const { labKey } = req.params;
    const username = req.session.user.username;
    const inst = db.prepare(
        'SELECT * FROM lab_instances WHERE username = ? AND lab_key = ?'
    ).get(username, labKey);

    if (!inst || !inst.lab_id) {
        return res.status(404).json({ error: 'no active lab' });
    }

    try {
        // 1) Retrouver l'ID NUMÉRIQUE de la connexion Guacamole par son "name" (= lab_id)
        const connectionId = await guacFindConnectionIdByName(inst.lab_id);
        if (!connectionId) {
            console.error(`[open] aucune connexion Guac trouvée pour lab_id=${inst.lab_id}`);
            return res.status(404).json({ error: 'guac connection not found' });
        }

        // 2) Login Guacamole avec l'utilisateur courant (mot de passe synchro via guacEnsureUser)
        const params = new URLSearchParams();
        params.set('username', username);
        params.set('password', GUAC_USER_PASS);

        console.log(`[open] Tentative login Guac user=${username}, pass=${GUAC_USER_PASS}, connectionId=${connectionId}`);

        const resp = await fetch(`${GUAC_API_BASE}/api/tokens`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
            body: params
        });

        if (!resp.ok) {
            const errText = await resp.text();
            console.error(`[open] Guac user login failed ${resp.status}: ${errText}`);
            throw new Error(`Guac user login failed ${resp.status}`);
        }

        const data = await resp.json();

        // 3) Construire l'identifiant "client" attendu par l'UI Guacamole :
        //    base64( "<connectionId>\0c\0<datasource>" ) sans padding '='
        const clientId = guacClientIdFromConnectionId(connectionId, GUAC_DS);

        // 4) URL finale (NOTE: on passe l'IDENTIFIANT ENCODÉ, pas l'ID numérique brut)
        const url = `${GUAC_API_BASE}/#/client/${clientId}?token=${data.authToken}`;
        console.log(`[open] URL générée: ${url}`);

        res.json({ url });
    } catch (err) {
        console.error('[guac open] erreur', err);
        res.status(500).json({ error: 'open failed' });
    }
});

// Helper local : encoder l'identifiant "client" comme le fait l'UI Guacamole
function guacClientIdFromConnectionId(connectionId, datasource) {
    // "<id>\0c\0<datasource>"
    const raw = `${connectionId}\0c\0${datasource}`;
    // base64 sans padding
    return Buffer.from(raw, 'utf8').toString('base64').replace(/=+$/, '');
}






// ------------------ Guacamole Helpers -----------------
let guacAdminSession = null;

async function guacAdminLogin() {
    if (guacAdminSession && guacAdminSession.expires > Date.now()) return guacAdminSession;

    const params = new URLSearchParams();
    params.set('username', GUAC_ADMIN_USER);
    params.set('password', GUAC_ADMIN_PASS);

    const resp = await fetch(`${GUAC_API_BASE}/api/tokens`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
        body: params
    });
    if (!resp.ok) throw new Error(`Guac login failed ${resp.status}`);
    const data = await resp.json();

    guacAdminSession = {
        token: data.authToken,
        cookie: resp.headers.get('set-cookie') || '',
        expires: Date.now() + 10 * 60 * 1000
    };

    return guacAdminSession;
}

async function guacEnsureUser({ username }) {
    const { token, cookie } = await guacAdminLogin();
    let r = await fetch(`${GUAC_API_BASE}/api/session/data/${GUAC_DS}/users/${encodeURIComponent(username)}?token=${token}`, {
        headers: { Cookie: cookie }
    });
    if (r.status === 200) return;

    r = await fetch(`${GUAC_API_BASE}/api/session/data/${GUAC_DS}/users?token=${token}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json', Cookie: cookie },
        body: JSON.stringify({ username, password: GUAC_USER_PASS, attributes: {} })
    });
    if (!r.ok) throw new Error(`Guac create user failed ${r.status}`);
}

async function guacCreateSshConnectionAndGrant({ connName, hostname, port = 22, sshUser, sshPass, username }) {
    const { token, cookie } = await guacAdminLogin();

    let r = await fetch(`${GUAC_API_BASE}/api/session/data/${GUAC_DS}/connections?token=${token}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json', Cookie: cookie },
        body: JSON.stringify({
            name: connName,
            protocol: 'ssh',
            parameters: { hostname, port: String(port), username: sshUser, password: sshPass, "enable-sftp": "false", "ignore-cert": "true" },
            attributes: {}
        })
    });
    if (!r.ok) throw new Error(`Guac create connection failed ${r.status}`);
    const created = await r.json();
    const connectionId = created.identifier;

    r = await fetch(`${GUAC_API_BASE}/api/session/data/${GUAC_DS}/users/${encodeURIComponent(username)}/permissions?token=${token}`, {
        method: 'PATCH',
        headers: { 'Content-Type': 'application/json', Cookie: cookie },
        body: JSON.stringify([{ op: 'add', path: `/connectionPermissions/${connectionId}`, value: 'READ' }])
    });
    if (!r.ok) throw new Error(`Guac grant permission failed ${r.status}`);

    return connectionId;
}

async function guacFindConnectionIdByName(name) {
    const { token, cookie } = await guacAdminLogin();
    const r = await fetch(`${GUAC_API_BASE}/api/session/data/${GUAC_DS}/connections?token=${token}`, { headers: { Cookie: cookie } });
    if (!r.ok) throw new Error(`Guac list connections failed ${r.status}`);
    const list = await r.json();
    const connections = Object.values(list);
    const item = connections.find(c => c.name === name);
    return item?.identifier || null;
}

// ----------------------- Static Frontend --------------
app.use(express.static(path.join(__dirname, 'public')));
app.get('*', (req, res, next) => {
    if (req.path.startsWith('/api')) return next();
    res.sendFile(path.join(__dirname, 'public', 'index.html'));
});

// ----------------------- Start server -----------------
app.listen(PORT, () => {
    console.log(`UI backend lancé sur http://localhost:${PORT}`);
    console.log(`Orchestrateur attendu sur ${ORCH_URL}`);
});
