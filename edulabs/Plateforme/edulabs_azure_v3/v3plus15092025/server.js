// server.js – orchestrateur Azure (labs avec Bicep/CLI + auto-cleanup)

import express from 'express';
import bodyParser from 'body-parser';
import morgan from 'morgan';
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';
import { execSync } from 'child_process';
import crypto from 'crypto';
import Database from 'better-sqlite3';
import yaml from 'js-yaml';
import cron from 'node-cron';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

const PORT = process.env.PORT || 3000;
const LOCATION = process.env.AZURE_LOCATION || 'eastus';
const PASSWORD = 'Motdepassefort123!'; // ⚠️ à mettre dans un secret
const TEMPLATE = path.join(__dirname, 'template.bicep'); // ton ARM/Bicep JSON
const LABS_DIR = path.join(__dirname, 'labs');
const DB_FILE = path.join(__dirname, 'labs.db');

// ---------------------------------------------------------------------------
// SQLite
// ---------------------------------------------------------------------------
const db = new Database(DB_FILE);
db.exec(`
  CREATE TABLE IF NOT EXISTS labs (
    run_id     TEXT PRIMARY KEY,
    lab_id     TEXT,
    rg_name    TEXT,
    vm_name    TEXT,
    ip         TEXT,
    expires_at TEXT,
    status     TEXT
  );
  CREATE INDEX IF NOT EXISTS idx_expires ON labs(expires_at);
`);

fs.mkdirSync(LABS_DIR, { recursive: true });

// ---------------------------------------------------------------------------
// helpers
// ---------------------------------------------------------------------------
const sanitizeOwner = (raw = '') =>
    (raw.toLowerCase().replace(/[^a-z0-9]/g, '').slice(0, 10)) || 'student';

const genRunId = () => crypto.randomBytes(4).toString('hex');

function writeYaml(lab_id, data) {
    const p = path.join(LABS_DIR, `${lab_id}.yaml`);
    fs.writeFileSync(p, yaml.dump(data));
}

function rgExists(rg_name) {
    try {
        const out = execSync(`az group exists --name ${rg_name}`).toString().trim();
        return out === 'true';
    } catch {
        return false;
    }
}

// ---------------------------------------------------------------------------
// Express
// ---------------------------------------------------------------------------
const app = express();
app.use(bodyParser.json());
app.use(morgan('tiny'));

// ---------------------------------------------------------------------------
// Start lab (provision Azure)
// ---------------------------------------------------------------------------
app.post('/start', async (req, res) => {
    try {
        const ownerRaw = req.body.owner || 'student';
        const durationMinutes = Number(req.body.durationMinutes) || 60;

        const owner = sanitizeOwner(ownerRaw);
        const run_id = genRunId();
        const lab_id = `lab-${owner}-${run_id}`;
        const rg_name = `rg-${lab_id}`;
        const vm_name = `vm-${lab_id}-cplane`;

        const expires = new Date(Date.now() + durationMinutes * 60_000);

        const paramsFile = path.join(__dirname, `params-${run_id}.json`);
        fs.writeFileSync(paramsFile, JSON.stringify({
            adminUsername: { value: 'student' },
            adminPassword: { value: PASSWORD },
            vmName: { value: vm_name },
            location: { value: LOCATION }
        }, null, 2));

        console.log(`[${run_id}] creating RG ${rg_name}`);
        execSync(`az group create --name ${rg_name} --location ${LOCATION}`, { stdio: 'inherit' });

        console.log(`[${run_id}] deploying VM ${vm_name}`);
        execSync(
            `az deployment group create --resource-group ${rg_name} --template-file ${TEMPLATE} --parameters @${paramsFile}`,
            { stdio: 'inherit' }
        );

        const ip = execSync(
            `az network public-ip show -g ${rg_name} -n ${vm_name}-pip --query ipAddress -o tsv`
        ).toString().trim();

        const yamlObj = {
            lab_id,
            owner,
            status: 'running',
            expires_at: expires.toISOString(),
            resources: [
                { name: 'cplane', role: 'debian', ip, user: 'student', secret_ref: 'shared' }
            ],
            created_at: new Date().toISOString()
        };
        writeYaml(lab_id, yamlObj);

        db.prepare(
            `INSERT INTO labs (run_id, lab_id, rg_name, vm_name, ip, expires_at, status)
       VALUES (?, ?, ?, ?, ?, ?, ?)`
        ).run(run_id, lab_id, rg_name, vm_name, ip, expires.toISOString(), 'running');

        res.status(201).json({ lab_id, ip, expires_at: expires.toISOString() });
    } catch (err) {
        console.error(err);
        res.status(500).json({ error: 'Provisioning failed' });
    }
});

