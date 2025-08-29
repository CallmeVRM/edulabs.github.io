// server.js – backend Express minimal pour le PoC “Start Lab”

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

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const PORT = process.env.PORT || 3000;
const LOCATION = process.env.AZURE_LOCATION || 'westeurope';
const PASSWORD = 'Motdepassefort123!';          // ⚠️ POC UNSAFE – voir README
const TEMPLATE = path.join(__dirname, 'template.bicep');
const LABS_DIR = path.join(__dirname, 'labs');
const DB_FILE = path.join(__dirname, 'labs.db');

// --- helpers ---------------------------------------------------------------

const db = new Database(DB_FILE);
db.exec(`
  CREATE TABLE IF NOT EXISTS labs (
    run_id      TEXT PRIMARY KEY,
    lab_id      TEXT,
    rg_name     TEXT,
    vm_name     TEXT,
    ip          TEXT,
    expires_at  TEXT,
    status      TEXT
  );
`);

const sanitizeOwner = (raw = '') =>
    (raw.toLowerCase().replace(/[^a-z0-9]/g, '').slice(0, 10)) || 'student';

function genRunId() {
    return crypto.randomBytes(4).toString('hex');   // 8 hex chars
}

// assure le dossier ./labs
fs.mkdirSync(LABS_DIR, { recursive: true });

// --- express ---------------------------------------------------------------

const app = express();
app.use(bodyParser.json());
app.use(morgan('tiny'));

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

        // 1. fichier params sécurisé
        const paramsFile = path.join(__dirname, `params-${run_id}.json`);
        fs.writeFileSync(
            paramsFile,
            JSON.stringify(
                {
                    adminUsername: { value: 'student' },
                    adminPassword: { value: PASSWORD },
                    vmName: { value: vm_name },
                    location: { value: LOCATION }
                },
                null,
                2
            )
        );

        // 2. Azure CLI – bloc sync (PoC : simple)
        console.log(`[${run_id}] creating resource-group ${rg_name}`);
        execSync(`az group create --name ${rg_name} --location ${LOCATION}`, {
            stdio: 'inherit'
        });

        console.log(`[${run_id}] deploying VM ${vm_name}`);
        execSync(
            `az deployment group create --resource-group ${rg_name} --template-file ${TEMPLATE} --parameters @${paramsFile}`,
            { stdio: 'inherit' }
        );

        // 3. récupération IP publique
        const ip = execSync(
            `az network public-ip show -g ${rg_name} -n ${vm_name}-pip --query ipAddress -o tsv`
        )
            .toString()
            .trim();

        // 4. YAML (sans mot de passe)
        const yamlObj = {
            lab_id,
            owner,
            status: 'running',
            expires_at: expires.toISOString(),
            resources: [
                {
                    name: 'cplane',
                    role: 'debian',
                    ip,
                    user: 'student',
                    secret_ref: 'shared'
                }
            ],
            created_at: new Date().toISOString()
        };
        const yamlPath = path.join(LABS_DIR, `${lab_id}.yaml`);
        fs.writeFileSync(yamlPath, yaml.dump(yamlObj));

        // 5. DB
        db.prepare(
            `INSERT INTO labs (run_id, lab_id, rg_name, vm_name, ip, expires_at, status)
       VALUES (?, ?, ?, ?, ?, ?, ?)`
        ).run(run_id, lab_id, rg_name, vm_name, ip, expires.toISOString(), 'running');

        res.status(201).json({ lab_id, ip, expires_at: expires.toISOString() });
    } catch (err) {
        console.error(err);
        res.status(500).json({ error: 'Provisioning failed – check backend logs.' });
    }
});

app.post('/stop', async (req, res) => {
    try {
        const lab = req.body.lab_name;
        const row = db
            .prepare('SELECT rg_name FROM labs WHERE lab_id = ?')
            .get(lab);
        if (!row) return res.status(404).json({ error: 'lab not found' });

        execSync(`az group delete --name ${row.rg_name} --yes --no-wait`, {
            stdio: 'inherit'
        });

        db.prepare('UPDATE labs SET status = ? WHERE lab_id = ?').run('deleting', lab);
        res.json({ status: 'deleting', rg: row.rg_name });
    } catch (err) {
        console.error(err);
        res.status(500).json({ error: 'Stop failed.' });
    }
});

app.get('/open/:lab', (req, res) => {
    const p = path.join(LABS_DIR, `${req.params.lab}.yaml`);
    if (!fs.existsSync(p)) return res.status(404).end('Lab YAML not found');
    res.setHeader('Content-Type', 'text/yaml');
    fs.createReadStream(p).pipe(res);
});

app.use(express.static(path.join(__dirname, 'public'))); // pour index.html

app.listen(PORT, () => {
    console.log(`Azure-Lab PoC listening on http://localhost:${PORT}`);
});