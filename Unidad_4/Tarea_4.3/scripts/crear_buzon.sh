#!/usr/bin/env bash
# =============================================================================
#  crear_buzon.sh - Alta, cambio de contrasena y baja de buzones de empresa.lan
#
#  Un buzon virtual necesita tres cosas, y este script las hace juntas:
#    1) /etc/dovecot/usuarios : usuario@empresa.lan y su contrasena cifrada
#    2) /etc/postfix/buzones  : para que Postfix acepte correo para esa direccion
#    3) /var/mail/vhosts/empresa.lan/<usuario>/Maildir con sus carpetas
#
#  Uso:
#    sudo bash scripts/crear_buzon.sh <usuario> [contrasena]   alta o cambio de contrasena
#    sudo bash scripts/crear_buzon.sh --eliminar <usuario>     baja (respalda el buzon)
#    sudo bash scripts/crear_buzon.sh --listar                 lista los buzones
#  Si no se da contrasena, se genera una. Todas quedan en /root/tarea43_credenciales.txt
# =============================================================================
source "$(dirname "$0")/lib/comun.sh"
requiere_root

[[ -f "$USUARIOS_DOVECOT" && -f "$BUZONES_POSTFIX" ]] \
    || error "Faltan los archivos de buzones: ejecuta primero 03_dovecot.sh y 04_postfix.sh"
touch "$CREDENCIALES"; chmod 600 "$CREDENCIALES"

recargar() { systemctl reload postfix 2>/dev/null || true; doveadm reload 2>/dev/null || true; }

listar() {
    titulo "Buzones de $DOMINIO"
    printf '%-28s %-10s %s\n' DIRECCION MENSAJES CARPETA
    local d u
    for d in $(grep -v '^#' "$BUZONES_POSTFIX" | awk '{print $1}'); do
        u="${d%@*}"
        printf '%-28s %-10s %s\n' "$d" \
            "$(doveadm mailbox status -u "$d" messages INBOX 2>/dev/null | awk -F= '{print $2}')" \
            "$VMAIL_DIR/$DOMINIO/$u"
    done
    echo; info "Alias (alias_virtuales):"
    grep -vE '^\s*#|^\s*$' /etc/postfix/alias_virtuales | awk '{printf "  %-24s -> %s\n", $1, $2 $3}'
}

case "${1:-}" in
    --listar|listar) listar; exit 0 ;;
    --eliminar|eliminar)
        u="${2:-}"; [[ -n "$u" ]] || error "Uso: $0 --eliminar <usuario>"
        u="${u%@*}"; d="$u@$DOMINIO"
        grep -q "^$d " "$BUZONES_POSTFIX" || error "No existe el buzon $d"
        sed -i "/^$d:/d" "$USUARIOS_DOVECOT"
        sed -i "/^$d /d" "$BUZONES_POSTFIX"
        sed -i "/^$d: /d" "$CREDENCIALES"
        if [[ -d "$VMAIL_DIR/$DOMINIO/$u" ]]; then
            mkdir -p /root/tarea43_buzones_eliminados
            tar -czf "/root/tarea43_buzones_eliminados/${u}_$(date +%Y%m%d_%H%M%S).tar.gz" -C "$VMAIL_DIR/$DOMINIO" "$u"
            rm -rf "${VMAIL_DIR:?}/$DOMINIO/$u"
        fi
        recargar
        ok "Buzon $d eliminado (copia en /root/tarea43_buzones_eliminados)"
        exit 0 ;;
    ""|-h|--ayuda) sed -n '2,17p' "$0"; exit 1 ;;
esac

# ---------------- Alta o cambio de contrasena ----------------
u="${1%@*}"; d="$u@$DOMINIO"; clave="${2:-}"
[[ "$u" =~ ^[a-z][a-z0-9._-]{1,30}$ ]] || error "Nombre no valido: $u (minusculas, numeros, punto, guion)"
[[ -n "$clave" ]] || clave="$(clave_de "$d")"
[[ -n "$clave" ]] || clave="$(generar_clave 10)"

# 1) Dovecot: contrasena cifrada con SHA512-CRYPT (nunca en texto plano)
hash="$(doveadm pw -s SHA512-CRYPT -p "$clave")"
sed -i "/^$d:/d" "$USUARIOS_DOVECOT"
echo "$d:$hash::::::" >> "$USUARIOS_DOVECOT"

# 2) Postfix: la direccion existe (el valor tambien sirve para smtpd_sender_login_maps)
grep -q "^$d " "$BUZONES_POSTFIX" || echo "$d $d" >> "$BUZONES_POSTFIX"

# 3) Carpeta del buzon y carpetas especiales
install -d -m 700 -o vmail -g vmail "$VMAIL_DIR/$DOMINIO" "$VMAIL_DIR/$DOMINIO/$u"
sed -i "/^$d: /d" "$CREDENCIALES"; echo "$d: $clave" >> "$CREDENCIALES"
recargar
sleep 1
doveadm mailbox create -u "$d" -s Sent Drafts Trash Junk 2>/dev/null || true

ok "Buzon listo: $d"
doveadm user "$d" 2>/dev/null | grep -E 'home|uid|gid' | sed 's/^/     /' || true
