#!/usr/bin/env bash
# =============================================================================
#  03_dovecot.sh - Dovecot 2.4: entrega (LMTP), IMAPS y autenticacion SASL
#
#  1) Instala dovecot-imapd y dovecot-lmtpd
#  2) Crea el usuario de sistema "vmail" (uid 5000), dueno de todos los buzones
#  3) Reemplaza /etc/dovecot/dovecot.conf por config/dovecot/dovecot.conf
#  4) Crea el archivo de usuarios virtuales /etc/dovecot/usuarios
#
#  Requiere: 02_certificado_correo.sh
#  Uso: sudo bash scripts/03_dovecot.sh
# =============================================================================
source "$(dirname "$0")/lib/comun.sh"
requiere_root

[[ -f "$MAIL_CRT" ]] || error "Falta el certificado: ejecuta primero 02_certificado_correo.sh"

titulo "Instalando Dovecot y rsyslog"
# rsyslog escribe /var/log/mail.log (Postfix y Dovecot registran en syslog)
instalar_paquetes dovecot-core dovecot-imapd dovecot-lmtpd rsyslog
systemctl enable --now rsyslog --quiet 2>/dev/null || true
ok "$(dovecot --version | sed 's/^/Dovecot /')"

titulo "Usuario vmail (dueno de los buzones)"
getent group vmail >/dev/null || groupadd -g "$VMAIL_UID" vmail
id vmail &>/dev/null || useradd -r -u "$VMAIL_UID" -g vmail -d "$VMAIL_DIR" -s /usr/sbin/nologin -c "Buzones virtuales ($MARCA)" vmail
respaldar "$VMAIL_DIR"
install -d -m 770 -o vmail -g vmail "$VMAIL_DIR"
ok "vmail ($(id vmail)) · buzones en $VMAIL_DIR"

titulo "Configuracion"
instalar_archivo "$CONFIG_DIR/dovecot/dovecot.conf" /etc/dovecot/dovecot.conf 644
respaldar "$USUARIOS_DOVECOT"
touch "$USUARIOS_DOVECOT"
chown root:dovecot "$USUARIOS_DOVECOT"; chmod 640 "$USUARIOS_DOVECOT"
ok "Usuarios virtuales: $USUARIOS_DOVECOT (640 root:dovecot)"

if ! doveconf -n >/dev/null 2>/tmp/doveconf_error.txt; then
    cat /tmp/doveconf_error.txt
    error "dovecot.conf tiene errores (doveconf -n)"
fi
ok "doveconf -n sin errores"

titulo "Iniciando el servicio"
systemctl enable dovecot --quiet
systemctl restart dovecot
sleep 1
if servicio_activo dovecot; then
    ok "dovecot activo"
else
    journalctl -u dovecot -n 20 --no-pager
    error "dovecot no inicio"
fi
ss -ltnp | grep -E ':(993|143)\b' | awk '{print "Escuchando:", $4}'
