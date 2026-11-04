#!/usr/bin/env bash
# =============================================================================
#  99_validar.sh - Evidencia y pruebas automaticas de la Tarea 4.2
#
#  Web: servicios, virtual hosts, redireccion a HTTPS, certificado, versiones
#       de TLS, cabeceras de seguridad, PHP + MariaDB y restriccion de intranet
#  Archivos: FTPS (sin anonimo, TLS obligatorio, chroot) y SFTP enjaulado
#
#  Uso: sudo bash scripts/99_validar.sh
#  La salida tambien se guarda en evidencias/validacion_<fecha>.txt
# =============================================================================
source "$(dirname "$0")/lib/comun.sh"
requiere_root
set +e

mkdir -p "$BASE_DIR/evidencias"
SALIDA="$BASE_DIR/evidencias/validacion_$(date +%Y%m%d_%H%M%S).txt"
exec > >(tee "$SALIDA") 2>&1

pasaron=0; fallaron=0
pasa()  { echo -e "${VERDE}[PASA]${NC} $1"; ((pasaron++)); }
falla() { echo -e "${ROJO}[FALLA]${NC} $1"; ((fallaron++)); }
# probar "descripcion" comando...           -> pasa si el comando termina bien
probar() { local d="$1"; shift; if "$@" &>/dev/null; then pasa "$d"; else falla "$d"; fi; }
# negar "descripcion" comando...            -> pasa si el comando FALLA (acceso denegado)
negar()  { local d="$1"; shift; if "$@" &>/dev/null; then falla "$d"; else pasa "$d"; fi; }
# esperar "descripcion" "texto" comando...  -> pasa si la salida contiene el texto
esperar() {
    local d="$1" texto="$2"; shift 2
    local salida; salida="$("$@" 2>&1)"
    if grep -qF -- "$texto" <<< "$salida"; then pasa "$d -> $texto"; else falla "$d (no aparece: $texto)"; fi
}

URL_WWW="https://www.$DOMINIO"
URL_INT="https://intranet.$DOMINIO"
FTP_HOST="ftp.$DOMINIO"
U1="${USUARIOS_FTP[0]}"; U2="${USUARIOS_FTP[1]}"
C1="$(clave_de "$U1")"; C2="$(clave_de "$U2")"
SSH_OPC=(-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR -o PubkeyAuthentication=no)

# Ayudantes de las pruebas
encabezados() { curl -sk -I "$1"; }
pagina()      { curl -s --cacert "$CA_CRT" "$1"; }
tls()         { openssl s_client -connect "$IP_SERVIDOR:443" -servername "www.$DOMINIO" "$1" </dev/null; }
ftps()        { curl -s --ssl-reqd --cacert "$CA_CRT" "$@"; }
sftp_lote()   { sshpass -p "$2" sftp "${SSH_OPC[@]}" -b - "$1@$FTP_HOST" <<< "$3"; }
mariadb_en_red() { ss -ltn | grep -qE '(0\.0\.0\.0|\*|\[::\]|192\.168\.50\.10):3306'; }
# Intenta modificar datos con el usuario de la aplicacion (no deberia poder)
webapp_modifica() {
    local c; c="$(awk -F'"' '/^clave/ {print $2}' "$DB_INI")"
    mariadb -u "$DB_USUARIO" -p"$c" -e "UPDATE $DB_NOMBRE.avisos SET titulo = titulo WHERE 1 = 0"
}
ip_wan="$(ip -4 -o addr show "$IFACE_WAN" 2>/dev/null | awk '{print $4}' | cut -d/ -f1)"

titulo "Sistema"
echo "Equipo: $(hostname)   Fecha: $(date)"
grep PRETTY_NAME /etc/os-release
apache2 -v | head -n1
echo "PHP $(php -r 'echo PHP_VERSION;')"
mariadb --version
vsftpd -v 0>&- 2>&1 | head -n1
ssh -V 2>&1

titulo "Servicios y puertos"
for s in apache2 mariadb vsftpd ssh; do printf '%-10s %s\n' "$s" "$(systemctl is-active "$s")"; done
ss -ltnp | grep -E ':(21|22|80|443|3306)\b' | awk '{print "TCP", $4, $6}' | sed -E 's/,pid=[0-9]+,fd=[0-9]+//g'

titulo "Virtual Hosts (apache2ctl -S)"
apache2ctl -S 2>/dev/null | grep -E 'namevhost|port'

titulo "Certificado del servidor"
openssl x509 -in "$SRV_CRT" -noout -subject -issuer -dates
openssl x509 -in "$SRV_CRT" -noout -ext subjectAltName | tail -n +2

