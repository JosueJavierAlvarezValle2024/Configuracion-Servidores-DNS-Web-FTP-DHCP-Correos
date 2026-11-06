# Guía para grabar el video — Tarea 4.3 (Correo SMTP/IMAP)

El video debe demostrar la **trazabilidad de un correo**:

1. El **envío** del mensaje.
2. El **monitoreo del log en tiempo real** en la consola.
3. La **recepción** en la bandeja del destinatario.

La **cámara web** debe aparecer en la **esquina inferior derecha**.

Duración sugerida: **7 a 10 minutos**.

> **Cómo usar este guion:** primero graba **solo la pantalla, sin voz**, siguiendo los pasos y comandos. Después grábate con cámara y micrófono explicando ese video: los bloques **🎙️ Qué decir** están en el mismo orden que la grabación. Léelos como apoyo y dilo con tus palabras.

---

## 0. Preparación (antes de presionar "Grabar")

### 0.1 OBS Studio

1. **Fuentes → + → Captura de pantalla** (o *Captura de ventana* de VirtualBox).
2. **Fuentes → + → Dispositivo de captura de video** → tu cámara web, pequeña, en la **esquina inferior derecha**.
3. Deja 2–3 líneas vacías al final de la terminal para que la cámara no tape texto.

### 0.2 Máquinas virtuales

| VM | Estado |
|---|---|
| **Xubuntuu** (servidor) | Encendida **primero** |
| **Cliente-U4** | Encendida después, con Thunderbird ya configurado con las cuentas de **Ana** y **Pedro** (las dos salen por el puerto **587**) |

### 0.3 Servidor listo

Abre **dos terminales** y en ambas:

```bash
cd /home/vboxuser/Configuracion-Servidores-DNS-Web-FTP-DHCP-Correos/Unidad_4/Tarea_4.3
```

Comprueba que todo pasa:

```bash
sudo bash scripts/99_validar.sh
```

Debe terminar en **"Pruebas que fallaron: 0"**. Luego `clear` en las dos terminales.

### 0.4 Consejos

- Agranda la letra de la terminal: **Ctrl + +**.
- Si un comando muestra `(END)` o `:` abajo, presiona **q**.
- **Flecha ↑** recupera el comando anterior.
- Escribe los comandos a mano (copiar desde otro programa puede cambiar `--` por un guion largo).
- Pon las dos ventanas lado a lado al enviar el correo: **Thunderbird (cliente)** y **el log (servidor)**.

---

## 1. Presentación (≈ 20 s)

> 🎙️ **Qué decir:** Hola, soy Josué Javier Álvarez Valle, de la materia Administración de Servidores. En la Tarea 4.3 configuro un servidor de correo electrónico para el dominio empresa.lan: Postfix como agente de transferencia, que envía y recibe los mensajes, y Dovecot como agente de entrega, que los guarda en cada buzón y los entrega a los usuarios por IMAP. Todo con cifrado TLS. Al final muestro el recorrido completo de un correo en el log.

Muestra un texto o diapositiva con:

- Tarea 4.3 — Servidor de correo SMTP/IMAP con TLS
- Nombre, materia y fecha
- Servidor `mail.empresa.lan` (192.168.50.10) · Postfix + Dovecot · Thunderbird

---

## 2. Servidor: servicios y puertos (≈ 40 s)

> 🎙️ **Qué decir:** Los dos servicios están activos: Postfix y Dovecot. Postfix escucha en el puerto 25, por donde llega el correo de otros servidores, y en el 587, por donde los usuarios envían el suyo con usuario y contraseña. Dovecot escucha en el 993, que es IMAP cifrado. Los puertos sin cifrar, 143 y 110, están cerrados.

**Terminal 1 del servidor:**

```bash
systemctl status postfix dovecot -n 0
```
> Los dos en **active**. Presiona **q** si queda en `(END)`.

```bash
sudo ss -ltnp
```
> Señala los puertos **25** y **587** (master, de Postfix) y **993** (dovecot). No aparecen 143 ni 110.

---

## 3. Servidor: registros DNS del correo (≈ 40 s)

> 🎙️ **Qué decir:** Para que el correo funcione, el DNS debe decir qué servidor recibe el correo del dominio. El registro MX indica que es mail.empresa.lan, y el registro A dice que su IP es la .10. Además agregué un registro SPF, que indica que solo los servidores del MX pueden enviar correo a nombre de empresa.lan; cualquier otro debe rechazarse.

```bash
dig empresa.lan MX +short
```
> **10 mail.empresa.lan.**

```bash
dig mail.empresa.lan +short
```
> **192.168.50.10**

```bash
dig empresa.lan TXT +short
```
> **"v=spf1 mx -all"** (SPF) y el registro de DMARC.

---

## 4. Servidor: configuración de Postfix y Dovecot (≈ 2 min)

