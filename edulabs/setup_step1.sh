#!/usr/bin/env bash
set -euo pipefail

info()  { echo -e "[INFO] $*"; }
ok()    { echo -e "[ OK ] $*"; }
warn()  { echo -e "[WARN] $*"; }
fail()  { echo -e "[FAIL] $*"; exit 1; }

require_root() {
  if [[ "${EUID}" -ne 0 ]]; then
    fail "Ce script doit être lancé en root (ou via sudo)."
  fi
}

require_apt() {
  if ! command -v apt-get >/dev/null 2>&1; then
    fail "Gestionnaire APT non détecté. Ciblez Debian 12/Ubuntu 22.04."
  fi
}

ensure_pkg() {
  local pkgs=("$@")
  info "Installation des paquets requis: ${pkgs[*]}"
  export DEBIAN_FRONTEND=noninteractive
  apt-get update -qq
  apt-get install -y --no-install-recommends "${pkgs[@]}"
}

ensure_group() {
  local g="$1"
  if getent group "$g" >/dev/null 2>&1; then
    ok "Groupe déjà présent: $g"
  else
    info "Création du groupe: $g"
    groupadd "$g"
  fi
}

ensure_dir() {
  local path="$1" owner="$2" mode="$3"
  mkdir -p "$path"
  chown "$owner" "$path"
  chmod "$mode" "$path"
  ok "Répertoire: $path (owner=$owner, mode=$mode)"
}

ensure_line_in_file() {
  local line="$1" file="$2"
  touch "$file"
  grep -qxF "$line" "$file" || echo "$line" >> "$file"
}

smoke_test_acl() {
  info "Vérification rapide ACL (setfacl/getfacl)"
  if ! command -v setfacl >/dev/null 2>&1; then
    fail "setfacl introuvable — paquet 'acl' manquant ?"
  fi
  local f="/tmp/.acltestfile.$$"
  : >"$f"
  if setfacl -m u:root:rw "$f" 2>/dev/null; then
    setfacl -b "$f" || true
    rm -f "$f"
    ok "ACL opérationnelles."
  else
    rm -f "$f"
    fail "Le système de fichiers ne supporte pas les ACL (ou montage sans ACL)."
  fi
}

main() {
  require_root
  require_apt

  ensure_pkg acl sudo tree jq git vim zip tar openssh-server

  # Groupes de l’entreprise + futurs besoins
  local groups=(marketing dev hr ops com sftp-ext)
  for g in "${groups[@]}"; do ensure_group "$g"; done

  # Arborescence de travail
  ensure_dir /srv root:root 0755
  ensure_dir /srv/depts root:root 0755
  for g in marketing dev hr ops; do
    ensure_dir "/srv/depts/$g" "root:$g" 0750
    ensure_dir "/srv/depts/$g/share" "root:$g" 0770
  done

  ensure_dir /srv/projects root:root 0755
  for p in siteweb apimobile dataviz; do
    ensure_dir "/srv/projects/$p" root:dev 0775
  done

  # Squelette utilisateur
  mkdir -p /etc/skel/Documents
  ensure_line_in_file "alias ll='ls -alF'" /etc/skel/.bash_aliases

  # Structure du lab
  ensure_dir /opt/labs root:root 0755
  ensure_dir /opt/labs/bin root:root 0755
  ensure_dir /opt/labs/tickets root:root 0755
  if [[ ! -f /opt/labs/README.md ]]; then
    cat > /opt/labs/README.md <<'MD'
# Lab Linux — Structure

- `tickets/` : tickets du Sprint en cours (fichiers Markdown).
- `bin/` : scripts utilitaires (`check_*`, `audit_*`, etc.).

**Étape 1** installe paquets, groupes, arborescence, squelette.
Les ACL/setgid/sudo seront gérés par les tickets suivants.
MD
    ok "README créé: /opt/labs/README.md"
  else
    ok "README déjà présent: /opt/labs/README.md"
  fi

  smoke_test_acl
  ok "Étape 1 terminée."
}

main "$@"