#!/usr/bin/env bash
# =============================================================================
#  04_ftp_sftp.sh - Servidor de archivos seguro: FTPS (vsftpd) y SFTP (OpenSSH)
#
#  1) Crea el grupo sftpusuarios y los usuarios locales ftp_ventas y ftp_soporte
#     (shell /usr/sbin/nologin: no pueden abrir una terminal en el servidor)
#  2) Prepara la jaula de cada usuario:
#        /srv/sftp/<usuario>            root:root 755  (raiz de la jaula)
#        /srv/sftp/<usuario>/archivos   usuario   750  (donde puede escribir)
#  3) vsftpd: sin anonimo, lista blanca de usuarios, chroot y TLS obligatorio
#  4) OpenSSH: SFTP enjaulado para el grupo sftpusuarios, sin terminal
#
#  Uso: sudo bash scripts/04_ftp_sftp.sh [--password <clave>]
#       --password  misma contrasena para los usuarios FTP (si no, se generan)
#  Las contrasenas quedan en /root/tarea42_credenciales.txt
# =============================================================================
source "$(dirname "$0")/lib/comun.sh"
requiere_root

CLAVE=""
while [[ $# -gt 0 ]]; do
    case "$1" in
        --password) CLAVE="${2:-}"; shift 2 ;;
        *) error "Opcion desconocida: $1" ;;
    esac
done
[[ -f "$SRV_CRT" ]] || error "Falta el certificado: ejecuta primero 02_certificados.sh"

titulo "Instalando vsftpd y OpenSSH"
instalar_paquetes vsftpd openssh-server sshpass

titulo "Usuarios y jaulas"
getent group "$GRUPO_SFTP" >/dev/null || groupadd "$GRUPO_SFTP"
mkdir -p "$SFTP_DIR"; chown root:root "$SFTP_DIR"; chmod 755 "$SFTP_DIR"
touch "$CREDENCIALES"; chmod 600 "$CREDENCIALES"

for u in "${USUARIOS_FTP[@]}"; do
    if ! id "$u" &>/dev/null; then
        useradd -M -d "$SFTP_DIR/$u" -s /usr/sbin/nologin -G "$GRUPO_SFTP" -c "Usuario FTP/SFTP ($MARCA)" "$u"
        ok "Usuario creado: $u"
    else
        usermod -aG "$GRUPO_SFTP" "$u"
        info "El usuario $u ya existia"
    fi

    # Contrasena: la indicada con --password, la guardada antes o una nueva
    clave="$CLAVE"
    [[ -n "$clave" ]] || clave="$(clave_de "$u")"
    [[ -n "$clave" ]] || clave="$(generar_clave 10)"
    echo "$u:$clave" | chpasswd
    sed -i "/^$u: /d" "$CREDENCIALES"; echo "$u: $clave" >> "$CREDENCIALES"

    # Raiz de la jaula: de root y sin escritura (OpenSSH y vsftpd lo exigen)
    install -d -m 755 -o root -g root "$SFTP_DIR/$u"
    install -d -m 750 -o "$u" -g "$u" "$SFTP_DIR/$u/archivos"
    if [[ ! -f "$SFTP_DIR/$u/archivos/bienvenida.txt" ]]; then
        echo "Carpeta de $u en ftp.$DOMINIO - solo tu puedes ver estos archivos." > "$SFTP_DIR/$u/archivos/bienvenida.txt"
        chown "$u:$u" "$SFTP_DIR/$u/archivos/bienvenida.txt"; chmod 640 "$SFTP_DIR/$u/archivos/bienvenida.txt"
    fi
    ok "Jaula: $SFTP_DIR/$u  (escritura en archivos/)"
done

titulo "vsftpd (FTPS)"
instalar_archivo "$CONFIG_DIR/vsftpd.conf"        /etc/vsftpd.conf          644
instalar_archivo "$CONFIG_DIR/vsftpd-tarea42.pam" /etc/pam.d/vsftpd-tarea42 644
respaldar /etc/vsftpd.userlist
printf '%s\n' "${USUARIOS_FTP[@]}" > /etc/vsftpd.userlist
ok "Usuarios autorizados en /etc/vsftpd.userlist: ${USUARIOS_FTP[*]}"
mkdir -p /var/run/vsftpd/empty
systemctl enable vsftpd --quiet
systemctl restart vsftpd || true
sleep 1
servicio_activo vsftpd && ok "vsftpd activo" || { journalctl -u vsftpd -n 15 --no-pager; error "vsftpd no inicio"; }

titulo "OpenSSH (SFTP enjaulado)"
instalar_archivo "$CONFIG_DIR/sshd-sftp.conf" /etc/ssh/sshd_config.d/50-tarea42-sftp.conf 644
sshd -t || error "La configuracion de sshd tiene errores"
ok "sshd -t sin errores"
systemctl enable ssh --quiet 2>/dev/null || true
systemctl restart ssh
# Ubuntu puede arrancar sshd bajo demanda (ssh.socket)
if servicio_activo ssh || servicio_activo ssh.socket; then ok "ssh activo"; else error "ssh no inicio"; fi

ss -ltnp | grep -E ':(21|22)\b' | awk '{print "Escuchando:", $4}'
echo
info "Contrasenas de los usuarios FTP/SFTP:  sudo cat $CREDENCIALES"
