#!/usr/bin/env bash
# =============================================================================
#  01_red_servidor.sh - Prepara la red de la VM servidor
#
#  1) IP fija 192.168.50.10/24 en la interfaz de la red interna (enp0s8),
#     con NetworkManager. La ruta por defecto sigue saliendo por la NAT.
#  2) Las consultas de empresa.lan del propio servidor van a su BIND local.
#  3) Reenvio de paquetes + NAT (nftables): el servidor es la puerta de enlace
#     de los clientes de la red interna hacia internet.
#
#  Uso: sudo bash scripts/01_red_servidor.sh
# =============================================================================
source "$(dirname "$0")/lib/comun.sh"
requiere_root

titulo "Comprobando interfaces"
ip link show "$IFACE_LAN" &>/dev/null \
    || error "No existe $IFACE_LAN. Activa el Adaptador 2 (Red interna red-u4) en VirtualBox."
ip link show "$IFACE_WAN" &>/dev/null \
    || error "No existe $IFACE_WAN (Adaptador 1, NAT)."
ok "LAN: $IFACE_LAN    Internet (NAT): $IFACE_WAN"

titulo "IP fija $IP_SERVIDOR/$PREFIJO en $IFACE_LAN"
ajustes=(
    connection.interface-name "$IFACE_LAN"
    connection.autoconnect yes
    connection.autoconnect-priority 100
    ipv4.method manual
    ipv4.addresses "$IP_SERVIDOR/$PREFIJO"
    ipv4.never-default yes                         # no usar esta red como salida a internet
    ipv4.dns "$IP_SERVIDOR"                        # BIND local para...
    ipv4.dns-search "$DOMINIO,~$ZONA_INVERSA"      # ...empresa.lan y su zona inversa
    ipv6.method disabled
)
if nmcli -t -f NAME connection show | grep -qx "$CON_LAN"; then
    nmcli connection modify "$CON_LAN" "${ajustes[@]}"
    ok "Conexion '$CON_LAN' actualizada"
else
    nmcli connection add type ethernet con-name "$CON_LAN" ifname "$IFACE_LAN" "${ajustes[@]}" >/dev/null
    ok "Conexion '$CON_LAN' creada"
fi
nmcli connection up "$CON_LAN" >/dev/null
ip -br addr show "$IFACE_LAN"

titulo "Reenvio de paquetes (ip_forward)"
respaldar /etc/sysctl.d/60-tarea41.conf
echo "net.ipv4.ip_forward = 1    # $MARCA: el servidor enruta la LAN" > /etc/sysctl.d/60-tarea41.conf
sysctl -q -p /etc/sysctl.d/60-tarea41.conf
ok "net.ipv4.ip_forward = $(sysctl -n net.ipv4.ip_forward)"

titulo "NAT de 192.168.50.0/24 hacia $IFACE_WAN"
instalar_paquetes nftables
tmp="$(mktemp)"
sed "s/oifname \"enp0s3\"/oifname \"$IFACE_WAN\"/" "$CONFIG_DIR/nat-tarea41.nft" > "$tmp"
instalar_archivo "$tmp" /etc/tarea41/nat.nft 644
rm -f "$tmp"

respaldar /etc/systemd/system/tarea41-nat.service
cat > /etc/systemd/system/tarea41-nat.service <<EOF
# $MARCA - carga las reglas NAT de la red interna al arrancar
[Unit]
Description=NAT de la red interna 192.168.50.0/24 (Tarea 4.1)
After=network.target

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/usr/sbin/nft -f /etc/tarea41/nat.nft
ExecStop=/usr/sbin/nft delete table ip tarea41_nat

[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload
systemctl enable tarea41-nat.service --quiet
systemctl restart tarea41-nat.service
servicio_activo tarea41-nat.service && ok "Reglas NAT cargadas" || error "Fallo tarea41-nat.service"
nft list table ip tarea41_nat
