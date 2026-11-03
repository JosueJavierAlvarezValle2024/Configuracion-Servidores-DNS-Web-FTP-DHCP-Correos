#!/usr/bin/env bash
# =============================================================================
#  02_dhcp.sh - Instala y configura el servidor DHCP (isc-dhcp-server)
#
#  - Rango dinamico, exclusion, tiempos de concesion y reservas por MAC
#    definidos en config/dhcpd.conf
#  - Solo atiende la interfaz de la red interna (enp0s8)
#
#  Uso: sudo bash scripts/02_dhcp.sh [--mac 08:00:27:aa:bb:cc]
#       --mac  MAC de la VM cliente para la reserva de cliente01
#              (si no se indica, se usa la que trae config/dhcpd.conf)
# =============================================================================
source "$(dirname "$0")/lib/comun.sh"
requiere_root

MAC=""
while [[ $# -gt 0 ]]; do
    case "$1" in
        --mac) MAC="${2:-}"; shift 2 ;;
        *) error "Opcion desconocida: $1" ;;
    esac
done

if [[ -n "$MAC" ]]; then
    MAC="${MAC,,}"
    [[ "$MAC" =~ ^([0-9a-f]{2}:){5}[0-9a-f]{2}$ ]] || error "MAC invalida: $MAC (formato 08:00:27:aa:bb:cc)"
fi

titulo "Instalando isc-dhcp-server"
instalar_paquetes isc-dhcp-server

titulo "Preparando /etc/dhcp/dhcpd.conf"
# Se prueba en /etc/dhcp porque AppArmor no deja a dhcpd leer otros directorios
prueba="/etc/dhcp/dhcpd.conf.$MARCA"
cp "$CONFIG_DIR/dhcpd.conf" "$prueba"
if [[ -n "$MAC" ]]; then
    sed -i "/^host cliente01/,/^}/ s/hardware ethernet [^;]*;/hardware ethernet $MAC;/" "$prueba"
    ok "Reserva cliente01 -> $MAC = $IP_RESERVA"
fi
if grep -q 'XX:XX' "$prueba"; then
    rm -f "$prueba"
    error "Falta la MAC del cliente. Usa: sudo bash $0 --mac 08:00:27:..."
fi
if ! dhcpd -4 -t -cf "$prueba" >/dev/null 2>&1; then
    dhcpd -4 -t -cf "$prueba" || true
    rm -f "$prueba"
    error "dhcpd.conf tiene errores de sintaxis"
fi
ok "Sintaxis correcta (dhcpd -t)"
instalar_archivo "$prueba" /etc/dhcp/dhcpd.conf 644
rm -f "$prueba"

titulo "Interfaz de escucha: $IFACE_LAN"
respaldar /etc/default/isc-dhcp-server
if grep -q '^INTERFACESv4=' /etc/default/isc-dhcp-server; then
    sed -i "s/^INTERFACESv4=.*/INTERFACESv4=\"$IFACE_LAN\"/" /etc/default/isc-dhcp-server
else
    echo "INTERFACESv4=\"$IFACE_LAN\"" >> /etc/default/isc-dhcp-server
fi
grep '^INTERFACESv4' /etc/default/isc-dhcp-server

# Al arrancar la VM, dhcpd debe esperar a que enp0s8 ya tenga su IP fija
respaldar /etc/systemd/system/isc-dhcp-server.service.d/10-tarea41.conf
mkdir -p /etc/systemd/system/isc-dhcp-server.service.d
cat > /etc/systemd/system/isc-dhcp-server.service.d/10-tarea41.conf <<EOF
# $MARCA - esperar a la red antes de iniciar dhcpd
[Unit]
Wants=network-online.target
After=network-online.target
EOF

titulo "Iniciando el servicio"
systemctl daemon-reload
systemctl disable --now isc-dhcp-server6 --quiet 2>/dev/null || true   # no se usa DHCPv6
systemctl enable isc-dhcp-server --quiet
systemctl restart isc-dhcp-server || true
sleep 1
if servicio_activo isc-dhcp-server; then
    ok "isc-dhcp-server activo"
else
    journalctl -u isc-dhcp-server -n 20 --no-pager
    error "isc-dhcp-server no inicio (revisa que $IFACE_LAN tenga la IP $IP_SERVIDOR: ejecuta 01_red_servidor.sh)"
fi
ss -lunp | grep -E ':67\b' || true