> 🎙️ **Qué decir:** En main.cf de Postfix defino el nombre del servidor, mail.empresa.lan, y el dominio virtual empresa.lan: los buzones no son usuarios de Linux, sino cuentas del dominio. Los mensajes se entregan a Dovecot por LMTP. También configuro el certificado TLS, la autenticación a través de Dovecot y las reglas que evitan que el servidor reenvíe correo de desconocidos, lo que se llama relay abierto. En master.cf está el puerto 587: ahí el cifrado y la contraseña son obligatorios, y cada usuario solo puede enviar con su propia dirección. En dovecot.conf se ve dónde se guardan los buzones, los usuarios virtuales con sus contraseñas cifradas, el TLS obligatorio y los sockets que comparte con Postfix.

```bash
cat /etc/postfix/main.cf
```
> Señala `myhostname`, `virtual_mailbox_domains`, `virtual_transport = lmtp:...`, `smtpd_tls_cert_file`, `smtpd_sasl_type = dovecot` y `smtpd_relay_restrictions`.

```bash
cat /etc/postfix/master.cf
```
> Señala el bloque **submission** (587): `smtpd_tls_security_level=encrypt` y `smtpd_sasl_auth_enable=yes`.

```bash
cat /etc/dovecot/dovecot.conf
```
> Señala `mail_home`, `passdb passwd-file`, `ssl = required` y los `unix_listener` de **dovecot-lmtp** y **auth**.

---

## 5. Servidor: script de creación de buzones (≈ 1 min)

> 🎙️ **Qué decir:** Los buzones se crean con este script. Para cada buzón hace tres cosas: guarda el usuario y su contraseña cifrada para Dovecot, registra la dirección en Postfix para que acepte correo para ella, y crea su carpeta con Enviados, Borradores, Papelera y Correo no deseado. Ahora creo un buzón nuevo para Luis y lo listo junto a los demás y a los alias, como postmaster, que redirigen a un buzón real.

```bash
cat scripts/crear_buzon.sh
```
> Señala los tres pasos: `doveadm pw` (contraseña cifrada), la tabla `/etc/postfix/buzones` y las carpetas.

```bash
sudo bash scripts/crear_buzon.sh luis.rios
```
> **Buzón listo: luis.rios@empresa.lan**.

```bash
sudo bash scripts/crear_buzon.sh listar
```
> Los cinco buzones, cuántos mensajes tiene cada uno y los alias.

---

## 6. Servidor: log en tiempo real (≈ 10 s)

> 🎙️ **Qué decir:** Ahora abro el registro del correo en tiempo real. Aquí van a aparecer, uno por uno, todos los pasos que sigue el mensaje que voy a enviar.

**Terminal 2 del servidor** (déjala visible junto a Thunderbird):

```bash
sudo tail -f /var/log/mail.log
```

---

## 7. Cliente: enviar un correo de Ana a Pedro (≈ 2 min)

> 🎙️ **Qué decir:** En el cliente uso Thunderbird. La cuenta de Ana lee el correo por IMAP en el puerto 993 con SSL/TLS y envía por el 587 con STARTTLS, usando su contraseña. Redacto un mensaje para Pedro y lo envío. En el log se ve el recorrido completo. Primero, Ana se conecta al puerto 587, la conexión se cifra con TLS 1.3 y ella inicia sesión: aparece sasl_username con su dirección. Postfix le asigna un número al mensaje, que se repite en todas las líneas y sirve para rastrearlo. El gestor de la cola registra el remitente, Postfix se lo entrega a Dovecot por LMTP con status=sent, y Dovecot confirma "saved mail to INBOX": el mensaje ya está en el buzón de Pedro.

1. En Thunderbird, muestra rápidamente la configuración de la cuenta de **Ana**: **☰ → Configuración de cuentas → Configuración del servidor** (IMAP 993 SSL/TLS) y **Servidor de salida (SMTP)** (587 STARTTLS).
2. Selecciona la **Bandeja de entrada de ana.torres** → **+ Nuevo mensaje**:
   - **Para:** `pedro.ruiz@empresa.lan`
   - **Asunto:** `Trazabilidad - Tarea 4.3`
   - Un texto corto → **Enviar**.
3. Mira la terminal 2 del servidor. Aparecen, en orden:

| Línea | Qué significa |
|---|---|
| `postfix/submission/smtpd ... TLSv1.3 ...` | Conexión cifrada en el puerto 587 |
| `... sasl_username=ana.torres@empresa.lan` | Ana inició sesión |
| `postfix/cleanup ... message-id=<...>` | El mensaje recibe su identificador |
| `postfix/qmgr ... from=<ana.torres@empresa.lan>` | Entra a la cola |
| `dovecot: lmtp(pedro.ruiz@empresa.lan) ... saved mail to INBOX` | Dovecot lo guarda en el buzón de Pedro |
| `postfix/lmtp ... to=<pedro.ruiz@empresa.lan> ... status=sent` | Entrega confirmada |
| `postfix/qmgr ... removed` | Sale de la cola |

