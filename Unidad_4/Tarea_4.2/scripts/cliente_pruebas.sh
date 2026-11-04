#!/usr/bin/env bash
# =============================================================================
#  cliente_pruebas.sh - Pruebas desde la VM CLIENTE (Tarea 4.2)
#
#  Uso: bash scripts/cliente_pruebas.sh [opcion]
#     confiar-ca   Descarga la CA de empresa.lan y la instala en el sistema
#                  y en Firefox (pide la contrasena de sudo). Hacerlo una vez.
#     web          Redireccion a HTTPS, certificado, TLS y sitios virtuales
#     ftps         Pruebas de FTPS: anonimo, sin cifrar y con TLS
#     (sin opcion) web + ftps
#  Las opciones se aceptan con o sin "--".
# =============================================================================
set -uo pipefail
DOMINIO="empresa.lan"
CA_URL="http://www.$DOMINIO/ca.crt"
CA_LOCAL="/usr/local/share/ca-certificates/empresa-ca.crt"
POLITICA_FF="/etc/firefox/policies/policies.json"
AZUL='\033[1;34m'; VERDE='\033[0;32m'; ROJO='\033[0;31m'; NC='\033[0m'
titulo() { echo -e "\n${AZUL}==== $* ====${NC}"; }
bien()   { echo -e "${VERDE}  OK${NC}  $*"; }
mal()    { echo -e "${ROJO}  NO${NC}  $*"; }

command -v curl >/dev/null || { echo "Instalando curl..."; sudo apt-get install -y -q curl >/dev/null; }

confiar_ca() {
    titulo "Descargando la CA desde $CA_URL"
    curl -fsS "$CA_URL" -o /tmp/empresa-ca.crt || { echo "No se pudo descargar (¿esta encendido el servidor?)"; exit 1; }
    openssl x509 -in /tmp/empresa-ca.crt -noout -subject -fingerprint -sha256
    # 1) Almacen del sistema: curl, wget, openssl, Thunderbird...
    sudo install -m 644 /tmp/empresa-ca.crt "$CA_LOCAL"
    sudo update-ca-certificates >/dev/null
    bien "CA instalada en el sistema"
    # 2) Firefox (paquete snap): politica empresarial que importa la CA
    sudo mkdir -p /etc/firefox/policies
    sudo install -m 644 /tmp/empresa-ca.crt /etc/firefox/policies/empresa-ca.crt
    echo '{ "policies": { "Certificates": { "Install": ["/etc/firefox/policies/empresa-ca.crt"] } } }' \
        | sudo tee "$POLITICA_FF" >/dev/null
    bien "Politica de Firefox creada: cierra y vuelve a abrir Firefox"
    echo "    Si Firefox sigue mostrando la advertencia, importala a mano:"
    echo "    Ajustes > Privacidad y seguridad > Ver certificados > Autoridades > Importar"
    echo "    y elige /tmp/empresa-ca.crt (marca 'Confiar para identificar sitios web')."
}

pruebas_web() {
    titulo "Redireccion HTTP -> HTTPS"
    curl -sI "http://www.$DOMINIO/" | grep -E '^HTTP|^Location'

    titulo "Certificado que presenta https://www.$DOMINIO"
    echo | openssl s_client -connect "www.$DOMINIO:443" -servername "www.$DOMINIO" 2>/dev/null \
        | openssl x509 -noout -subject -issuer -dates -ext subjectAltName 2>/dev/null
    echo | openssl s_client -connect "www.$DOMINIO:443" -servername "www.$DOMINIO" 2>/dev/null \
        | grep -E 'Protocol|Cipher is|Verify return code' | sed 's/^ */  /'

    titulo "Sitios virtuales (mismo servidor, distinto nombre)"
    for sitio in www intranet; do
        codigo="$(curl -s -o /tmp/pagina.html -w '%{http_code}' "https://$sitio.$DOMINIO/")"
        tituloweb="$(grep -o '<title>[^<]*' /tmp/pagina.html | sed 's/<title>//')"
        if [[ "$codigo" == "200" ]]; then bien "https://$sitio.$DOMINIO -> $codigo · $tituloweb"
        else mal "https://$sitio.$DOMINIO -> $codigo (¿importaste la CA? usa: confiar-ca)"; fi
    done
    curl -s "https://www.$DOMINIO/" | grep -q 'MariaDB: conectado' \
        && bien "La pagina PHP consulta MariaDB" || mal "La pagina no muestra datos de MariaDB"

    titulo "Cabeceras de seguridad"
    curl -sI "https://www.$DOMINIO/" | grep -iE '^(server|strict-transport|x-content|x-frame)'
}

pruebas_ftps() {
    titulo "FTPS en ftp.$DOMINIO"
    curl -s --ssl-reqd -u anonymous:x "ftp://ftp.$DOMINIO/" >/dev/null 2>&1 \
        && mal "El acceso anonimo esta permitido" || bien "Acceso anonimo rechazado"
    echo "  Escribe la contrasena de ftp_ventas (sudo cat /root/tarea42_credenciales.txt en el servidor):"
    read -rsp "  Contrasena: " clave; echo
    curl -s -u "ftp_ventas:$clave" "ftp://ftp.$DOMINIO/" >/dev/null 2>&1 \
        && mal "Acepta contrasenas sin cifrar" || bien "Inicio de sesion SIN cifrar rechazado"
    if lista="$(curl -s --ssl-reqd -l -u "ftp_ventas:$clave" "ftp://ftp.$DOMINIO/")"; then
        bien "Inicio de sesion con TLS correcto. Contenido de la raiz (jaula): $(echo $lista)"
    else
        mal "No se pudo iniciar sesion con TLS (¿contrasena correcta?)"
    fi
}

case "${1:-}" in
    confiar-ca|--confiar-ca) confiar_ca ;;
    web|--web)               pruebas_web ;;
    ftps|--ftps)             pruebas_ftps ;;
    "")                      pruebas_web; pruebas_ftps ;;
    *) echo "Opcion desconocida: $1"; exit 1 ;;
esac
