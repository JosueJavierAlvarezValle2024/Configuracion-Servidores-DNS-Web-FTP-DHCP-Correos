#!/usr/bin/env bash
# =============================================================================
#  cliente_pruebas.sh - Pruebas de correo desde la VM CLIENTE (Tarea 4.3)
#
#  Uso: bash scripts/cliente_pruebas.sh <opcion>
#     confiar-ca   Hace que Thunderbird confie en la CA de empresa.lan (sudo)
#     dns          Registros MX, A y SPF del dominio
#     tls          Certificado y STARTTLS de SMTP (587) y de IMAPS (993)
#     enviar       Envia un correo autenticado (pide remitente, destino y clave)
#     bandeja      Lista los ultimos mensajes de un buzon por IMAPS
#  Las opciones se aceptan con o sin "--".
# =============================================================================
set -uo pipefail
DOMINIO="empresa.lan"
HOST="mail.$DOMINIO"
CA_URL="http://www.$DOMINIO/ca.crt"
AZUL='\033[1;34m'; VERDE='\033[0;32m'; ROJO='\033[0;31m'; NC='\033[0m'
titulo() { echo -e "\n${AZUL}==== $* ====${NC}"; }
bien()   { echo -e "${VERDE}  OK${NC}  $*"; }
mal()    { echo -e "${ROJO}  NO${NC}  $*"; }

command -v curl >/dev/null || { echo "Instalando curl..."; sudo apt-get install -y -q curl >/dev/null; }

confiar_ca() {
    titulo "CA de $DOMINIO para Thunderbird"
    curl -fsS "$CA_URL" -o /tmp/empresa-ca.crt || { echo "No se pudo descargar $CA_URL"; exit 1; }
    sudo install -m 644 /tmp/empresa-ca.crt /usr/local/share/ca-certificates/empresa-ca.crt
    sudo update-ca-certificates >/dev/null 2>&1
    sudo mkdir -p /etc/thunderbird/policies
    sudo install -m 644 /tmp/empresa-ca.crt /etc/thunderbird/policies/empresa-ca.crt
    echo '{ "policies": { "Certificates": { "Install": ["/etc/thunderbird/policies/empresa-ca.crt"] } } }' \
        | sudo tee /etc/thunderbird/policies/policies.json >/dev/null
    bien "Politica creada: cierra y vuelve a abrir Thunderbird"
    echo "    Si Thunderbird avisa del certificado, importala a mano:"
    echo "    Configuracion > Privacidad y seguridad > Gestionar certificados > Autoridades > Importar"
    echo "    /tmp/empresa-ca.crt (marca 'Confiar en esta CA para identificar sitios web')."
}

pruebas_dns() {
    titulo "Registros DNS del correo"
    echo "MX   $DOMINIO      -> $(dig +short "$DOMINIO" MX)"
    echo "A    $HOST -> $(dig +short "$HOST" A)"
    echo "SPF  $DOMINIO      -> $(dig +short "$DOMINIO" TXT | grep spf1)"
}

pruebas_tls() {
    titulo "SMTP envio (587) con STARTTLS"
    echo | openssl s_client -connect "$HOST:587" -starttls smtp -servername "$HOST" 2>/dev/null \
        | grep -E 'subject=|issuer=|Protocol|Cipher is|Verify return code' | sed 's/^ */  /'
    titulo "IMAPS (993)"
    echo | openssl s_client -connect "$HOST:993" -servername "$HOST" 2>/dev/null \
        | grep -E 'subject=|issuer=|Protocol|Cipher is|Verify return code|OK \[' | sed 's/^ */  /'
}

enviar() {
    titulo "Enviar un correo por SMTP 587 (STARTTLS + autenticacion)"
    read -rp "  Remitente (ej. ana.torres): " de
    read -rp "  Destinatario (ej. pedro.ruiz): " para
    read -rsp "  Contrasena de $de: " clave; echo
    de="${de%@*}@$DOMINIO"; para="${para%@*}@$DOMINIO"
    asunto="Prueba desde el cliente $(date +%H:%M:%S)"
    printf 'From: %s\r\nTo: %s\r\nSubject: %s\r\nDate: %s\r\n\r\nHola, este mensaje se envio desde cliente01 por SMTP con TLS.\r\n' \
        "$de" "$para" "$asunto" "$(date -R)" > /tmp/mensaje.eml
    if curl -s --url "smtp://$HOST:587" --ssl-reqd --mail-from "$de" --mail-rcpt "$para" \
            --upload-file /tmp/mensaje.eml --user "$de:$clave"; then
        bien "Enviado: \"$asunto\" de $de para $para"
    else
        mal "No se pudo enviar (revisa la contrasena)"
    fi
}

bandeja() {
    titulo "Bandeja de entrada por IMAPS (993)"
    read -rp "  Buzon (ej. pedro.ruiz): " u
    read -rsp "  Contrasena: " clave; echo
    u="${u%@*}@$DOMINIO"
    total="$(curl -s --url "imaps://$HOST/INBOX" --user "$u:$clave" -X 'EXAMINE INBOX' | grep -oE '[0-9]+ EXISTS' | cut -d' ' -f1)"
    [[ -n "$total" ]] || { mal "No se pudo iniciar sesion"; return; }
    bien "$u tiene $total mensajes. Los ultimos 5:"
    for ((i = total; i > 0 && i > total - 5; i--)); do
        curl -s --url "imaps://$HOST/INBOX;MAILINDEX=$i;SECTION=HEADER.FIELDS%20(FROM%20SUBJECT%20DATE)" --user "$u:$clave" \
            | tr -d '\r' | sed '/^$/d' | sed 's/^/    /'
        echo "    ---"
    done
}

case "${1:-}" in
    confiar-ca|--confiar-ca) confiar_ca ;;
    dns|--dns)               pruebas_dns ;;
    tls|--tls)               pruebas_tls ;;
    enviar|--enviar)         enviar ;;
    bandeja|--bandeja)       bandeja ;;
    *) sed -n '2,13p' "$0"; exit 1 ;;
esac
