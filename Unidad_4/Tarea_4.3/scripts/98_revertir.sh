#!/usr/bin/env bash
# =============================================================================
#  98_revertir.sh - Deshace la configuracion de la Tarea 4.3
#
#  Detiene Postfix y Dovecot, restaura sus archivos originales, borra los
#  buzones y quita los registros de correo de la zona DNS.
#  No toca las Tareas 4.1 y 4.2.
#
#  Uso: sudo bash scripts/98_revertir.sh [--purgar]
#       --purgar  ademas desinstala postfix, dovecot y swaks
# =============================================================================
source "$(dirname "$0")/lib/comun.sh"
requiere_root
PURGAR=0; [[ "${1:-}" == "--purgar" ]] && PURGAR=1

titulo "Servicios de correo"
for s in postfix dovecot; do
    systemctl disable --now "$s" --quiet 2>/dev/null && ok "Detenido: $s" || true
done

titulo "Restaurando archivos"
for f in /etc/postfix/main.cf /etc/postfix/master.cf /etc/postfix/alias_virtuales /etc/postfix/remitentes_internos "$BUZONES_POSTFIX" \
         /etc/mailname /etc/dovecot/dovecot.conf "$USUARIOS_DOVECOT" "$MAIL_CRT" "$MAIL_KEY" "$VMAIL_DIR"; do
    restaurar "$f"
done
rm -f "$CREDENCIALES"

titulo "Usuario vmail"
id vmail &>/dev/null && userdel vmail && ok "Usuario vmail eliminado" || true
getent group vmail >/dev/null && groupdel vmail 2>/dev/null || true

titulo "Zona DNS"
if [[ -f "$ZONA" ]] && grep -q "; BEGIN $MARCA" "$ZONA"; then
    sed -i "/; BEGIN $MARCA/,/; END $MARCA/d" "$ZONA"
    actual="$(awk '/; *serial/ {print $1; exit}' "$ZONA")"
    sed -i "0,/$actual\(\s*; *serial\)/s//$((actual + 1))\1/" "$ZONA"
    named-checkzone "$DOMINIO" "$ZONA" >/dev/null && rndc reload "$DOMINIO" >/dev/null && ok "Registros de correo quitados de la zona"
fi
# La copia original de la zona ya no se necesita
rm -f "$DIR_RESPALDOS$ZONA.orig" "$DIR_RESPALDOS$ZONA.nuevo"

if (( PURGAR )); then
    titulo "Desinstalando paquetes"
    DEBIAN_FRONTEND=noninteractive apt-get purge -y -q postfix 'dovecot-*' swaks >/dev/null || true
    DEBIAN_FRONTEND=noninteractive apt-get autoremove -y -q >/dev/null || true
    ok "postfix, dovecot y swaks desinstalados"
fi

ok "Reversion terminada. Respaldos en $DIR_RESPALDOS"
