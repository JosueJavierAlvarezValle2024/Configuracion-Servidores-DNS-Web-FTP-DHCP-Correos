#!/usr/bin/env bash
# =============================================================================
#  05_buzones.sh - Crea por lote los buzones de data/buzones.csv
#
#  Uso: sudo bash scripts/05_buzones.sh [--password <clave>]
#       --password  misma contrasena para todos (si no, cada uno recibe una)
#  Las contrasenas quedan en /root/tarea43_credenciales.txt
# =============================================================================
source "$(dirname "$0")/lib/comun.sh"
requiere_root

CLAVE=""
[[ "${1:-}" == "--password" ]] && CLAVE="${2:-}"

titulo "Buzones desde $(basename "$CSV_BUZONES")"
tail -n +2 "$CSV_BUZONES" | tr -d '\r' | while IFS=',' read -r usuario nombre depto; do
    [[ -n "$usuario" ]] || continue
    info "$nombre ($depto)"
    bash "$(dirname "$0")/crear_buzon.sh" "$usuario" ${CLAVE:+"$CLAVE"}
done

bash "$(dirname "$0")/crear_buzon.sh" --listar
echo
info "Contrasenas de los buzones:  sudo cat $CREDENCIALES"
