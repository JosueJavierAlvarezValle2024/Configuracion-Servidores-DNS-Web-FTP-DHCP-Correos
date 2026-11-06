#!/usr/bin/env bash
# =============================================================================
#  03_postfix.sh - Postfix: SMTP (25) y envio autenticado con TLS (587)
#
#  1) Instala Postfix sin el asistente de configuracion de Ubuntu
#  2) Instala main.cf, master.cf y los alias virtuales
#  3) Revisa la configuracion (postfix check) y reinicia
#
#  Va ANTES de Dovecot: al instalarse crea /var/spool/postfix/private, donde
#  Dovecot pone sus sockets (LMTP y autenticacion).
#  Uso: sudo bash scripts/03_postfix.sh
# =============================================================================
source "$(dirname "$0")/lib/comun.sh"
requiere_root

titulo "Instalando Postfix"
# Respuestas del asistente de instalacion: sin configuracion (la ponemos nosotros)
echo "postfix postfix/main_mailer_type select No configuration" | debconf-set-selections
echo "postfix postfix/mailname string $HOST_CORREO" | debconf-set-selections
instalar_paquetes postfix swaks
ok "$(postconf -h mail_version | sed 's/^/Postfix /')"

titulo "Configuracion"
respaldar /etc/mailname
echo "$HOST_CORREO" > /etc/mailname
instalar_archivo "$CONFIG_DIR/postfix/main.cf"         /etc/postfix/main.cf         644
instalar_archivo "$CONFIG_DIR/postfix/master.cf"       /etc/postfix/master.cf       644
instalar_archivo "$CONFIG_DIR/postfix/alias_virtuales" /etc/postfix/alias_virtuales 644
instalar_archivo "$CONFIG_DIR/postfix/remitentes_internos" /etc/postfix/remitentes_internos 644
# La tabla de buzones la llena crear_buzon.sh; aqui solo se crea si no existe
respaldar "$BUZONES_POSTFIX"
[[ -f "$BUZONES_POSTFIX" ]] || echo "# $MARCA - buzones de empresa.lan (los agrega crear_buzon.sh)" > "$BUZONES_POSTFIX"
chmod 644 "$BUZONES_POSTFIX"

titulo "Revisando y aplicando"
postfix check || error "postfix check encontro problemas"
ok "postfix check sin errores"
systemctl enable postfix --quiet
systemctl restart postfix
sleep 1
servicio_activo postfix && ok "postfix activo" || { journalctl -u postfix -n 20 --no-pager; error "postfix no inicio"; }
ss -ltnp | grep -E ':(25|587)\b' | awk '{print "Escuchando:", $4}'
postconf -n | grep -E '^(myhostname|virtual_mailbox_domains|virtual_transport|smtpd_tls_cert_file|smtpd_sasl_type)'