titulo "Pruebas WEB"
probar  "apache2 esta activo"                           servicio_activo apache2
probar  "mariadb esta activo"                           servicio_activo mariadb
probar  "Configuracion de Apache sin errores"           apache2ctl -t
esperar "Virtual host www.empresa.lan en 443"           "www.empresa.lan"      apache2ctl -S
esperar "Virtual host intranet.empresa.lan en 443"      "intranet.empresa.lan" apache2ctl -S
esperar "HTTP redirige a HTTPS (301)"                   "Location: https://www.$DOMINIO/" encabezados "http://www.$DOMINIO/"
probar  "Certificado firmado por la CA local"           openssl verify -CAfile "$CA_CRT" "$SRV_CRT"
esperar "Certificado valido para www.empresa.lan"       "DNS:www.$DOMINIO"     openssl x509 -in "$SRV_CRT" -noout -ext subjectAltName
probar  "HTTPS de www con certificado de confianza"     pagina "$URL_WWW/"
esperar "PHP genera la pagina"                          "Empresa LAN"          pagina "$URL_WWW/"
esperar "PHP consulta MariaDB"                          "MariaDB: conectado"   pagina "$URL_WWW/"
esperar "La pagina muestra los empleados"               "ana.torres@$DOMINIO"  pagina "$URL_WWW/"
esperar "Intranet responde a la red interna"            "Avisos internos"      pagina "$URL_INT/"
if [[ -n "$ip_wan" ]]; then
    esperar "Intranet rechaza otra red ($ip_wan) con 403" "403" \
        curl -s -o /dev/null -w '%{http_code}' --cacert "$CA_CRT" --interface "$ip_wan" "$URL_INT/"
fi
probar  "TLS 1.3 aceptado"                              tls -tls1_3
probar  "TLS 1.2 aceptado"                              tls -tls1_2
negar   "TLS 1.1 rechazado"                             tls -tls1_1
esperar "Cabecera HSTS"                                 "Strict-Transport-Security" encabezados "$URL_WWW/"
esperar "Cabecera Server sin version"                   "Server: Apache"       encabezados "$URL_WWW/"
negar   "MariaDB no escucha en la red"                  mariadb_en_red
negar   "Usuario webapp no puede modificar datos"       webapp_modifica

titulo "Pruebas FTPS (vsftpd)"
probar  "vsftpd esta activo"                            servicio_activo vsftpd
negar   "Acceso anonimo rechazado"                      ftps -u anonymous:correo@x "ftp://$FTP_HOST/"
negar   "Inicio de sesion sin cifrar rechazado"         curl -s -u "$U1:$C1" "ftp://$FTP_HOST/"
probar  "$U1 inicia sesion con TLS"                     ftps -u "$U1:$C1" "ftp://$FTP_HOST/"
esperar "Chroot: la raiz de $U1 solo contiene archivos" "archivos"             ftps -l -u "$U1:$C1" "ftp://$FTP_HOST/"
negar   "Chroot: $U1 no ve la carpeta de $U2"           bash -c "curl -s --ssl-reqd --cacert $CA_CRT -l -u '$U1:$C1' ftp://$FTP_HOST/ | grep -q $U2"
prueba="/tmp/prueba_ftps_$$.txt"; echo "Subido por FTPS $(date)" > "$prueba"
probar  "$U1 sube un archivo por FTPS"                  ftps -u "$U1:$C1" -T "$prueba" "ftp://$FTP_HOST/archivos/"
probar  "$U1 descarga el archivo por FTPS"              ftps -u "$U1:$C1" -o /dev/null "ftp://$FTP_HOST/archivos/$(basename "$prueba")"
rm -f "$prueba" "$SFTP_DIR/$U1/archivos/$(basename "$prueba")"

titulo "Pruebas SFTP (OpenSSH)"
probar  "sshd sin errores de configuracion"             sshd -t
esperar "Chroot: el directorio raiz de $U2 es /"        "Remote working directory: /" sftp_lote "$U2" "$C2" "pwd"
esperar "Chroot: en / solo esta archivos"               "archivos"             sftp_lote "$U2" "$C2" "ls /"
negar   "Chroot: $U2 no puede entrar a /etc"            sftp_lote "$U2" "$C2" "cd /etc"
prueba="/tmp/prueba_sftp_$$.txt"; echo "Subido por SFTP $(date)" > "$prueba"
probar  "$U2 sube y descarga un archivo por SFTP"       sftp_lote "$U2" "$C2" "put $prueba /archivos/
get /archivos/$(basename "$prueba") /tmp/descargado_$$.txt"
rm -f "$prueba" "/tmp/descargado_$$.txt" "$SFTP_DIR/$U2/archivos/$(basename "$prueba")"
esperar "$U2 no tiene terminal (solo SFTP)"             "sftp connections only" sshpass -p "$C2" ssh "${SSH_OPC[@]}" "$U2@$FTP_HOST" id

titulo "Ultimas lineas de los logs"
echo "--- /var/log/vsftpd.log"; tail -n 6 /var/log/vsftpd.log 2>/dev/null
echo "--- SFTP (journal de ssh)"; journalctl -u ssh --no-pager -n 200 2>/dev/null | grep -E 'session opened|open "|close "' | tail -n 6

titulo "Resultado"
echo "Pruebas que pasaron: $pasaron   Pruebas que fallaron: $fallaron"
echo "Evidencia guardada en: $SALIDA"
