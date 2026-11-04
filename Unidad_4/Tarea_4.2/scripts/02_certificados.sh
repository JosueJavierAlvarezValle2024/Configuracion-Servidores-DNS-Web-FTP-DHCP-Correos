#!/usr/bin/env bash
# =============================================================================
#  02_certificados.sh - Autoridad certificadora local y certificado del servidor
#
#  1) Crea la CA de empresa.lan (ca.key + ca.crt, valida 10 años)
#  2) Crea la llave del servidor y una solicitud (CSR) con todos sus nombres
#  3) La CA firma el certificado del servidor (valido 825 dias)
#  4) Publica ca.crt en http://www.empresa.lan/ca.crt para los clientes
#
#  Uso: sudo bash scripts/02_certificados.sh [--nueva-ca]
#       --nueva-ca  vuelve a crear la CA (los clientes tendrian que importarla otra vez)
# =============================================================================
source "$(dirname "$0")/lib/comun.sh"
requiere_root
NUEVA_CA=0; [[ "${1:-}" == "--nueva-ca" ]] && NUEVA_CA=1

respaldar "$SSL_DIR"
mkdir -p "$SSL_DIR/private"
chmod 755 "$SSL_DIR"; chmod 700 "$SSL_DIR/private"

titulo "Autoridad certificadora (CA)"
if [[ -f "$CA_KEY" && -f "$CA_CRT" && $NUEVA_CA -eq 0 ]]; then
    ok "La CA ya existe: se reutiliza"
else
    openssl req -x509 -new -nodes -newkey rsa:4096 -sha256 -days 3650 \
        -config "$CONFIG_DIR/ssl/ca.cnf" -keyout "$CA_KEY" -out "$CA_CRT" 2>/dev/null
    chmod 600 "$CA_KEY"
    ok "CA creada"
fi
openssl x509 -in "$CA_CRT" -noout -subject -enddate

titulo "Certificado del servidor"
openssl req -new -nodes -newkey rsa:2048 -sha256 \
    -config "$CONFIG_DIR/ssl/servidor.cnf" -keyout "$SRV_KEY" -out "$SSL_DIR/servidor.csr" 2>/dev/null
chmod 600 "$SRV_KEY"
openssl x509 -req -in "$SSL_DIR/servidor.csr" -CA "$CA_CRT" -CAkey "$CA_KEY" -CAcreateserial \
    -days 825 -sha256 -extfile "$CONFIG_DIR/ssl/servidor.cnf" -extensions ext_servidor \
    -out "$SRV_CRT" 2>/dev/null
chmod 644 "$SRV_CRT"
openssl verify -CAfile "$CA_CRT" "$SRV_CRT" || error "El certificado no se pudo verificar con la CA"
openssl x509 -in "$SRV_CRT" -noout -subject -issuer -enddate
openssl x509 -in "$SRV_CRT" -noout -ext subjectAltName | tail -n +2 | sed 's/^ */Nombres: /'

titulo "Publicando la CA para los clientes"
mkdir -p "$WEB_DIR/ca"
install -m 644 "$CA_CRT" "$WEB_DIR/ca/empresa-ca.crt"
# El propio servidor tambien confia en su CA (para curl y las pruebas)
respaldar /usr/local/share/ca-certificates/empresa-ca.crt
install -m 644 "$CA_CRT" /usr/local/share/ca-certificates/empresa-ca.crt
update-ca-certificates >/dev/null 2>&1 || true
ok "Descarga para clientes: http://www.$DOMINIO/ca.crt"

# Si los servicios ya estaban activos, toman el certificado nuevo
servicio_activo apache2 && systemctl reload apache2 || true
servicio_activo vsftpd  && systemctl restart vsftpd || true
