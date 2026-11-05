#!/usr/bin/env bash
# =============================================================================
#  02_certificado_correo.sh - Certificado TLS para mail.empresa.lan
#
#  Lo firma la CA local de la Tarea 4.2, en la que los clientes ya confian.
#  Lo usan Postfix (SMTP 25 y 587) y Dovecot (IMAPS 993).
#
#  Uso: sudo bash scripts/02_certificado_correo.sh
# =============================================================================
source "$(dirname "$0")/lib/comun.sh"
requiere_root

[[ -f "$CA_CRT" && -f "$CA_KEY" ]] || error "No se encontro la CA en $SSL_DIR: ejecuta primero la Tarea 4.2 (02_certificados.sh)"

titulo "Certificado de $HOST_CORREO"
respaldar "$MAIL_CRT"; respaldar "$MAIL_KEY"
openssl req -new -nodes -newkey rsa:2048 -sha256 \
    -config "$CONFIG_DIR/ssl/mail.cnf" -keyout "$MAIL_KEY" -out "$SSL_DIR/mail.csr" 2>/dev/null
chmod 600 "$MAIL_KEY"
openssl x509 -req -in "$SSL_DIR/mail.csr" -CA "$CA_CRT" -CAkey "$CA_KEY" -CAcreateserial \
    -days 825 -sha256 -extfile "$CONFIG_DIR/ssl/mail.cnf" -extensions ext_servidor \
    -out "$MAIL_CRT" 2>/dev/null
chmod 644 "$MAIL_CRT"
rm -f "$SSL_DIR/mail.csr"

openssl verify -CAfile "$CA_CRT" "$MAIL_CRT" || error "El certificado no se pudo verificar con la CA"
openssl x509 -in "$MAIL_CRT" -noout -subject -issuer -enddate
openssl x509 -in "$MAIL_CRT" -noout -ext subjectAltName | tail -n +2 | sed 's/^ */Nombres: /'

# Si los servicios ya estaban activos, toman el certificado nuevo
servicio_activo postfix && systemctl reload postfix || true
servicio_activo dovecot && systemctl reload dovecot || true
