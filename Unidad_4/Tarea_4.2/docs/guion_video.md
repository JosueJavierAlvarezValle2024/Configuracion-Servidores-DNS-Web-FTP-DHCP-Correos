# Guía para grabar el video — Tarea 4.2 (HTTPS y SFTP/FTPS)

El video debe demostrar:

1. Navegar al **sitio seguro HTTPS** y mostrar el **certificado**.
2. **Inspeccionar la configuración del Virtual Host**.
3. **Subir y descargar archivos por SFTP** con el **chroot activo**.

La **cámara web** debe aparecer en la **esquina inferior derecha**.

Duración sugerida: **7 a 10 minutos**.

---

## 0. Preparación (antes de presionar "Grabar")

### 0.1 OBS Studio

1. **Fuentes → + → Captura de pantalla** (o *Captura de ventana* de VirtualBox).
2. **Fuentes → + → Dispositivo de captura de video** → tu cámara web.
3. Haz la cámara pequeña (aprox. 1/5 del ancho) arrastrando sus esquinas rojas y colócala en la **esquina inferior derecha**.
4. Deja 2–3 líneas vacías al final de la terminal para que la cámara no tape texto.
5. Graba una prueba de 10 segundos y revísala.

### 0.2 Máquinas virtuales

| VM | Estado |
|---|---|
| **Xubuntuu** (servidor) | Encendida **primero** |
| **Cliente-U4** | Encendida después, con su MAC original (IP 192.168.50.20) |

### 0.3 Servidor listo

Abre **dos terminales** en el servidor y en ambas entra a la tarea:

```bash
cd /home/vboxuser/Configuracion-Servidores-DNS-Web-FTP-DHCP-Correos/Unidad_4/Tarea_4.2
```

Comprueba que todo pasa y anota la contraseña de `ftp_ventas`:

```bash
sudo bash scripts/99_validar.sh
sudo cat /root/tarea42_credenciales.txt
```

Debe terminar en **"Pruebas que fallaron: 0"**. Luego `clear`.

### 0.4 Cliente listo

En una terminal del cliente:

```bash
cd /home/vboxuser/Configuracion-Servidores-DNS-Web-FTP-DHCP-Correos/Unidad_4/Tarea_4.2
cp /etc/os-release /home/vboxuser/reporte_ventas.txt
clear
```

El archivo `reporte_ventas.txt` es el que vas a subir por SFTP. **Cierra Firefox** para empezar con él cerrado.

### 0.5 Consejos

- Agranda la letra de la terminal: **Ctrl + +**. En Firefox también puedes acercar con **Ctrl + +**.
- **Flecha ↑** recupera el comando anterior.
- Si un comando muestra `(END)` o `:` abajo, presiona **q** para salir.
- Escribe los comandos a mano. Si los copias desde otro programa, los `--` pueden convertirse en guion largo.
- La **@** se escribe con **AltGr + Q** (teclado latinoamericano) o **AltGr + 2** (teclado de España).

---

## 1. Presentación (≈ 20 s)

Muestra un texto o diapositiva con:

- Tarea 4.2 — Servicios web HTTPS y transferencia de archivos (FTPS/SFTP)
- Nombre, materia y fecha
- Servidor `srv01` 192.168.50.10 · Cliente 192.168.50.20 · Dominio `empresa.lan`

---

## 2. Servidor: servicios activos (≈ 30 s)

**Terminal 1 del servidor:**

```bash
systemctl status apache2 mariadb vsftpd ssh -n 0
```
> Los cuatro servicios en **active (running)**. Presiona **q** si queda en `(END)`.

---

## 3. Servidor: configuración del Virtual Host (≈ 1:30 min)

```bash
sudo apache2ctl -S
```
> Dos sitios en el mismo servidor: **www.empresa.lan** e **intranet.empresa.lan**, en los puertos **80** y **443**.

```bash
cat /etc/apache2/sites-available/www.empresa.lan.conf
```
> Señala:
> - Puerto **80**: `RewriteRule` que **redirige a HTTPS**.
> - Puerto **443**: `SSLEngine on`, `SSLCertificateFile`, `SSLCertificateKeyFile` y la cabecera **HSTS**.
> - `DocumentRoot` y `Options -Indexes`.

