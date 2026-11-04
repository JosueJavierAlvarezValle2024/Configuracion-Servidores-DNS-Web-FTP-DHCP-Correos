#!/usr/bin/env bash
# =============================================================================
#  comun.sh - Variables y funciones compartidas por los scripts de la Tarea 4.2
# =============================================================================
set -Eeuo pipefail

BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
CONFIG_DIR="$BASE_DIR/config"
SITIO_DIR="$BASE_DIR/sitio"

# ---- Datos del laboratorio (vienen de la Tarea 4.1) ----
DOMINIO="empresa.lan"
IP_SERVIDOR="192.168.50.10"
IFACE_WAN="${IFACE_WAN:-enp0s3}"

# ---- Web ----
WEB_DIR="/var/www/empresa"                 # www/, intranet/ y ca/
SITIOS=(www.empresa.lan intranet.empresa.lan)
DB_NOMBRE="empresa_db"
DB_USUARIO="webapp"
DB_INI="/etc/tarea42/db.ini"               # credenciales de la base, fuera del sitio web

# ---- Certificados ----
SSL_DIR="/etc/ssl/empresa"
CA_CRT="$SSL_DIR/ca.crt"
CA_KEY="$SSL_DIR/private/ca.key"
SRV_CRT="$SSL_DIR/servidor.crt"
SRV_KEY="$SSL_DIR/private/servidor.key"

# ---- FTP / SFTP ----
GRUPO_SFTP="sftpusuarios"
USUARIOS_FTP=(ftp_ventas ftp_soporte)
SFTP_DIR="/srv/sftp"                       # /srv/sftp/<usuario>/archivos
CREDENCIALES="/root/tarea42_credenciales.txt"

MARCA="TAREA42"
DIR_RESPALDOS="/root/tarea42_respaldos"

# ---- Salida con colores ----
VERDE='\033[0;32m'; ROJO='\033[0;31m'; AMARILLO='\033[1;33m'; AZUL='\033[1;34m'; NC='\033[0m'
titulo() { echo -e "\n${AZUL}==== $* ====${NC}"; }
ok()     { echo -e "${VERDE}[OK]${NC} $*"; }
info()   { echo -e "[..] $*"; }
aviso()  { echo -e "${AMARILLO}[AVISO]${NC} $*"; }
error()  { echo -e "${ROJO}[ERROR]${NC} $*" >&2; exit 1; }

requiere_root() {
    [[ $EUID -eq 0 ]] || error "Ejecuta con sudo: sudo bash $0"
}

# Guarda el archivo original una sola vez, antes de la primera modificacion.
# Si no existia, deja una marca para que 98_revertir.sh lo borre.
respaldar() {
    local f="$1" r="$DIR_RESPALDOS$1"
    if [[ -e "$r.orig" || -e "$r.nuevo" ]]; then return 0; fi
    mkdir -p "$(dirname "$r")"
    if [[ -e "$f" ]]; then cp -a "$f" "$r.orig"; else touch "$r.nuevo"; fi
}

# Deja un archivo (o carpeta) como estaba antes de la tarea
restaurar() {
    local f="$1" r="$DIR_RESPALDOS$1"
    if [[ -e "$r.orig" ]]; then
        rm -rf "$f"; cp -a "$r.orig" "$f"; rm -rf "$r.orig"; ok "Restaurado: $f"
    elif [[ -e "$r.nuevo" ]]; then
        rm -rf "$f"; rm -f "$r.nuevo"; ok "Eliminado: $f"
    fi
}

# instalar_archivo origen destino [permisos] [propietario:grupo]
instalar_archivo() {
    local origen="$1" destino="$2" modo="${3:-644}" dueno="${4:-root:root}"
    respaldar "$destino"
    mkdir -p "$(dirname "$destino")"
    install -m "$modo" -o "${dueno%%:*}" -g "${dueno##*:}" "$origen" "$destino"
    ok "Instalado: $destino"
}

instalar_paquetes() {
    info "Instalando: $*"
    DEBIAN_FRONTEND=noninteractive apt-get install -y -q "$@" >/dev/null || true
    local p
    for p in "$@"; do
        dpkg -s "$p" &>/dev/null || error "No se pudo instalar $p (revisa internet y ejecuta sudo apt update)"
    done
    ok "Paquetes listos: $*"
}

servicio_activo() { systemctl is-active --quiet "$1"; }

# Contrasena aleatoria facil de teclear (sin caracteres ambiguos)
generar_clave() { tr -dc 'A-HJ-NP-Za-km-z2-9' < /dev/urandom | head -c "${1:-12}" || true; }

# clave_de <usuario>: lee la contrasena guardada en el archivo de credenciales
clave_de() { awk -F': ' -v u="$1" '$1==u {print $2}' "$CREDENCIALES" 2>/dev/null; }
