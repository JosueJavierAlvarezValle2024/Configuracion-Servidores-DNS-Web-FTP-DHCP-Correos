#!/usr/bin/env bash
# =============================================================================
#  98_revertir.sh - Deshace la configuracion de la Tarea 4.1
#
#  Detiene DHCP y DNS, restaura los archivos originales, quita el NAT y
#  la IP fija de enp0s8.
#
#  Uso: sudo bash scripts/98_revertir.sh [--purgar]
#       --purgar  ademas desinstala isc-dhcp-server y bind9
# =============================================================================
source "$(dirname "$0")/lib/comun.sh"
requiere_root
PURGAR=0; [[ "${1:-}" == "--purgar" ]] && PURGAR=1

titulo "Deteniendo servicios"
for s in isc-dhcp-server named tarea41-nat; do
    systemctl disable --now "$s" --quiet 2>/dev/null && ok "Detenido: $s" || true
done

titulo "Restaurando archivos"
for f in /etc/dhcp/dhcpd.conf /etc/default/isc-dhcp-server \
         /etc/systemd/system/isc-dhcp-server.service.d/10-tarea41.conf \
         /etc/bind/named.conf /etc/bind/named.conf.options /etc/bind/named.conf.local \
         /etc/bind/zones/db.empresa.lan /etc/bind/zones/db.rev /etc/bind/zones \
         /etc/tarea41/nat.nft /etc/systemd/system/tarea41-nat.service \
         /etc/sysctl.d/60-tarea41.conf; do
    restaurar "$f"
done
rmdir /etc/tarea41 /etc/systemd/system/isc-dhcp-server.service.d 2>/dev/null || true
systemctl daemon-reload
sysctl -q -w net.ipv4.ip_forward=0 || true

titulo "Quitando la IP fija de $IFACE_LAN"
nmcli connection delete "$CON_LAN" &>/dev/null && ok "Conexion '$CON_LAN' eliminada" || info "No existia '$CON_LAN'"

if (( PURGAR )); then
    titulo "Desinstalando paquetes"
    DEBIAN_FRONTEND=noninteractive apt-get purge -y -q isc-dhcp-server bind9 >/dev/null || true
    ok "isc-dhcp-server y bind9 desinstalados"
else
    # Si BIND sigue instalado, se vuelve a iniciar con su configuracion original
    dpkg -s bind9 &>/dev/null && systemctl enable --now named --quiet 2>/dev/null || true
fi

ok "Reversion terminada. Respaldos en $DIR_RESPALDOS"
