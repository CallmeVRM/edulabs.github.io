#!/usr/bin/env bash
set -euo pipefail


RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
pass() { echo -e "${GREEN}[PASS]${NC} $*"; }
fail() { echo -e "${RED}[FAIL]${NC} $*"; exit 1; }
warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }


need_cmd() { command -v "$1" >/dev/null 2>&1 || fail "Commande manquante: $1"; }
check_pkg() { dpkg -s "$1" >/dev/null 2>&1 && pass "Paquet installé: $1" || fail "Paquet absent: $1"; }
check_group() { getent group "$1" >/dev/null 2>&1 && pass "Groupe OK: $1" || fail "Groupe manquant: $1"; }
check_dir() {
local path="$1" owner_exp="$2" mode_exp="$3"
[[ -d "$path" ]] || fail "Répertoire manquant: $path"
local stat_out owner mode
stat_out=$(stat -c '%U:%G %a' "$path")
owner=$(awk '{print $1}' <<<"$stat_out")
mode=$(awk '{print $2}' <<<"$stat_out")
[[ "$owner" == "$owner_exp" ]] || fail "Owner $path = $owner (attendu: $owner_exp)"
[[ "$mode" == "$mode_exp" ]] || fail "Mode $path = $mode (attendu: $mode_exp)"
pass "Répertoire OK: $path (owner=$owner_exp, mode=$mode_exp)"
}


main() {
need_cmd stat; need_cmd getent; need_cmd dpkg; need_cmd setfacl || fail "Commande manquante: setfacl"


for p in acl sudo tree jq git vim zip tar; do 
  if ! dpkg -s "$p" >/dev/null 2>&1; then
	warn "Paquet absent: $p. Installation recommandée."
for g in marketing dev hr ops com sftp-ext; do 
  if ! getent group "$g" >/dev/null 2>&1; then
	warn "Groupe manquant: $g. Création recommandée."
  else
	pass "Groupe OK: $g"
  fi
done
	pass "Paquet installé: $p"
  fi
done


for g in marketing dev hr ops com sftp-ext; do check_group "$g"; done


check_dir /srv root:root 755
check_dir /srv/depts root:root 755
check_dir /srv/depts/marketing root:marketing 750
check_dir /srv/depts/marketing/share root:marketing 750
check_dir /srv/depts/dev root:dev 750
check_dir /srv/depts/dev/share root:dev 750
check_dir /srv/depts/hr root:hr 750
check_dir /srv/depts/hr/share root:hr 750
check_dir /srv/depts/ops root:ops 750
check_dir /srv/depts/ops/share root:ops 750


check_dir /srv/projects root:root 755
check_dir /srv/projects/siteweb root:dev 755
check_dir /srv/projects/apimobile root:dev 755
check_dir /srv/projects/dataviz root:dev 755


[[ -d /etc/skel/Documents ]] && pass "/etc/skel/Documents présent" || fail "/etc/skel/Documents manquant"
[[ -f /etc/skel/.bash_aliases && $(grep -c "alias ll='ls -alF'" /etc/skel/.bash_aliases || true) -ge 1 ]] \
&& pass "/etc/skel/.bash_aliases contient alias ll" \
|| fail "/etc/skel/.bash_aliases incomplet"


[[ -d /opt/labs/tickets ]] && pass "/opt/labs/tickets présent" || fail "/opt/labs/tickets manquant"
[[ -d /opt/labs/bin ]] && pass "/opt/labs/bin présent" || fail "/opt/labs/bin manquant"


echo -e "${GREEN}Tous les tests Étape 1 sont PASS.${NC}"
}


main "$@"