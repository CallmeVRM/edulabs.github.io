cd ~/guac-proxy
mkdir -p app nginx

cd ~/guac-proxy/app
npm init -y
npm install guacamole-common-js
cp node_modules/guacamole-common-js/all.min.js .

index.html
<!DOCTYPE html>
<html lang="fr">
<head>
  <meta charset="utf-8">
  <title>Portail Labs</title>
  <style>
    body { display: flex; height: 100vh; margin: 0; font-family: sans-serif; }
    #left { width: 25%; padding: 1em; border-right: 1px solid #ccc; background: #f9f9f9; }
    #right { flex: 1; display: flex; flex-direction: column; }
    #tabs { display: flex; background: #eee; border-bottom: 1px solid #ccc; }
    #tabs button { padding: 0.5em 1em; border: none; background: #ddd; cursor: pointer; }
    #tabs button.active { background: #bbb; }
    #terminals { flex: 1; position: relative; background: black; }
    .terminal { position: absolute; top:0; left:0; right:0; bottom:0; display:none; }
    .terminal.active { display:block; }
  </style>
</head>
<body>
  <div id="left">
    <h2>Consignes</h2>
    <ol>
      <li>Connexion en SSH</li>
      <li>Exécuter les commandes demandées</li>
      <li>Valider le résultat</li>
    </ol>
    <button id="loginBtn">Se connecter avec guacadmin</button>
    <div id="status"></div>
  </div>

  <div id="right">
    <div id="tabs"></div>
    <div id="terminals"></div>
  </div>

  <!-- Notre copie locale de la lib -->
  <script src="all.min.js"></script>
  <script>
    const API = "/guacamole/api";
    let token = null;

    async function login(username, password) {
      const resp = await fetch(API + "/tokens", {
        method: "POST",
        body: new URLSearchParams({username, password})
      });
      if (!resp.ok) throw new Error("Échec login");
      const data = await resp.json();
      token = data.authToken;
      return data;
    }

    async function getConnections() {
      const resp = await fetch(API + "/session/data/mysql/connections?token=" + token);
      if (!resp.ok) throw new Error("Impossible de récupérer les connexions");
      return await resp.json();
    }

    function openConnection(connId, name) {
      const tunnel = new Guacamole.WebSocketTunnel(
        "/guacamole/websocket-tunnel?token=" + token +
        "&GUAC_DATA_SOURCE=mysql&GUAC_ID=" + connId
      );
      const client = new Guacamole.Client(tunnel);

      const termDiv = document.createElement("div");
      termDiv.className = "terminal";
      termDiv.appendChild(client.getDisplay().getElement());
      document.getElementById("terminals").appendChild(termDiv);

      const tabBtn = document.createElement("button");
      tabBtn.textContent = name;
      tabBtn.onclick = () => {
        document.querySelectorAll(".terminal").forEach(t => t.classList.remove("active"));
        document.querySelectorAll("#tabs button").forEach(b => b.classList.remove("active"));
        termDiv.classList.add("active");
        tabBtn.classList.add("active");
      };
      document.getElementById("tabs").appendChild(tabBtn);

      if (document.querySelectorAll(".terminal").length === 1) tabBtn.click();

      client.connect();
      window.addEventListener("beforeunload", () => client.disconnect());
    }

    document.getElementById("loginBtn").onclick = async () => {
      const status = document.getElementById("status");
      status.textContent = "Connexion en cours...";
      try {
        await login("guacadmin", "guacadmin");
        const conns = await getConnections();
        if (Object.keys(conns).length === 0) {
          status.textContent = "⚠️ Aucun environnement disponible.";
          return;
        }
        status.textContent = "✅ Connexion réussie.";
        Object.values(conns).forEach(c => openConnection(c.identifier, c.name));
      } catch (err) {
        console.error(err);
        status.textContent = "❌ Erreur : " + err.message;
      }
    };
  </script>
</body>
</html>


## ~/guac-proxy/nginx/nginx.conf :
worker_processes auto;
events { worker_connections 1024; }

http {
  map $http_upgrade $connection_upgrade {
    default upgrade;
    ''      close;
  }

  upstream guacamole_backend {
    server host.containers.internal:8080;
    keepalive 32;
  }

  server {
    listen 80;
    server_name azlabs.edulabs.fr;

    # Portail personnalisé
    location /app/ {
      root /usr/share/nginx/html;
      index index.html;
      try_files $uri $uri/ =404;
    }

    # Guacamole standard
    location / {
      proxy_pass http://guacamole_backend/guacamole/;
      proxy_http_version 1.1;
      proxy_set_header Host              $host;
      proxy_set_header X-Real-IP         $remote_addr;
      proxy_set_header X-Forwarded-For   $proxy_add_x_forwarded_for;
      proxy_set_header X-Forwarded-Proto $scheme;
    }

    # Websocket Guacamole
    location /websocket-tunnel {
      proxy_pass http://guacamole_backend/guacamole/websocket-tunnel;
      proxy_http_version 1.1;
      proxy_set_header Upgrade    $http_upgrade;
      proxy_set_header Connection $connection_upgrade;
      proxy_set_header Host              $host;
      proxy_set_header X-Real-IP         $remote_addr;
      proxy_set_header X-Forwarded-For   $proxy_add_x_forwarded_for;
      proxy_set_header X-Forwarded-Proto $scheme;
    }
  }
}

