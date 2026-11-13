#!/usr/bin/env bash
# Étape 5 — Machine virtuelle pfSense CE « fw » (KVM, 4 cartes)
#   sudo ./05-pfsense.sh /chemin/netgate-installer-amd64.iso[.gz]
#
#   vtnet0 -> lab-wan  203.0.113.11/24 (passerelle 203.0.113.254)
#   vtnet1 -> lab-lan  10.1.10.1/24
#   vtnet2 -> lab-srv  10.1.20.1/24   (OPT1, renommée SRV)
#   vtnet3 -> lab-dmz  10.1.30.1/24   (OPT2, renommée DMZ)
# L'installation elle-même se fait à la main (≈ 15 min) : suivez pfsense/INSTALLATION-pfsense.md
. "$(dirname "$0")/commun.sh"
exige_root
ISO_SRC=${1:-}
[ -n "$ISO_SRC" ] && [ -f "$ISO_SRC" ] || meurt "Usage : sudo $0 /chemin/netgate-installer-amd64.iso[.gz]"

IMG=/var/lib/libvirt/images
ISO=$IMG/pfsense-installer.iso
titre "Image d'installation"
case "$ISO_SRC" in
  *.gz) gunzip -c "$ISO_SRC" > "$ISO" ;;
  *)    cp "$ISO_SRC" "$ISO" ;;
esac
ok "$ISO"

if virsh dominfo fw >/dev/null 2>&1; then
  avert "la VM « fw » existe déjà."
  read -r -p "   La supprimer et repartir de zéro ? [o/N] " r
  [ "$r" = o ] || exit 0
  virsh destroy fw >/dev/null 2>&1 || true
  virsh undefine fw --snapshots-metadata --remove-all-storage >/dev/null
fi

titre "Création de la VM fw"
qemu-img create -q -f qcow2 $IMG/fw.qcow2 "${FW_DISQUE_GO}G"
virt-install --name fw --memory "$FW_RAM_MO" --vcpus "$FW_VCPU" --cpu host-passthrough \
  --osinfo detect=on,require=off \
  --disk path=$IMG/fw.qcow2,format=qcow2,bus=virtio \
  --cdrom "$ISO" --boot hd,cdrom \
  --network bridge=lab-wan,model=virtio,mac=52:54:00:30:20:01 \
  --network bridge=lab-lan,model=virtio,mac=52:54:00:30:20:02 \
  --network bridge=lab-srv,model=virtio,mac=52:54:00:30:20:03 \
  --network bridge=lab-dmz,model=virtio,mac=52:54:00:30:20:04 \
  --graphics vnc,listen=127.0.0.1 --video vga \
  --noautoconsole
virsh autostart fw >/dev/null
ok "VM fw créée et démarrée sur l'installateur"

titre "Suite : installation manuelle"
info "Ouvrez la console de la VM depuis le bureau : lab console fw   (ou virt-manager)"
info "puis suivez $KIT/pfsense/INSTALLATION-pfsense.md"
if [ -n "${DISPLAY:-}" ] && [ -n "${SUDO_USER:-}" ]; then
  sudo -u "$SUDO_USER" DISPLAY="$DISPLAY" virt-viewer -c qemu:///system fw >/dev/null 2>&1 &
fi
