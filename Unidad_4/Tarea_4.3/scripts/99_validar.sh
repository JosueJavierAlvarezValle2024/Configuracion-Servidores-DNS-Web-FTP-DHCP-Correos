#!/usr/bin/env bash
# =============================================================================
#  99_validar.sh - Evidencia y pruebas automaticas del correo (Tarea 4.3)
#
#  DNS (MX, A, SPF), certificado, servicios y puertos, seguridad de SMTP
#  (STARTTLS, sin relay abierto, sin autenticacion en claro), envio y
#  recepcion entre buzones del dominio, IMAPS y registro en mail.log.
#
#  Uso: sudo bash scripts/99_validar.sh
#  La salida tambien se guarda en evidencias/validacion_<fecha>.txt
# =============================================================================
source "$(dirname "$0")/lib/comun.sh"
requiere_root
for p in curl swaks; do
    command -v "$p" >/dev/null || DEBIAN_FRONTEND=noninteractive apt-get install -y -q "$p" >/dev/null
done
set +e

mkdir -p "$BASE_DIR/evidencias"
SALIDA="$BASE_DIR/evidencias/validacion_$(date +%Y%m%d_%H%M%S).txt"
exec > >(tee "$SALIDA") 2>&1

pasaron=0; fallaron=0
pasa()  { echo -e "${VERDE}[PASA]${NC} $1"; ((pasaron++)); }
falla() { echo -e "${ROJO}[FALLA]${NC} $1"; ((fallaron++)); }
probar() { local d="$1"; shift; if "$@" &>/dev/null; then pasa "$d"; else falla "$d"; fi; }
negar()  { local d="$1"; shift; if "$@" &>/dev/null; then falla "$d"; else pasa "$d"; fi; }
# esperar "descripcion" "texto" comando...  -> pasa si la salida contiene el texto
esperar() {
    local d="$1" texto="$2"; shift 2
    local salida; salida="$("$@" 2>&1)"
    if grep -qF -- "$texto" <<< "$salida"; then pasa "$d -> $texto"; else falla "$d (no aparece: $texto)"; fi
}
# no_aparece "descripcion" "texto" comando... -> pasa si la salida NO contiene el texto
no_aparece() {
    local d="$1" texto="$2"; shift 2
    local salida; salida="$("$@" 2>&1)"
    if grep -qF -- "$texto" <<< "$salida"; then falla "$d (aparece: $texto)"; else pasa "$d"; fi
}

A="ana.torres@$DOMINIO"; B="pedro.ruiz@$DOMINIO"
CA_="$(clave_de "$A")"; CB="$(clave_de "$B")"
q()    { dig +short @"$IP_SERVIDOR" "$@"; }
ehlo() { swaks --server "$HOST_CORREO" --port "$1" "${@:2}" --quit-after EHLO --ehlo prueba.empresa.lan; }
puerto_abierto() { ss -ltn | grep -qE ":$1\b"; }
# hay_mensaje <buzon> <asunto>: el mensaje esta en el INBOX (doveadm search no imprime nada si no)
hay_mensaje() { [[ -n "$(doveadm search -u "$1" mailbox INBOX subject "$2" 2>/dev/null)" ]]; }
imap_login() { curl -s --cacert "$CA_CRT" --url "imaps://$HOST_CORREO/INBOX" --user "$1:$2" -X 'EXAMINE INBOX'; }

titulo "Sistema"
echo "Equipo: $(hostname)   Fecha: $(date)"
grep PRETTY_NAME /etc/os-release
postconf -h mail_version | sed 's/^/Postfix /'
dovecot --version | sed 's/^/Dovecot /'

titulo "Servicios y puertos"
for s in postfix dovecot named rsyslog; do printf '%-10s %s\n' "$s" "$(systemctl is-active "$s")"; done
ss -ltnp | grep -E ':(25|587|993|143|110)\b' | awk '{print "TCP", $4, $6}' | sed -E 's/,pid=[0-9]+,fd=[0-9]+//g'

titulo "Buzones"
bash "$(dirname "$0")/crear_buzon.sh" --listar

titulo "Pruebas DNS"
esperar "MX de $DOMINIO"                              "10 $HOST_CORREO."   q "$DOMINIO" MX
esperar "A de $HOST_CORREO"                           "$IP_SERVIDOR"       q "$HOST_CORREO" A
esperar "SPF de $DOMINIO"                             "v=spf1 mx -all"     q "$DOMINIO" TXT
esperar "DMARC de $DOMINIO"                           "v=DMARC1"           q "_dmarc.$DOMINIO" TXT

