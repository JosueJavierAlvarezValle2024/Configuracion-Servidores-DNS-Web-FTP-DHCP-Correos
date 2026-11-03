#!/usr/bin/env bash
# =============================================================================
#  99_validar.sh - Evidencia y pruebas automaticas del servidor DHCP + DNS
#
#  Muestra la red, los servicios, las concesiones entregadas y ejecuta
#  pruebas de resolucion directa, inversa, MX, CNAME y reenviadores.
#
#  Uso: sudo bash scripts/99_validar.sh
#  La salida tambien se guarda en evidencias/validacion_<fecha>.txt
# =============================================================================
source "$(dirname "$0")/lib/comun.sh"
requiere_root
set +e     # las pruebas pueden fallar sin detener el script

mkdir -p "$BASE_DIR/evidencias"
SALIDA="$BASE_DIR/evidencias/validacion_$(date +%Y%m%d_%H%M%S).txt"
exec > >(tee "$SALIDA") 2>&1

pasaron=0; fallaron=0
pasa()  { echo -e "${VERDE}[PASA]${NC} $1"; ((pasaron++)); }
falla() { echo -e "${ROJO}[FALLA]${NC} $1"; ((fallaron++)); }

# probar "descripcion" comando...          -> pasa si el comando termina bien
probar() { local d="$1"; shift; if "$@" &>/dev/null; then pasa "$d"; else falla "$d"; fi; }

# esperar "descripcion" "texto" comando... -> pasa si la salida contiene el texto
esperar() {
    local d="$1" texto="$2"; shift 2
    local salida; salida="$("$@" 2>&1 | paste -sd' ' -)"
    if [[ "$salida" == *"$texto"* ]]; then pasa "$d -> $salida"; else falla "$d -> '${salida:-sin respuesta}' (se esperaba: $texto)"; fi
}
q() { dig +short @"$IP_SERVIDOR" "$@"; }

titulo "Sistema"
echo "Equipo: $(hostname)   Fecha: $(date)"
grep PRETTY_NAME /etc/os-release
dhcpd --version 2>&1 | head -n1
named -v

titulo "Red del servidor"
ip -br addr show "$IFACE_LAN"
ip -br addr show "$IFACE_WAN"
ip route
echo "ip_forward = $(sysctl -n net.ipv4.ip_forward)"

titulo "Servicios"
for s in isc-dhcp-server named tarea41-nat; do
    printf '%-18s %s\n' "$s" "$(systemctl is-active "$s")"
done
ss -lunp | grep -E 'dhcpd|named' | awk '{print $1, $5, $7}'

titulo "Concesiones DHCP activas (/var/lib/dhcp/dhcpd.leases)"
printf '%-15s %-18s %-14s %-20s %s\n' IP MAC EQUIPO INICIO FIN
awk '
    /^lease /             { ip=$2; mac=""; host=""; est="" }
    $1=="starts"          { ini=$3" "$4 }
    $1=="ends"            { fin=$3" "$4 }
    $1=="hardware"        { mac=$3 }
    $1=="client-hostname" { host=$2 }
    $1=="binding"         { est=$3 }
    /^}/ { if (ip!="") { l[ip]=sprintf("%-15s %-18s %-14s %-20s %s %s", ip, mac, host, ini, fin, est) } ip="" }
    END  { for (i in l) print l[i] }
' /var/lib/dhcp/dhcpd.leases 2>/dev/null | tr -d ';"' | sort -t. -k4n
echo "(Las reservas por MAC no aparecen aqui: se ven en el log de abajo)"

titulo "Ultimos eventos DHCP (journal)"
journalctl -u isc-dhcp-server --no-pager -n 200 2>/dev/null | grep -E 'DHCP(DISCOVER|OFFER|REQUEST|ACK|NAK|RELEASE)' | tail -n 12

titulo "Pruebas DHCP"
probar  "isc-dhcp-server esta activo"                     servicio_activo isc-dhcp-server
probar  "dhcpd.conf sin errores de sintaxis"              dhcpd -4 -t -cf /etc/dhcp/dhcpd.conf
esperar "dhcpd escucha solo en $IFACE_LAN"                "\"$IFACE_LAN\"" grep '^INTERFACESv4' /etc/default/isc-dhcp-server
esperar "Rango dinamico 1 (.100-.149)"                    "range 192.168.50.100 192.168.50.149" grep -E '^\s*range' /etc/dhcp/dhcpd.conf
esperar "Rango dinamico 2 (.160-.200), excluye .150-.159" "range 192.168.50.160 192.168.50.200" grep -E '^\s*range' /etc/dhcp/dhcpd.conf
esperar "Reserva por MAC de cliente01"                    "$IP_RESERVA" grep -A3 '^host cliente01' /etc/dhcp/dhcpd.conf
if journalctl -u isc-dhcp-server --no-pager 2>/dev/null | grep -q "DHCPACK on $IP_RESERVA"; then
    pasa "cliente01 recibio su IP reservada $IP_RESERVA (DHCPACK en el log)"
else
    falla "Aun no hay DHCPACK para $IP_RESERVA (enciende la VM cliente y vuelve a validar)"
fi

titulo "Pruebas DNS"
probar  "named esta activo"                               servicio_activo named
probar  "named-checkconf sin errores"                     named-checkconf
probar  "Zona directa valida"                             named-checkzone "$DOMINIO" /etc/bind/zones/db.empresa.lan
probar  "Zona inversa valida"                             named-checkzone "$ZONA_INVERSA" /etc/bind/zones/db.rev
esperar "A     srv01.$DOMINIO"                            "$IP_SERVIDOR"   q "srv01.$DOMINIO" A
esperar "A     cliente01.$DOMINIO"                        "$IP_RESERVA"    q "cliente01.$DOMINIO" A
esperar "CNAME www.$DOMINIO"                              "srv01.$DOMINIO." q "www.$DOMINIO" CNAME
esperar "CNAME ftp.$DOMINIO"                              "srv01.$DOMINIO." q "ftp.$DOMINIO" CNAME
esperar "MX    $DOMINIO"                                  "10 mail.$DOMINIO." q "$DOMINIO" MX
esperar "NS    $DOMINIO"                                  "ns1.$DOMINIO."  q "$DOMINIO" NS
esperar "PTR   $IP_SERVIDOR"                              "srv01.$DOMINIO." q -x "$IP_SERVIDOR"
esperar "PTR   $IP_RESERVA"                               "cliente01.$DOMINIO." q -x "$IP_RESERVA"
esperar "Reenviadores: resuelve www.google.com"           "."              q www.google.com A
esperar "Nombre inexistente responde NXDOMAIN"            "NXDOMAIN"       dig @"$IP_SERVIDOR" "noexiste.$DOMINIO"

titulo "Resultado"
echo "Pruebas que pasaron: $pasaron   Pruebas que fallaron: $fallaron"
echo "Evidencia guardada en: $SALIDA"
