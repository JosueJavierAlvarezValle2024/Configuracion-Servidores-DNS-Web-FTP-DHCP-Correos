#!/usr/bin/env bash
# =============================================================================
#  03_dns.sh - Instala y configura el servidor DNS (BIND9)
#
#  - named.conf.options : ACL, recursion y reenviadores (forwarders)
#  - named.conf.local   : zona directa empresa.lan y zona inversa 192.168.50
#  - zones/db.empresa.lan y zones/db.rev : registros A, CNAME, MX, NS y PTR
#
#  Uso: sudo bash scripts/03_dns.sh
# =============================================================================
source "$(dirname "$0")/lib/comun.sh"
requiere_root

titulo "Instalando BIND9"
instalar_paquetes bind9 bind9-utils bind9-dnsutils

titulo "Copiando la configuracion"
instalar_archivo "$CONFIG_DIR/named.conf"         /etc/bind/named.conf         644 root:bind
instalar_archivo "$CONFIG_DIR/named.conf.options" /etc/bind/named.conf.options 644 root:bind
instalar_archivo "$CONFIG_DIR/named.conf.local"   /etc/bind/named.conf.local   644 root:bind
respaldar /etc/bind/zones
instalar_archivo "$CONFIG_DIR/db.empresa.lan"     /etc/bind/zones/db.empresa.lan 644 root:bind
instalar_archivo "$CONFIG_DIR/db.rev"             /etc/bind/zones/db.rev         644 root:bind

titulo "Revisando sintaxis"
named-checkconf || error "named.conf tiene errores"
ok "named-checkconf sin errores"
named-checkzone "$DOMINIO" /etc/bind/zones/db.empresa.lan || error "Error en la zona directa"
named-checkzone "$ZONA_INVERSA" /etc/bind/zones/db.rev    || error "Error en la zona inversa"

titulo "Iniciando el servicio"
systemctl enable named --quiet
systemctl restart named
sleep 1
if servicio_activo named; then
    ok "named (BIND9) activo"
else
    journalctl -u named -n 20 --no-pager
    error "named no inicio"
fi
ss -lunp | grep -E ':53\b' | grep named || true

titulo "Prueba rapida"
echo "www.$DOMINIO  -> $(dig +short @"$IP_SERVIDOR" "www.$DOMINIO" | paste -sd' ' -)"
echo "$IP_SERVIDOR -> $(dig +short @"$IP_SERVIDOR" -x "$IP_SERVIDOR")"
