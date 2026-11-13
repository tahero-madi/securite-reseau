#!/usr/bin/env bash
# Socle commun, exécuté DANS chaque conteneur pendant l'installation
# (le conteneur est alors sur lxdbr0 avec accès Internet).
set -Eeuo pipefail
trap 'echo "[KO] $(hostname) ligne $LINENO : $BASH_COMMAND" >&2' ERR
. /root/lab.conf
export DEBIAN_FRONTEND=noninteractive

cloud-init status --wait >/dev/null 2>&1 || true

# Pas de mises à jour automatiques pendant la formation (état maîtrisé, pas de verrou apt)
apt-get purge -y -q unattended-upgrades >/dev/null 2>&1 || true
apt-get update -q
apt-get install -y -q openssh-server sudo less nano vim-tiny iputils-ping iproute2 tcpdump \
  netcat-openbsd curl dnsutils rsyslog ca-certificates traceroute

# Compte stagiaire
id stagiaire >/dev/null 2>&1 || useradd -m -s /bin/bash -G sudo stagiaire
echo "stagiaire:$PW_STAGIAIRE" | chpasswd
# Authentification SSH par mot de passe : volontairement laissée active (constat d'audit TP 8)
cat > /etc/ssh/sshd_config.d/10-lab.conf <<EOF
PasswordAuthentication yes
KbdInteractiveAuthentication no
EOF
systemctl enable ssh >/dev/null 2>&1 || true

# AC du lab
cp /root/ca.crt /usr/local/share/ca-certificates/lab-3020.crt
update-ca-certificates >/dev/null

# Résolution des noms du lab
sed -i '/# --- lab 3-020 ---/,/# --- fin lab 3-020 ---/d' /etc/hosts
cat /root/hosts.lab >> /etc/hosts

# Réseau définitif (activé quand le conteneur passera sur les ponts du lab)
echo 'network: {config: disabled}' > /etc/cloud/cloud.cfg.d/99-lab-reseau.cfg
rm -f /etc/netplan/50-cloud-init.yaml
install -m 600 /root/10-lab.yaml /etc/netplan/10-lab.yaml

# Fuseau UTC (corrélation des journaux)
ln -sf /usr/share/zoneinfo/Etc/UTC /etc/localtime
echo "[OK] socle commun : $(hostname)"
