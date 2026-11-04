#!/usr/bin/env bash
# =============================================================================
#  98_revertir.sh - Deshace la configuracion de la Tarea 4.2
#
#  Quita los virtual hosts, el sitio, la base de datos, los certificados,
#  los usuarios FTP/SFTP con sus carpetas y la configuracion de vsftpd y sshd.
#  No toca la Tarea 4.1 (DHCP, DNS y NAT siguen funcionando).
#
#  Uso: sudo bash scripts/98_revertir.sh [--purgar]
#       --purgar  ademas desinstala apache2, php, mariadb-server y vsftpd
# =============================================================================
source "$(dirname "$0")/lib/comun.sh"
requiere_root
PURGAR=0; [[ "${1:-}" == "--purgar" ]] && PURGAR=1

titulo "Apache"
for s in "${SITIOS[@]}"; do a2dissite -q "$s" 2>/dev/null || true; done
a2disconf -q tarea42-seguridad 2>/dev/null || true
for s in 000-default default-ssl; do
    if [[ -e "$DIR_RESPALDOS/sitio-desactivado-$s" ]]; then
        a2ensite -q "$s" && rm -f "$DIR_RESPALDOS/sitio-desactivado-$s" && ok "Sitio por defecto reactivado: $s"
    fi
done
for f in /etc/apache2/sites-available/www.empresa.lan.conf /etc/apache2/sites-available/intranet.empresa.lan.conf \
         /etc/apache2/conf-available/tarea42-seguridad.conf "$WEB_DIR"; do
    restaurar "$f"
done
servicio_activo apache2 && systemctl reload apache2 || true

titulo "Base de datos"
if servicio_activo mariadb; then
    mariadb -e "DROP DATABASE IF EXISTS $DB_NOMBRE; DROP USER IF EXISTS '$DB_USUARIO'@'localhost';" \
        && ok "Eliminadas la base $DB_NOMBRE y el usuario $DB_USUARIO"
fi
restaurar /etc/tarea42

titulo "Certificados"
restaurar /usr/local/share/ca-certificates/empresa-ca.crt
update-ca-certificates --fresh >/dev/null 2>&1 || true
restaurar "$SSL_DIR"

titulo "FTP / SFTP"
systemctl disable --now vsftpd --quiet 2>/dev/null || true
for f in /etc/vsftpd.conf /etc/pam.d/vsftpd-tarea42 /etc/vsftpd.userlist \
         /etc/ssh/sshd_config.d/50-tarea42-sftp.conf; do
    restaurar "$f"
done
sshd -t 2>/dev/null && systemctl restart ssh 2>/dev/null || true
for u in "${USUARIOS_FTP[@]}"; do
    id "$u" &>/dev/null && userdel "$u" && ok "Usuario eliminado: $u"
done
getent group "$GRUPO_SFTP" >/dev/null && groupdel "$GRUPO_SFTP" && ok "Grupo eliminado: $GRUPO_SFTP"
rm -rf "$SFTP_DIR" && ok "Eliminado: $SFTP_DIR"
rm -f "$CREDENCIALES"

if (( PURGAR )); then
    titulo "Desinstalando paquetes"
    DEBIAN_FRONTEND=noninteractive apt-get purge -y -q apache2 'php*' mariadb-server vsftpd sshpass >/dev/null || true
    DEBIAN_FRONTEND=noninteractive apt-get autoremove -y -q >/dev/null || true
    ok "Paquetes de la Tarea 4.2 desinstalados (openssh-server se conserva)"
fi

ok "Reversion terminada. Respaldos en $DIR_RESPALDOS"
