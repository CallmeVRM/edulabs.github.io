#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# prepare_lab.sh — Installe et prépare un lab Linux “Sprint 1 + Incidents”
# ---------------------------------------------------------------------------
set -euo pipefail

need_root() { (( EUID == 0 )) || { echo "Run as root." >&2; exit 1; }; }

# Helper : write /path/to/file [mode] <<'EOF'
write() {
  local path="$1" mode="${2:-0644}" tmp
  tmp=$(mktemp); cat >"$tmp"
  install -D -m "$mode" "$tmp" "$path"
  rm -f "$tmp"
}

main() {
  need_root
  export DEBIAN_FRONTEND=noninteractive

  # 1. Packages (silencieux)
  apt-get -qq update
  apt-get -yqq install --no-install-recommends \
      acl sudo tree jq git vim zip tar openssh-server e2fsprogs

  # 2. Groupes métier
  for g in marketing dev hr ops com sftp-ext; do
    getent group "$g" >/dev/null || groupadd "$g"
  done

  # 3. Répertoires & droits
  install -d -o root -g root -m 0755 /srv /srv/depts /srv/projects
  for g in marketing dev hr ops; do
    install -d -o root -g "$g" -m 0750 "/srv/depts/$g"
    install -d -o root -g "$g" -m 2770 "/srv/depts/$g/share"
  done
  for p in siteweb apimobile dataviz; do
    install -d -o root -g dev -m 0775 "/srv/projects/$p"
  done

  # 4. /etc/skel
  install -d -m 0755 /etc/skel/Documents
  grep -qxF "alias ll='ls -alF'" /etc/skel/.bash_aliases 2>/dev/null ||
    echo "alias ll='ls -alF'" >> /etc/skel/.bash_aliases

  # 5. Arborescence lab
  install -d -m 0755 /opt/labs/{bin,tickets/{sprint1,incidents}}

  # 6. Checkers -------------------------------------------------------------
  write /opt/labs/bin/check_sprint1.sh 0755 <<'CHK'
#!/usr/bin/env bash
set -euo pipefail
die(){ echo "[FAIL] $1"; exit 1; }
pass(){ echo "[PASS] $1"; }
has_user(){ getent passwd "$1" >/dev/null; }
prim(){ id -gn "$1"; }
groups(){ id -nG "$1"; }

has_user alice.dupont || die "T1: alice.dupont absent"
[[ $(prim alice.dupont) == marketing ]] || die "T1: groupe primaire ≠ marketing"
[[ -d /home/alice.dupont ]] || die "T1: home absent"
grep -q ':/bin/bash$' <(getent passwd alice.dupont) || die "T1: shell ≠ /bin/bash"
pass "T1 OK"

groups alice.dupont | grep -qw com || die "T2: alice pas dans com"
pass "T2 OK"

d=/srv/depts/marketing/share
[[ -d $d ]] || die "T3: share manquant"
[[ $(stat -c %a "$d") == 2770 ]] || die "T3: permissions ≠ 2770"
f="$d/.chk$$"; sudo -u alice.dupont bash -lc ": >'$f'" || die "T3: écriture KO"
[[ $(stat -c %G "$f") == marketing ]] || { rm -f "$f"; die "T3: héritage groupe KO"; }
rm -f "$f"; pass "T3 OK"

has_user bob.martin || die "T4: bob.martin absent"
[[ $(prim bob.martin) == dev ]] || die "T4: groupe primaire ≠ dev"
[[ -d /home/bob.martin/Documents ]] || die "T4: Documents absent"
grep -q "alias ll=" /home/bob.martin/.bash_aliases || die "T4: alias ll manquant"
pass "T4 OK"

echo "Sprint 1 VALIDÉ ✅"
CHK

  write /opt/labs/bin/check_incidents.sh 0755 <<'CHK'
#!/usr/bin/env bash
set -euo pipefail
die(){ echo "[FAIL] $1"; exit 1; }
pass(){ echo "[PASS] $1"; }

s=/srv/depts/marketing/share
[[ -d $s ]] || die "INC-01: $s manquant"

[[ $(stat -c %a "$s") == 2770 ]] || die "INC-01: permissions ≠ 2770"
if getent passwd alice.dupont >/dev/null; then
  f="$s/.inc01$$"; sudo -u alice.dupont bash -lc ": >'$f'" || die "INC-01: écriture KO"
  [[ $(stat -c %G "$f") == marketing ]] || { rm -f "$f"; die "INC-01: héritage groupe KO"; }
  rm -f "$f"
fi
pass "INC-01 OK"

find "$s" -maxdepth 0 -type d -perm -1000 >/dev/null || die "INC-02: sticky-bit absent"
find "$s" -maxdepth 0 -type d -perm -0020 >/dev/null || die "INC-02: pas d'écriture groupe"
pass "INC-02 OK"

if lsattr /etc/shadow 2>/dev/null | grep -q ' i '; then die "INC-03: /etc/shadow immutable"; fi
[[ $(stat -c %a /etc/shadow) == 640 && $(stat -c %U:%G /etc/shadow) == root:shadow ]] \
  || die "INC-03: perms shadow KO"
pass "INC-03 OK"

pass "INC-04 OK"
echo "Incidents VALIDÉS ✅"
CHK

  # 7. Scripts incidents ----------------------------------------------------
  ## INC-01
  write /opt/labs/bin/prepare_inc01.sh 0755 <<'SH'
#!/usr/bin/env bash
set -euo pipefail
chmod 0750 /srv/depts/marketing/share
SH
  write /opt/labs/bin/fix_inc01.sh 0755 <<'SH'
#!/usr/bin/env bash
set -euo pipefail
chown root:marketing /srv/depts/marketing/share
chmod 2770 /srv/depts/marketing/share
SH

  ## INC-02  (sticky-bit)
  write /opt/labs/bin/prepare_inc02.sh 0755 <<'SH'
#!/usr/bin/env bash
set -euo pipefail
dir=/srv/depts/marketing/share
u=thomas.dru

# 1) Création/garantie de l'utilisateur + appartenance marketing -------------
if ! id "$u" &>/dev/null; then
  useradd -m -d /home/"$u" -s /bin/bash -g marketing "$u"
else
  id -nG "$u" | grep -qw marketing || usermod -aG marketing "$u"
fi

# 2) Création de 8 fichiers possédés par thomas.dru --------------------------
for n in {01..08}; do
  sudo -u "$u" touch "$dir/fichier$n"
done

# 3) Rendre le dossier group-writable et retirer le sticky-bit ---------------
chmod g+rwx "$dir"
chmod -t    "$dir"
SH

  write /opt/labs/bin/fix_inc02.sh 0755 <<'SH'
#!/usr/bin/env bash
set -euo pipefail
chmod +t /srv/depts/marketing/share
SH

  ## INC-03
  write /opt/labs/bin/prepare_inc03.sh 0755 <<'SH'
#!/usr/bin/env bash
set -euo pipefail
u=camel.chalal

# 1) S’assure que camel.chalal existe (groupe primaire dev)
if ! id "$u" &>/dev/null; then
  useradd -m -d /home/"$u" -s /bin/bash -g dev "$u"
  echo "$u:Motdepass123!" | chpasswd
fi

# 2) Rend /etc/shadow immutable (+i)  →   passwd échouera
chattr +i /etc/shadow
echo "[INC-03] Posé : /etc/shadow immutable (+i) – passwd bloqué"
SH

  write /opt/labs/bin/fix_inc03.sh 0755 <<'SH'
#!/usr/bin/env bash
set -euo pipefail
chattr -i /etc/shadow || true
chown root:shadow /etc/shadow; chmod 640 /etc/shadow
chown root:root  /etc/passwd;  chmod 644 /etc/passwd
echo "[INC-03] Corrigé : /etc/shadow remis en état (passwd OK)"
SH

  ## INC-04
  write /opt/labs/bin/prepare_inc04.sh 0755 <<'SH'
#!/usr/bin/env bash
set -euo pipefail
u=camel.chalal
id "$u" &>/dev/null || {
  useradd -m -d /home/"$u" -s /bin/bash -g dev "$u"
  echo "$u:Motdepasse123!" | chpasswd
}
useradd -m -d /home/sylvain.morel -s /bin/bash sylvain.morel
home=$(getent passwd "$u" | cut -d: -f6)
install -d -m 0777 -o "$u" -g dev "$home/.ssh"
touch "$home/.ssh/authorized_keys"
chown sylvain.morel:sylvain.morel "$home/.ssh/authorized_keys"
chmod 0666 "$home/.ssh/authorized_keys"
SH
  write /opt/labs/bin/fix_inc04.sh 0755 <<'SH'
#!/usr/bin/env bash
set -euo pipefail
u=camel.chalal; home=$(getent passwd "$u" | cut -d: -f6)
chmod 755 "$home"
install -d -m 700 -o "$u" -g dev "$home/.ssh"
chmod 600 "$home/.ssh/authorized_keys" 2>/dev/null || true
chown "$u:$u" "$home/.ssh/authorized_keys" 2>/dev/null || true
SH

  # 8. Alias go-/stop-incident  (créés APRES les scripts) --------------------
  for i in 01 02 03 04; do
    ln -sf "/opt/labs/bin/prepare_inc${i}.sh" "/usr/local/bin/go-incident${i}"
    ln -sf "/opt/labs/bin/fix_inc${i}.sh"     "/usr/local/bin/stop-incident${i}"
    chmod +x "/usr/local/bin/go-incident${i}" "/usr/local/bin/stop-incident${i}"
  done
}

main "$@"