titulo "Pruebas de configuracion y cifrado"
probar  "postfix activo"                              servicio_activo postfix
probar  "dovecot activo"                              servicio_activo dovecot
probar  "postfix check sin errores"                   postfix check
probar  "doveconf sin errores"                        doveconf -n
probar  "Certificado de correo firmado por la CA"     openssl verify -CAfile "$CA_CRT" "$MAIL_CRT"
esperar "Certificado valido para $HOST_CORREO"        "DNS:$HOST_CORREO"   openssl x509 -in "$MAIL_CRT" -noout -ext subjectAltName
probar  "Puerto 25 (SMTP) abierto"                    puerto_abierto 25
probar  "Puerto 587 (envio) abierto"                  puerto_abierto 587
probar  "Puerto 993 (IMAPS) abierto"                  puerto_abierto 993
negar   "Puerto 143 (IMAP sin cifrar) cerrado"        puerto_abierto 143
negar   "Puerto 110 (POP3 sin cifrar) cerrado"        puerto_abierto 110

titulo "Pruebas de seguridad SMTP"
esperar    "Puerto 25 ofrece STARTTLS"                "STARTTLS"           ehlo 25
no_aparece "587 no ofrece AUTH sin TLS"               "250-AUTH"           ehlo 587
esperar    "587 ofrece AUTH despues de STARTTLS"      "AUTH PLAIN LOGIN"   ehlo 587 --tls
esperar    "Sin relay abierto (otro dominio)"         "Relay access denied" \
    swaks --server "$HOST_CORREO" --port 25 --from x@otro.com --to alguien@gmail.com --quit-after RCPT --ehlo cliente.otro.com
esperar    "Destinatario inexistente rechazado"       "User unknown"       \
    swaks --server "$HOST_CORREO" --port 25 --from x@otro.com --to noexiste@$DOMINIO --quit-after RCPT --ehlo cliente.otro.com
esperar    "Contrasena incorrecta rechazada (535)"    "535"                \
    swaks --server "$HOST_CORREO" --port 587 --tls --auth LOGIN --auth-user "$A" --auth-password incorrecta --quit-after AUTH
esperar    "No se puede enviar como otro usuario"     "Sender address rejected" \
    swaks --server "$HOST_CORREO" --port 587 --tls --auth LOGIN --auth-user "$A" --auth-password "$CA_" --from "$B" --to "$B" --quit-after RCPT
esperar    "25 rechaza remitente @$DOMINIO sin login"  "Sender address rejected" \
    swaks --server "$HOST_CORREO" --port 25 --tls --from "$B" --to "$A" --quit-after RCPT --ehlo cliente.empresa.lan

titulo "Envio y recepcion entre buzones"
ASUNTO="Prueba 99_validar $(date +%H%M%S)"
esperar "$A envia a $B por 587 con TLS"              "queued as"          \
    swaks --server "$HOST_CORREO" --port 587 --tls --auth LOGIN --auth-user "$A" --auth-password "$CA_" \
          --from "$A" --to "$B" --header "Subject: $ASUNTO" --body "Mensaje de prueba de la Tarea 4.3"
sleep 3
esperar "Postfix entrego el mensaje (status=sent)"    "status=sent"        tail -n 40 "$LOG_CORREO"
esperar "Dovecot lo guardo en el buzon de $B"         "saved mail to INBOX" tail -n 40 "$LOG_CORREO"
probar  "El mensaje esta en el INBOX de $B"           hay_mensaje "$B" "$ASUNTO"
probar  "$B inicia sesion por IMAPS (993)"            imap_login "$B" "$CB"
negar   "IMAPS rechaza una contrasena incorrecta"     imap_login "$B" incorrecta
esperar "Alias postmaster entrega a $A"               "queued as"          \
    swaks --server "$HOST_CORREO" --port 25 --from externo@otro.com --to "postmaster@$DOMINIO" --header "Subject: Alias $ASUNTO" --ehlo cliente.otro.com
sleep 2
probar  "El mensaje del alias llego al buzon de $A"   hay_mensaje "$A" "Alias $ASUNTO"

titulo "Trazabilidad en $LOG_CORREO (ultimo mensaje)"
qid="$(grep -F "sasl_username=$A" "$LOG_CORREO" | tail -n1 | sed -E 's/.*: ([0-9A-F]+): client=.*/\1/')"
if [[ -n "$qid" ]]; then grep -F "$qid" "$LOG_CORREO" | tail -n 8; fi
grep -F "lmtp($B)" "$LOG_CORREO" | tail -n 2

titulo "Resultado"
echo "Pruebas que pasaron: $pasaron   Pruebas que fallaron: $fallaron"
echo "Evidencia guardada en: $SALIDA"