// ---------------------------------------------------------------------------
// Stop lab (delete RG)
// ---------------------------------------------------------------------------
app.post('/stop', (req, res) => {
    try {
        const lab = req.body.lab_name;
        const row = db.prepare('SELECT rg_name FROM labs WHERE lab_id = ?').get(lab);
        if (!row) return res.status(404).json({ error: 'lab not found' });

        execSync(`az group delete --name ${row.rg_name} --yes --no-wait`, { stdio: 'inherit' });
        db.prepare('UPDATE labs SET status = ? WHERE lab_id = ?').run('deleting', lab);

        res.json({ status: 'deleting', rg: row.rg_name });
    } catch (err) {
        console.error(err);
        res.status(500).json({ error: 'Stop failed' });
    }
});

// ---------------------------------------------------------------------------
// Debug: récupérer YAML interne
// ---------------------------------------------------------------------------
app.get('/open/:lab', (req, res) => {
    const p = path.join(LABS_DIR, `${req.params.lab}.yaml`);
    if (!fs.existsSync(p)) return res.status(404).end('Lab YAML not found');
    res.setHeader('Content-Type', 'text/yaml');
    fs.createReadStream(p).pipe(res);
});

// ---------------------------------------------------------------------------
// Cron cleanup (expiration + deletion verification)
// ---------------------------------------------------------------------------
cron.schedule('*/2 * * * *', () => {
    const now = new Date().toISOString();

    // Expirés → suppression
    const expired = db.prepare(
        `SELECT lab_id, rg_name FROM labs
     WHERE expires_at <= ? AND status = 'running'`
    ).all(now);

    expired.forEach(({ lab_id, rg_name }) => {
        try {
            console.log(`[cleanup] expiring lab ${lab_id}, deleting RG ${rg_name}`);
            execSync(`az group delete --name ${rg_name} --yes --no-wait`, { stdio: 'inherit' });
            db.prepare(`UPDATE labs SET status = 'deleting' WHERE lab_id = ?`).run(lab_id);
        } catch (err) {
            console.error(`[cleanup] échec suppression RG ${rg_name}`, err.message);
        }
    });

    // Labs en "deleting" → vérifier si RG encore existant
    const deleting = db.prepare(
        `SELECT lab_id, rg_name FROM labs WHERE status = 'deleting'`
    ).all();

    deleting.forEach(({ lab_id, rg_name }) => {
        if (!rgExists(rg_name)) {
            console.log(`[cleanup] RG ${rg_name} supprimé → purge DB`);
            db.prepare(`DELETE FROM labs WHERE lab_id = ?`).run(lab_id);

            const yamlPath = path.join(LABS_DIR, `${lab_id}.yaml`);
            if (fs.existsSync(yamlPath)) {
                const y = yaml.load(fs.readFileSync(yamlPath, 'utf8'));
                y.status = 'deleted';
                writeYaml(lab_id, y);
            }
        }
    });
});

// ---------------------------------------------------------------------------
// Lancement
// ---------------------------------------------------------------------------
app.listen(PORT, () => {
    console.log(`Orchestrateur Azure prêt sur http://localhost:${PORT}`);
});
