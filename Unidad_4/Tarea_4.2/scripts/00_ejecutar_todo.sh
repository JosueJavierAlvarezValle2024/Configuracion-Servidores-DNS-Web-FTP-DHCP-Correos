#!/usr/bin/env bash
# =============================================================================
#  00_ejecutar_todo.sh - Configura la Tarea 4.2 completa en orden:
#  LAMP -> certificados -> virtual hosts HTTPS -> FTPS/SFTP -> validacion
#
#  Requiere la Tarea 4.1 funcionando (DNS con www, intranet y ftp).
#  Uso: sudo bash scripts/00_ejecutar_todo.sh [--password <clave>]
# =============================================================================
source "$(dirname "$0")/lib/comun.sh"
requiere_root
DIR="$(dirname "$0")"

titulo "Comprobando la Tarea 4.1"
for n in www intranet ftp; do
    ip_n="$(dig +short "$n.$DOMINIO" @"$IP_SERVIDOR" | tail -n1)"
    [[ "$ip_n" == "$IP_SERVIDOR" ]] && ok "$n.$DOMINIO -> $ip_n" \
        || error "$n.$DOMINIO no resuelve a $IP_SERVIDOR: revisa el DNS de la Tarea 4.1"
done

titulo "Actualizando la lista de paquetes"
apt-get update -q >/dev/null && ok "apt update" || aviso "apt update fallo; se intenta continuar"

bash "$DIR/01_web_lamp.sh"
bash "$DIR/02_certificados.sh"
bash "$DIR/03_https_vhosts.sh"
bash "$DIR/04_ftp_sftp.sh" "$@"
bash "$DIR/99_validar.sh"
