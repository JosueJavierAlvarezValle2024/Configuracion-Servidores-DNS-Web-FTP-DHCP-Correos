#!/usr/bin/env bash
# =============================================================================
#  00_ejecutar_todo.sh - Configura el servidor completo en orden:
#  red -> DHCP -> DNS -> validacion
#
#  Uso: sudo bash scripts/00_ejecutar_todo.sh [--mac 08:00:27:aa:bb:cc]
# =============================================================================
source "$(dirname "$0")/lib/comun.sh"
requiere_root
DIR="$(dirname "$0")"

titulo "Actualizando la lista de paquetes"
apt-get update -q >/dev/null && ok "apt update" || aviso "apt update fallo; se intenta continuar"

bash "$DIR/01_red_servidor.sh"
bash "$DIR/02_dhcp.sh" "$@"
bash "$DIR/03_dns.sh"
bash "$DIR/99_validar.sh"
