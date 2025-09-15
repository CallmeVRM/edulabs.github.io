const $ = (sel, root = document) => root.querySelector(sel);

const state = { user: null, catalog: [], status: {} };

async function api(path, opts = {}) {
    const res = await fetch(path, {
        credentials: 'same-origin',
        headers: { 'Content-Type': 'application/json' },
        ...opts,
        body: opts.body ? JSON.stringify(opts.body) : undefined
    });
    if (!res.ok) throw new Error((await res.json().catch(() => ({}))).error || `${res.status}`);
    return res.json();
}

async function checkSession() {
    const { user } = await api('/api/me');
    state.user = user;
    renderHeader();
    if (user) {
        $('#loginSection').classList.add('hidden');
        await loadDashboard();
    } else {
        $('#loginSection').classList.remove('hidden');
    }
}

function renderHeader() {
    const box = $('#userBox');
    if (!state.user) { box.innerHTML = ''; return; }
    box.innerHTML = `
    <span>Connecté : <strong>${state.user.username}</strong></span>
    <button id="logoutBtn" class="btn-gradient">Se déconnecter</button>
  `;
    $('#logoutBtn').onclick = async () => {
        await api('/api/logout', { method: 'POST' });
        location.reload();
    };
}

async function loadDashboard() {
    const cat = await api('/api/catalog');
    state.catalog = cat.labs || [];
    await refreshStatus();
    $('#labsSection').classList.remove('hidden');
}

// ✅ mise à jour partielle, pas de flicker
async function refreshStatus() {
    const st = await api('/api/labs/status');
    state.status = st.status || {};

    state.catalog.forEach(lab => {
        const card = document.querySelector(`[data-lab-key="${lab.key}"]`);
        const info = state.status[lab.key] || { status: 'idle' };

        if (!card) return; // la card n’existe pas encore

        const statusLabel = {
            running: 'En cours',
            idle: 'À l’arrêt',
            deleting: 'Suppression…',
            error: 'Erreur'
        }[info.status] || info.status;

        const stEl = card.querySelector('.lab-status');
        stEl.textContent = statusLabel;
        stEl.className = `lab-status status status--${info.status || 'idle'}`;

        card.querySelector('.lab-ip').innerHTML = info.ip
            ? `<i class="ri-global-line"></i>${info.ip}`
            : '';
        card.querySelector('.lab-exp').innerHTML = info.expires_at
            ? `<i class="ri-time-line"></i>${new Date(info.expires_at).toLocaleString()}`
            : '';
    });

    // si cards pas créées → render initial
    if (!document.querySelector('[data-lab-key]')) {
        renderLabs();
    }
}

function renderLabs() {
    const grid = $('#labsGrid');
    grid.innerHTML = '';
    const tmpl = $('#labCardTmpl');

    if (!state.catalog || state.catalog.length === 0) {
        grid.innerHTML = `<p class="msg">⚠️ Aucun lab disponible</p>`;
        return;
    }

    state.catalog.forEach(lab => {
        const node = tmpl.content.firstElementChild.cloneNode(true);
        node.setAttribute("data-lab-key", lab.key);

        const info = state.status[lab.key] || { status: 'idle' };
        const st = info.status || 'idle';

        const statusLabel = {
            running: 'En cours',
            idle: 'À l’arrêt',
            deleting: 'Suppression…',
            error: 'Erreur'
        }[st] || st;

        node.querySelector('.lab-title').textContent = lab.title;
        const stEl = node.querySelector('.lab-status');
        stEl.textContent = statusLabel;
        stEl.className = `lab-status status status--${st}`;

        node.querySelector('.lab-ip').innerHTML = info.ip ? `<i class="ri-global-line"></i>${info.ip}` : '';
        node.querySelector('.lab-exp').innerHTML = info.expires_at ? `<i class="ri-time-line"></i>${new Date(info.expires_at).toLocaleString()}` : '';

        // boutons
        const btnStart = node.querySelector('.btn-start');
        const btnStop = node.querySelector('.btn-stop');
        const btnOpen = node.querySelector('.btn-open');
        const msg = node.querySelector('.lab-msg');

        const setBusy = (busy) => [btnStart, btnStop, btnOpen].forEach(b => b.disabled = !!busy);

        btnStart.onclick = async () => {
            setBusy(true); msg.textContent = '';
            try {
                await api(`/api/labs/${lab.key}/start`, { method: 'POST', body: { durationMinutes: 60 } });
                msg.textContent = 'Lab démarré';
                await refreshStatus();
            } catch (e) { msg.textContent = 'Erreur: ' + e.message; }
            finally { setBusy(false); }
        };

        btnStop.onclick = async () => {
            setBusy(true); msg.textContent = '';
            try {
                await api(`/api/labs/${lab.key}/stop`, { method: 'POST' });
                msg.textContent = 'Arrêt demandé';
                await refreshStatus();
            } catch (e) { msg.textContent = 'Erreur: ' + e.message; }
            finally { setBusy(false); }
        };

        btnOpen.onclick = async () => {
            setBusy(true); msg.textContent = '';
            try {
                const { url } = await api(`/api/labs/${lab.key}/open`);
                if (url) window.open(url, '_blank');
                else msg.textContent = 'URL non disponible';
            } catch (e) { msg.textContent = 'Erreur: ' + e.message; }
            finally { setBusy(false); }
        };

        grid.appendChild(node);
    });
}

// login
$('#loginForm').addEventListener('submit', async (e) => {
    e.preventDefault();
    const fd = new FormData(e.currentTarget);
    const username = fd.get('username');
    const password = fd.get('password');
    const out = $('#loginMsg');
    out.textContent = '';
    try {
        const { user } = await api('/api/login', { method: 'POST', body: { username, password } });
        if (user) await checkSession();
    } catch { out.textContent = 'Identifiants invalides'; }
});

// boot
checkSession();
setInterval(refreshStatus, 10000); // refresh doux toutes les 10s
