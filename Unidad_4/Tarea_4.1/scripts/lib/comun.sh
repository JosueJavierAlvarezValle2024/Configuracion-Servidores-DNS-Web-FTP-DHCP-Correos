#!/usr/bin/env bash
# =============================================================================
#  comun.sh - Variables y funciones compartidas por los scripts de la Tarea 4.1
# =============================================================================
set -Eeuo pipefail

BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
CONFIG_DIR="$BASE_DIR/config"

# ---- Datos de la red (ver README, seccion 1) ----
DOMINIO="empresa.lan"
ZONA_INVERSA="50.168.192.in-addr.arpa"
IP_SERVIDOR="192.168.50.10"
PREFIJO="24"
IP_RESERVA="192.168.50.20"                 # reserva por MAC de cliente01

# Interfaces de la VM servidor (se pueden cambiar: sudo IFACE_LAN=... bash ...)
IFACE_LAN="${IFACE_LAN:-enp0s8}"           # Adaptador 2: red interna red-u4
IFACE_WAN="${IFACE_WAN:-enp0s3}"           # Adaptador 1: NAT de VirtualBox
CON_LAN="red-u4"                           # nombre de la conexion en NetworkManager

MARCA="TAREA41"
DIR_RESPALDOS="/root/tarea41_respaldos"

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
# Si el archivo no existia, deja una marca para que 98_revertir.sh lo borre.
respaldar() {
    local f="$1" r="$DIR_RESPALDOS$1"
    if [[ -e "$r.orig" || -e "$r.nuevo" ]]; then return 0; fi
    mkdir -p "$(dirname "$r")"
    if [[ -e "$f" ]]; then cp -a "$f" "$r.orig"; else touch "$r.nuevo"; fi
}

# Deja un archivo como estaba antes de la tarea
restaurar() {
    local f="$1" r="$DIR_RESPALDOS$1"
    if [[ -e "$r.orig" ]]; then
        cp -a "$r.orig" "$f"; rm -f "$r.orig"; ok "Restaurado: $f"
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
        dpkg -s "$p" &>/dev/null || error "No se pudo instalar $p (revisa la conexion a internet y apt update)"
    done
    ok "Paquetes listos: $*"
}

servicio_activo() { systemctl is-active --quiet "$1"; }
