#!/usr/bin/env bash
# Socle commun à toutes les VM du lab (Kali et Ubuntu)
set -Eeuo pipefail
trap 'echo "[KO] socle commun, ligne $LINENO : $BASH_COMMAND"' ERR
. ./lab.conf
export DEBIAN_FRONTEND=noninteractive NEEDRESTART_MODE=l  # pas de redémarrage automatique de services
echo "== Socle commun ($ROLE, utilisateur $LAB_USER)"

# Pas de mises à jour automatiques pendant la formation (état maîtrisé, pas de verrou apt)
systemctl disable --now unattended-upgrades.service apt-daily.timer apt-daily-upgrade.timer >/dev/null 2>&1 || true
apt-get purge -y -q unattended-upgrades >/dev/null 2>&1 || true
cloud-init status --wait >/dev/null 2>&1 || true

apt-get update -q
apt-get install -y -q openssh-server curl tcpdump netcat-openbsd dnsutils traceroute \
  iputils-ping iproute2 rsyslog nano less ca-certificates jq
echo "[OK] paquets de base"

# SSH : authentification par mot de passe laissée active (constat d'audit du TP 8)
install -d /etc/ssh/sshd_config.d
cat > /etc/ssh/sshd_config.d/10-lab.conf <<'EOF'
PasswordAuthentication yes
KbdInteractiveAuthentication no
EOF
systemctl enable ssh >/dev/null 2>&1 || true
systemctl restart ssh >/dev/null 2>&1 || systemctl restart sshd >/dev/null 2>&1 || true
echo "[OK] SSH actif (mot de passe autorisé)"

# Noms des machines du lab
sed -i '/# --- lab 3-020 ---/,/# --- fin lab 3-020 ---/d' /etc/hosts
cat >> /etc/hosts <<EOF
# --- lab 3-020 ---
$FW_LAN     fw.$DOMAINE fw
$IP_KALI    kali.$DOMAINE kali poste
$IP_SRVINT  srv-int.$DOMAINE srv-int radius.$DOMAINE ldap.$DOMAINE
$IP_WEB     web.$DOMAINE web
$IP_CLOUDGW cloud-gw.$DOMAINE cloud-gw
$IP_CLOUDGW_VPC cloud.$DOMAINE
$IP_EXT     ext.$DOMAINE ext
# --- fin lab 3-020 ---
EOF
echo "[OK] /etc/hosts complété (noms *.lab.local)"

# Horloge : UTC partout (corrélation des journaux au TP 7)
timedatectl set-timezone Etc/UTC 2>/dev/null || ln -sf /usr/share/zoneinfo/Etc/UTC /etc/localtime
# Les machines internes prennent l'heure sur pfSense (NTP intégré) : pas de sortie NTP vers Internet
case $ROLE in
  srv-int|web)
    GWNTP=$([ "$ROLE" = srv-int ] && echo "$FW_SRV" || echo "$FW_DMZ")
    if [ -d /etc/systemd/timesyncd.conf.d ] || systemctl list-unit-files systemd-timesyncd.service >/dev/null 2>&1; then
      install -d /etc/systemd/timesyncd.conf.d
      printf '[Time]\nNTP=%s\nFallbackNTP=\n' "$GWNTP" > /etc/systemd/timesyncd.conf.d/10-lab.conf
      systemctl restart systemd-timesyncd >/dev/null 2>&1 || true
    fi
    echo "[OK] heure en UTC, synchronisée sur pfSense ($GWNTP)" ;;
  *) echo "[OK] heure en UTC" ;;
esac