```bash
cat /etc/apache2/sites-available/intranet.empresa.lan.conf
```
> Señala `Require ip 192.168.50.0/24`: la intranet **solo** responde a la red interna.

```bash
cat /etc/apache2/conf-available/tarea42-seguridad.conf
```
> **Configuración del cifrado:** `SSLProtocol` (solo TLS 1.2 y 1.3), `SSLCipherSuite` y `ServerTokens Prod`.

```bash
ls -l /etc/ssl/empresa
```
> Certificados de la **CA local** (`ca.crt`) y del servidor (`servidor.crt`).

---

## 4. Cliente: navegar al sitio seguro (≈ 2 min)

1. Abre **Firefox** y escribe en la barra: **`http://www.empresa.lan`** (con http, sin la s).
   > Cambia solo a **https://www.empresa.lan** (redirección 301).
2. Recorre la página:
   - **Conexión segura: Cifrada con TLS**, versión **TLSv1.3**, cifrado y "Emitido por Empresa LAN - CA raiz".
   - **MariaDB: conectado** y la tabla de **8 empleados**: PHP consultando la base de datos.
3. **Mostrar el certificado:**
   1. Clic en el icono a la **izquierda de la dirección**.
   2. **Conexión segura**.
   3. **Más información del sitio** (o "Más información").
   4. **Ver certificado**.

   > Muestra:
   > - **Nombre común:** www.empresa.lan.
   > - **Emisor:** Empresa LAN - CA raiz.
   > - **Validez:** fechas "No antes / No después".
   > - **Nombres alternativos (SAN):** www, empresa.lan, intranet, ftp, srv01 y la IP.
   > - **Clave:** RSA 2048 · SHA-256.
   >
   > Haz clic en la pestaña **Empresa LAN - CA raiz** para mostrar el certificado de la autoridad certificadora.
4. Abre una pestaña nueva con **`https://intranet.empresa.lan`**.
   > El segundo virtual host: página verde de la intranet con "Dirección IP 192.168.50.20" y los avisos internos.

---

## 5. Cliente: pruebas web en la terminal (≈ 40 s)

```bash
bash scripts/cliente_pruebas.sh web
```
> Redirección **301**, certificado (asunto, emisor, SAN), **TLSv1.3** con *Verify return code: 0 (ok)*, los dos sitios con **200** y las cabeceras de seguridad.

---

## 6. Servidor: configuración de SFTP/FTPS y jaulas (≈ 1 min)

**Terminal 1 del servidor:**

```bash
cat /etc/ssh/sshd_config.d/50-tarea42-sftp.conf
```
> `Match Group sftpusuarios`, **`ChrootDirectory /srv/sftp/%u`** y `ForceCommand internal-sftp`.

```bash
cat /etc/vsftpd.conf
```
> Señala `anonymous_enable=NO`, **`chroot_local_user=YES`**, `local_root=/srv/sftp/$USER`, `ssl_enable=YES` y `force_local_logins_ssl=YES`.

```bash
sudo ls -la /srv/sftp/ftp_ventas
```
> La raíz de la jaula es de **root** (no se puede escribir en ella); el usuario escribe en **archivos**.

**Terminal 2 del servidor** (déjala visible):

```bash
sudo journalctl -u ssh -f
```

---

## 7. Cliente: SFTP con chroot (≈ 2 min)

```bash
sftp ftp_ventas@ftp.empresa.lan
```
> Escribe la contraseña de `ftp_ventas` (no se ve mientras la escribes). En la terminal 2 del servidor aparece la sesión abierta.

Dentro de `sftp>`, uno por uno:

```
pwd
```
> `Remote working directory: /`: el usuario cree que está en la raíz del servidor.

```
ls /
```
> Solo aparece **/archivos**: no ve `/etc`, `/home` ni la carpeta de otros usuarios.

