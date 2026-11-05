#!/usr/bin/env bash
# =============================================================================
#  01_dns_correo.sh - Registros DNS del correo en la zona empresa.lan
#
#  1) Comprueba que existan el MX y el A de mail.empresa.lan (Tarea 4.1)
#  2) Agrega el bloque de config/dns/registros_correo.zona (SPF, DMARC y
#     los alias smtp/imap) entre las marcas BEGIN/END TAREA43
#  3) Aumenta el serial de la zona, la revisa y la recarga en BIND
#
#  Uso: sudo bash scripts/01_dns_correo.sh
# =============================================================================
source "$(dirname "$0")/lib/comun.sh"
requiere_root

[[ -f "$ZONA" ]] || error "No existe $ZONA: primero configura el DNS de la Tarea 4.1"

titulo "Registros existentes (Tarea 4.1)"
grep -qE '^\s*@\s+IN\s+MX\s+10\s+mail\.empresa\.lan\.' "$ZONA" && ok "MX 10 mail.$DOMINIO." || error "Falta el registro MX en $ZONA"
grep -qE '^\s*mail\s+IN\s+A\s+192\.168\.50\.10' "$ZONA" && ok "mail A $IP_SERVIDOR" || error "Falta el registro A de mail en $ZONA"

titulo "Agregando SPF, DMARC y alias"
respaldar "$ZONA"
# Quita el bloque anterior (si existe) para regenerarlo
sed -i "/; BEGIN $MARCA/,/; END $MARCA/d" "$ZONA"
{
    echo "; BEGIN $MARCA - registros de correo (01_dns_correo.sh)"
    grep -vE '^\s*;|^\s*$' "$CONFIG_DIR/dns/registros_correo.zona"
    echo "; END $MARCA"
} >> "$ZONA"
sed -n "/; BEGIN $MARCA/,/; END $MARCA/p" "$ZONA"

titulo "Serial de la zona"
actual="$(awk '/; *serial/ {print $1; exit}' "$ZONA")"
[[ "$actual" =~ ^[0-9]+$ ]] || error "No se encontro el serial en $ZONA"
nuevo="$(date +%Y%m%d)01"
(( nuevo > actual )) || nuevo=$(( actual + 1 ))
sed -i "0,/$actual\(\s*; *serial\)/s//$nuevo\1/" "$ZONA"
ok "Serial: $actual -> $nuevo"

named-checkzone "$DOMINIO" "$ZONA" || error "La zona tiene errores (se puede restaurar con 98_revertir.sh)"
rndc reload "$DOMINIO" >/dev/null && ok "Zona recargada en BIND"
sleep 1

titulo "Comprobacion"
echo "MX   -> $(dig +short @"$IP_SERVIDOR" "$DOMINIO" MX)"
echo "A    -> $(dig +short @"$IP_SERVIDOR" "$HOST_CORREO" A)"
echo "SPF  -> $(dig +short @"$IP_SERVIDOR" "$DOMINIO" TXT)"
