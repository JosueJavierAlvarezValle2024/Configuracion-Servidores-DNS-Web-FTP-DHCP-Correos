#!/usr/bin/env bash
# =============================================================================
#  00_ejecutar_todo.sh - Configura la Tarea 4.3 completa en orden:
#  DNS -> certificado -> Postfix -> Dovecot -> buzones -> validacion
#
#  Requiere las Tareas 4.1 (DNS) y 4.2 (CA local).
#  Uso: sudo bash scripts/00_ejecutar_todo.sh [--password <clave>]
# =============================================================================
source "$(dirname "$0")/lib/comun.sh"
requiere_root
DIR="$(dirname "$0")"

titulo "Actualizando la lista de paquetes"
apt-get update -q >/dev/null && ok "apt update" || aviso "apt update fallo; se intenta continuar"

bash "$DIR/01_dns_correo.sh"
bash "$DIR/02_certificado_correo.sh"
bash "$DIR/03_postfix.sh"
bash "$DIR/04_dovecot.sh"
bash "$DIR/05_buzones.sh" "$@"
bash "$DIR/99_validar.sh"