---

## 8. Cliente: recepción en la bandeja de Pedro (≈ 1 min)

> 🎙️ **Qué decir:** Ahora abro la bandeja de entrada de Pedro y ahí está el mensaje de Ana. Si abro el código fuente del correo, en las cabeceras Received se ve por dónde pasó: del cliente al servidor mail.empresa.lan, y que viajó cifrado con TLS. El mensaje enviado también quedó en la carpeta Enviados de Ana.

1. Haz clic en la **Bandeja de entrada de pedro.ruiz**. Si no aparece, presiona **Obtener mensajes**.
2. Abre el mensaje **"Trazabilidad - Tarea 4.3"**.
3. Presiona **Ctrl + U** (código fuente): señala las cabeceras **Received:** con `mail.empresa.lan` y `TLSv1.3`. Cierra esa ventana.
4. Muestra la carpeta **Enviados** de Ana.

---

## 9. Cliente: respuesta de Pedro a Ana (≈ 1 min)

> 🎙️ **Qué decir:** Ahora Pedro responde. En el log se repite el mismo recorrido, pero esta vez el usuario que inicia sesión es Pedro, y Dovecot guarda el mensaje en el buzón de Ana.

1. Con el mensaje abierto en la cuenta de Pedro → **Responder** → escribe un texto → **Enviar**.
2. En el log: `sasl_username=pedro.ruiz@empresa.lan` → `lmtp(ana.torres@empresa.lan) ... saved mail to INBOX`.
3. Abre la **Bandeja de entrada de ana.torres**: ahí está la respuesta.

Detén el log con **Ctrl + C**.

---

## 10. Cliente: certificado y cifrado (≈ 40 s)

> 🎙️ **Qué decir:** Desde la terminal del cliente compruebo el cifrado: tanto el puerto 587 como el 993 presentan el certificado de mail.empresa.lan, emitido por la autoridad certificadora local de la empresa, con TLS 1.3 y verificación correcta.

En una terminal del cliente:

```bash
cd /home/vboxuser/Configuracion-Servidores-DNS-Web-FTP-DHCP-Correos/Unidad_4/Tarea_4.3
bash scripts/cliente_pruebas.sh tls
```
> En los dos puertos: `subject=...CN=mail.empresa.lan`, `issuer=...Empresa LAN - CA raiz`, **TLSv1.3** y `Verify return code: 0 (ok)`.

---

## 11. Cierre: validación automática (≈ 1 min)

> 🎙️ **Qué decir:** Por último, el script de validación revisa todo de forma automática: los registros DNS, el certificado, que los puertos sin cifrar estén cerrados, que no haya relay abierto, que se rechacen contraseñas incorrectas y la suplantación de remitentes, y que un correo enviado llegue al buzón. Todas las pruebas pasan. Con esto el dominio empresa.lan tiene correo electrónico seguro y con trazabilidad completa. Gracias.

**Terminal 1 del servidor:**

```bash
sudo bash scripts/99_validar.sh
```
> Recorre **Pruebas DNS**, **Pruebas de seguridad SMTP** y **Envío y recepción**, y termina en **"Pruebas que fallaron: 0"**.

---

## Si algo sale mal durante la grabación

| Problema | Solución |
|---|---|
| Thunderbird no envía y dice "usa el puerto 587" | Esa cuenta tiene el servidor de salida en el 25: **☰ → Configuración de cuentas → Servidor de salida (SMTP) → Editar** → puerto 587, STARTTLS |
| El mensaje no aparece en la bandeja | Presiona **Obtener mensajes**; revisa en el log si dice `status=sent` |
| Thunderbird pide la contraseña | Escríbela y marca **Recordar** (están en `sudo cat /root/tarea43_credenciales.txt`) |
| El log no muestra nada | Revisa que lo abriste en el servidor con `sudo tail -f /var/log/mail.log` |
| Un comando queda en `(END)` | Presiona **q** |

## Capturas para el documento PDF

| # | Paso | Captura |
|---|---|---|
| 1 | 2 | Servicios activos y puertos |
| 2 | 3 | Registros MX, A y SPF |
| 3 | 4 | Fragmentos de `main.cf`, `master.cf` y `dovecot.conf` |
| 4 | 5 | Creación y listado de buzones |
| 5 | 7 | Configuración de la cuenta en Thunderbird (IMAP 993 / SMTP 587) |
| 6 | 7 | **Log completo del envío** (de `sasl_username` a `saved mail to INBOX`) |
| 7 | 8 | **Mensaje recibido** en la bandeja de Pedro |
| 8 | 8 | Código fuente del mensaje con las cabeceras Received |
| 9 | 9 | Respuesta recibida en la bandeja de Ana |
| 10 | 10 | `cliente_pruebas.sh tls` |
| 11 | 11 | Resultado de `99_validar.sh` |
