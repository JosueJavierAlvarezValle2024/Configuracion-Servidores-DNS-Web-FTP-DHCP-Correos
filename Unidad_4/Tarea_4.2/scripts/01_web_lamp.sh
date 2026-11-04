#!/usr/bin/env bash
# =============================================================================
#  01_web_lamp.sh - Stack web: Apache + PHP + MariaDB
#
#  1) Instala Apache, PHP (con el modulo para MariaDB) y MariaDB
#  2) Asegura MariaDB: solo escucha en localhost, sin usuarios anonimos
#     ni base "test"
#  3) Crea la base empresa_db y el usuario "webapp" con permiso de SOLO LECTURA
#  4) Copia las paginas de prueba a /var/www/empresa
#
#  Uso: sudo bash scripts/01_web_lamp.sh
# =============================================================================
source "$(dirname "$0")/lib/comun.sh"
requiere_root

titulo "Instalando Apache, PHP y MariaDB"
instalar_paquetes apache2 php libapache2-mod-php php-mysql mariadb-server
systemctl enable --now apache2 mariadb --quiet
ok "$(apache2 -v | head -n1)"
ok "PHP $(php -r 'echo PHP_VERSION;')"
ok "$(mariadb --version)"

titulo "Asegurando MariaDB"
# Equivale a las preguntas de mariadb-secure-installation
mariadb <<SQL
DROP USER IF EXISTS ''@'localhost';
DROP USER IF EXISTS ''@'$(hostname)';
DROP DATABASE IF EXISTS test;
DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%';
FLUSH PRIVILEGES;
SQL
ok "Sin usuarios anonimos ni base de prueba"
# root entra solo desde el propio servidor con sudo (autenticacion unix_socket)
if grep -rqsE '^\s*bind-address\s*=\s*127\.0\.0\.1' /etc/mysql/; then
    ok "MariaDB escucha solo en 127.0.0.1 (no es accesible desde la red)"
else
    aviso "Revisa bind-address en /etc/mysql/mariadb.conf.d/50-server.cnf"
fi

titulo "Base de datos $DB_NOMBRE"
mariadb < "$CONFIG_DIR/empresa_db.sql"
ok "Tablas creadas: $(mariadb -N -e "SHOW TABLES FROM $DB_NOMBRE" | paste -sd' ' -)"

# Se reutiliza la contrasena si ya existe, para no romper las paginas
CLAVE_DB=""
[[ -f "$DB_INI" ]] && CLAVE_DB="$(awk -F' *= *' '$1=="clave" {gsub(/"/,"",$2); print $2}' "$DB_INI")"
[[ -n "$CLAVE_DB" ]] || CLAVE_DB="$(generar_clave 20)"

mariadb <<SQL
CREATE USER IF NOT EXISTS '$DB_USUARIO'@'localhost' IDENTIFIED BY '$CLAVE_DB';
ALTER USER '$DB_USUARIO'@'localhost' IDENTIFIED BY '$CLAVE_DB';
REVOKE ALL PRIVILEGES, GRANT OPTION FROM '$DB_USUARIO'@'localhost';
GRANT SELECT ON $DB_NOMBRE.* TO '$DB_USUARIO'@'localhost';
FLUSH PRIVILEGES;
SQL
ok "Usuario $DB_USUARIO@localhost con permiso SELECT sobre $DB_NOMBRE"

# Credenciales para PHP: solo root y el grupo www-data (Apache) pueden leerlas
respaldar /etc/tarea42
mkdir -p /etc/tarea42
cat > "$DB_INI" <<EOF
; $MARCA - credenciales de la base de datos para las paginas PHP
base    = "$DB_NOMBRE"
usuario = "$DB_USUARIO"
clave   = "$CLAVE_DB"
EOF
chown root:www-data "$DB_INI"; chmod 640 "$DB_INI"
ok "Credenciales en $DB_INI (640 root:www-data)"

titulo "Paginas de prueba en $WEB_DIR"
respaldar "$WEB_DIR"
mkdir -p "$WEB_DIR"/{www,intranet,ca}
cp -r "$SITIO_DIR/www/."      "$WEB_DIR/www/"
cp -r "$SITIO_DIR/intranet/." "$WEB_DIR/intranet/"
chown -R root:www-data "$WEB_DIR"
find "$WEB_DIR" -type d -exec chmod 755 {} +
find "$WEB_DIR" -type f -exec chmod 644 {} +
ok "Sitio publico: $WEB_DIR/www   Intranet: $WEB_DIR/intranet"