```
cd /etc
```
> **Falla** (No such file or directory): la jaula impide salir.

```
cd ..
pwd
```
> Sigue en **/**: no se puede subir de nivel.

```
cd /archivos
put /home/vboxuser/reporte_ventas.txt
```
> **Subida** al 100 %.

```
get bienvenida.txt
```
> **Descarga** al 100 %.

```
ls -l
bye
```
> Se ven `bienvenida.txt` y `reporte_ventas.txt`.

Comprueba que el usuario **no tiene terminal**:

```bash
ssh ftp_ventas@ftp.empresa.lan
```
> Después de la contraseña: **"This service allows sftp connections only."**

---

## 8. Servidor: el archivo llegó a la jaula (≈ 30 s)

Detén el log de la terminal 2 con **Ctrl + C**. En la terminal 1:

```bash
sudo ls -l /srv/sftp/ftp_ventas/archivos
```
> `reporte_ventas.txt` está en **/srv/sftp/ftp_ventas/archivos**: lo que el usuario veía como `/archivos`.

---

## 9. Cliente: FTPS (≈ 40 s)

En el servidor, deja el log de vsftpd abierto en la terminal 2:

```bash
sudo tail -f /var/log/vsftpd.log
```

En el cliente:

```bash
bash scripts/cliente_pruebas.sh ftps
```
> Escribe la contraseña de `ftp_ventas`. Resultado:
> - Acceso **anónimo rechazado**.
> - Inicio de sesión **sin cifrar rechazado**.
> - Con **TLS**: entra y en la raíz solo ve **archivos** (chroot).
>
> En el log del servidor aparecen los intentos rechazados y el inicio de sesión correcto.

Detén el log con **Ctrl + C**.

---

## 10. Cierre: validación automática (≈ 40 s)

**Terminal 1 del servidor:**

```bash
sudo bash scripts/99_validar.sh
```
> Recorre las secciones **Pruebas WEB**, **Pruebas FTPS** y **Pruebas SFTP**, y termina en **"Pruebas que fallaron: 0"**.

Texto final: *"Tarea 4.2 completada: sitio HTTPS con PHP y MariaDB, y archivos por SFTP/FTPS con chroot"*.

---

## Si algo sale mal durante la grabación

| Problema | Solución |
|---|---|
| Firefox muestra "Advertencia: riesgo potencial de seguridad" | En el cliente: `bash scripts/cliente_pruebas.sh confiar-ca`, cierra y abre Firefox |
| El sitio no carga | Revisa que el servidor esté encendido; en el cliente, `ping -c 2 www.empresa.lan` |
| `sftp` pide confirmar la huella del servidor | Escribe `yes` (solo la primera vez) |
| `Permission denied` en sftp | Contraseña incorrecta: revísala con `sudo cat /root/tarea42_credenciales.txt` en el servidor |
| `put` falla con permiso denegado | Estás en `/`; primero `cd /archivos` |
| Un comando queda en `(END)` | Presiona **q** |

## Capturas para el reporte técnico

| # | Paso | Captura |
|---|---|---|
| 1 | 2 | Servicios activos |
| 2 | 3 | `apache2ctl -S` |
| 3 | 3 | Virtual host `www.empresa.lan.conf` |
| 4 | 3 | `tarea42-seguridad.conf` (cifrado) |
| 5 | 4 | Página principal con TLS y MariaDB |
| 6 | 4 | Certificado en Firefox (asunto, emisor, validez y SAN) |
| 7 | 4 | Intranet |
| 8 | 5 | `cliente_pruebas.sh web` |
| 9 | 6 | `50-tarea42-sftp.conf`, `vsftpd.conf` y la jaula |
| 10 | 7 | Sesión SFTP: pwd, ls /, cd /etc, put y get |
| 11 | 7 | `ssh` rechazado (solo sftp) |
| 12 | 8 | Archivo subido en `/srv/sftp/ftp_ventas/archivos` |
| 13 | 9 | `cliente_pruebas.sh ftps` y log de vsftpd |
| 14 | 10 | Resultado de `99_validar.sh` |
