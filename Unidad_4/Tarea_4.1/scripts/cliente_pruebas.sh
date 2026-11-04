#!/usr/bin/env bash
# =============================================================================
#  cliente_pruebas.sh - Pruebas desde la VM CLIENTE (no en el servidor)
#
#  Uso: bash scripts/cliente_pruebas.sh [opcion]
#     (sin opcion)     Muestra la IP recibida por DHCP y prueba el DNS
#     --renovar        Libera y vuelve a pedir la IP (DISCOVER/OFFER/REQUEST/ACK)
#     --mac-aleatoria  El cliente usa una MAC distinta: recibe IP del rango dinamico
#     --mac-original   Vuelve a la MAC real: recibe la IP reservada 192.168.50.20
# =============================================================================
set -uo pipefail
DOMINIO="empresa.lan"
IP_SERVIDOR="192.168.50.10"
IP_RESERVA="192.168.50.20"
AZUL='\033[1;34m'; NC='\033[0m'
titulo() { echo -e "\n${AZUL}==== $* ====${NC}"; }

# Interfaz cableada del cliente y su conexion de NetworkManager
IFACE="$(nmcli -t -f DEVICE,TYPE device | awk -F: '$2=="ethernet"{print $1; exit}')"
[[ -n "$IFACE" ]] || { echo "No se encontro una interfaz ethernet"; exit 1; }
CON="$(nmcli -g GENERAL.CONNECTION device show "$IFACE")"

renovar() {
    titulo "Renovando la concesion DHCP de $IFACE"
    nmcli device disconnect "$IFACE" >/dev/null
    sleep 2
    nmcli device connect "$IFACE" >/dev/null && echo "Concesion solicitada de nuevo"
    sleep 2
}

cambiar_mac() {   # $1 = random | permanent
    [[ -n "$CON" ]] || CON="$(nmcli -t -f NAME,DEVICE connection show | awk -F: -v d="$IFACE" '$2==d{print $1; exit}')"
    sudo nmcli connection modify "$CON" 802-3-ethernet.cloned-mac-address "$1"
    if ! sudo nmcli connection up "$CON" >/dev/null; then
        echo "No se recibio IP con esta MAC."
        echo "En VirtualBox: Cliente-U4 > Red > Adaptador 1 > Avanzado > Modo promiscuo: 'Permitir VMs'"
        echo "(sin eso VirtualBox descarta las respuestas dirigidas a una MAC distinta a la configurada)"
    fi
    sleep 2
}

case "${1:-}" in
    # Las opciones se aceptan con o sin "--" (ej. renovar o --renovar)
    --renovar|renovar)              renovar ;;
    --mac-aleatoria|mac-aleatoria)  titulo "Usando una MAC aleatoria"; cambiar_mac random ;;
    --mac-original|mac-original)    titulo "Volviendo a la MAC original"; cambiar_mac permanent ;;
    "") ;;
    *) echo "Opcion desconocida: $1"; exit 1 ;;
esac

titulo "Datos recibidos por DHCP ($IFACE)"
echo "MAC en uso:  $(cat /sys/class/net/"$IFACE"/address)"
ip -br addr show "$IFACE"
nmcli -f DHCP4 device show "$IFACE" | grep -E 'ip_address|dhcp_lease_time|routers|domain_name|dhcp_server_identifier|expiry' \
    | sed 's/DHCP4.OPTION\[[0-9]*\]:\s*//'
ip_actual="$(ip -4 -o addr show "$IFACE" | awk '{print $4}' | cut -d/ -f1)"
if [[ "$ip_actual" == "$IP_RESERVA" ]]; then
    echo ">> IP RESERVADA por MAC: $ip_actual"
elif [[ "$ip_actual" =~ ^192\.168\.50\.(1[0-9][0-9]|200)$ ]]; then
    echo ">> IP DINAMICA del rango: $ip_actual"
fi

titulo "DNS configurado"
resolvectl status "$IFACE" | grep -E 'DNS Servers|DNS Domain' | sed 's/^ *//'

titulo "Resolucion directa (nslookup)"
nslookup "www.$DOMINIO"
titulo "Resolucion inversa (nslookup)"
nslookup "$IP_SERVIDOR"

titulo "Registros con dig"
for consulta in "srv01.$DOMINIO A" "www.$DOMINIO CNAME" "$DOMINIO MX" "$DOMINIO NS"; do
    printf '%-28s -> %s\n' "$consulta" "$(dig +short $consulta | paste -sd' ' -)"
done
printf '%-28s -> %s\n' "PTR $IP_RESERVA" "$(dig +short -x "$IP_RESERVA")"
printf '%-28s -> %s\n' "www.google.com (reenviador)" "$(dig +short www.google.com | tail -n1)"
