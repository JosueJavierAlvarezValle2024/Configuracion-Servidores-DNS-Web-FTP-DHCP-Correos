#!/usr/bin/env bash
# =============================================================================
#  03_https_vhosts.sh - Virtual Hosts de Apache con HTTPS
#
#  - Activa los modulos ssl, headers y rewrite
#  - Instala los virtual hosts www.empresa.lan e intranet.empresa.lan
#    (HTTP redirige a HTTPS) y la configuracion de cifrado tarea42-seguridad
#  - Desactiva los sitios por defecto de Apache
#
#  Requiere: 01_web_lamp.sh y 02_certificados.sh
#  Uso: sudo bash scripts/03_https_vhosts.sh
# =============================================================================
source "$(dirname "$0")/lib/comun.sh"
requiere_root

[[ -f "$SRV_CRT" && -f "$SRV_KEY" ]] || error "Falta el certificado: ejecuta primero 02_certificados.sh"

titulo "Modulos de Apache"
a2enmod -q ssl headers rewrite
ok "ssl, headers y rewrite activos"

titulo "Virtual Hosts"
for s in "${SITIOS[@]}"; do
    instalar_archivo "$CONFIG_DIR/apache/$s.conf" "/etc/apache2/sites-available/$s.conf"
    a2ensite -q "$s"
done
instalar_archivo "$CONFIG_DIR/apache/tarea42-seguridad.conf" /etc/apache2/conf-available/tarea42-seguridad.conf
a2enconf -q tarea42-seguridad

# Los sitios de ejemplo de Apache ya no se usan (98_revertir.sh los reactiva)
for s in 000-default default-ssl; do
    if [[ -e "/etc/apache2/sites-enabled/$s.conf" ]]; then
        a2dissite -q "$s"; touch "$DIR_RESPALDOS/sitio-desactivado-$s"
        ok "Sitio por defecto desactivado: $s"
    fi
done

titulo "Revisando y aplicando la configuracion"
apache2ctl configtest 2>&1 | grep -v 'AH00558' || true
apache2ctl -t >/dev/null 2>&1 || error "La configuracion de Apache tiene errores"
systemctl restart apache2
servicio_activo apache2 && ok "apache2 activo" || error "apache2 no inicio"
apache2ctl -S 2>/dev/null | grep -E 'namevhost|port (80|443)' || true
ss -ltnp | grep -E ':(80|443)\b' | awk '{print "Escuchando:", $4}'
