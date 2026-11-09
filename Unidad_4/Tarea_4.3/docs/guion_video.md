# Guion del video — Tarea 4.3: correo SMTP/IMAP (≈ 10 min)

El video debe demostrar la **trazabilidad de un correo**:

1. El **envío** del mensaje.
2. El **monitoreo del log en tiempo real** en la consola.
3. La **recepción** en la bandeja del destinatario.

La **cámara web** debe aparecer en la **esquina inferior derecha**.

> **Cómo usar este guion:** primero graba **solo la pantalla, sin voz**, siguiendo los pasos y comandos. Después grábate con cámara y micrófono explicando ese video: la columna **🎙️ Qué decir** de la tabla de pasos está junto a cada comando, en el mismo orden que la grabación. Léela como apoyo y dilo con tus palabras.

## Antes de grabar

- **OBS:** captura de pantalla completa (o de la ventana de VirtualBox) y la cámara web pequeña en la esquina inferior derecha. Deja 2–3 líneas vacías al final de la terminal para que la cámara no tape el texto.
- Enciende **primero el servidor (Xubuntuu)** y después **Cliente-U4**.
- En el **servidor** abre **dos terminales** y en las dos entra a la tarea:
  `cd /home/vboxuser/Configuracion-Servidores-DNS-Web-FTP-DHCP-Correos/Unidad_4/Tarea_4.3`
- Comprueba que todo pasa con `sudo bash scripts/99_validar.sh` (**"Pruebas que fallaron: 0"**). Después `clear`.
- En el **cliente**: Thunderbird abierto con las cuentas de **Ana** (`ana.torres`) y **Pedro** (`pedro.ruiz`), las dos con salida por el puerto **587**. Abre también una terminal y entra a la misma carpeta (`.../Unidad_4/Tarea_4.3`).
- Letra grande en la terminal (**Ctrl + +**). Si un comando queda en `(END)` o `:`, presiona **q**.

## Pasos

Los pasos 1 a 10, 16 y 18 se hacen en el **servidor**; los pasos 11 a 15 y 17, en el **cliente**. Lo que dice "debería" puede variar un poco en tu equipo (fechas, números de mensaje, orden de las líneas).

| # | Tiempo | Comandos / acciones | Qué debería aparecer | 🎙️ Qué decir |
|---|---|---|---|---|
| 1 | ≈ 30 s | **Terminal 1 del servidor:** `systemctl status postfix -n 0` | `postfix.service` con **active (exited)** en verde (en Ubuntu es normal que diga *exited*: ese servicio solo arranca a `postfix@-`, que es el que trabaja) | **Presentación y servicio.** Hola, soy Josué Javier Álvarez Valle. En la Tarea 4.3 configuro un servidor de correo para el dominio empresa.lan: Postfix envía y recibe los mensajes, y Dovecot los guarda en cada buzón y se los entrega a los usuarios. Todo va cifrado con TLS. Primero reviso que Postfix esté activo. Dice "exited" porque en Ubuntu este servicio solo enciende al proceso real de Postfix y termina; eso es normal. |
| 2 | ≈ 30 s | `sudo ss -ltnp` | Una lista de puertos abiertos. Los del correo: **`:25`** y **`:587`** con `master` (Postfix) y **`:993`** con `dovecot`. No aparecen `:143` ni `:110`. También salen los de tareas anteriores (53, 80, 443, 21, 22…) | **Puertos.** Este comando muestra los puertos en los que el servidor está escuchando. Postfix usa el 25, por donde llega el correo de otros servidores, y el 587, por donde los usuarios envían su correo con usuario y contraseña. Dovecot usa el 993, que es IMAP cifrado: por ahí Thunderbird lee los mensajes. Los puertos sin cifrar, 143 y 110, no aparecen porque los desactivé. |
| 3 | ≈ 40 s | `dig empresa.lan MX +short` · `dig mail.empresa.lan +short` · `dig empresa.lan TXT +short` | `10 mail.empresa.lan.` · `192.168.50.10` · `"v=spf1 mx -all"` | **DNS del correo.** Para que el correo funcione, el DNS debe decir quién recibe el correo del dominio. El registro MX dice que es mail.empresa.lan, con prioridad 10. El segundo comando da su IP, la .10. El registro TXT es el SPF: dice que solo el servidor del MX puede enviar correo a nombre de empresa.lan; cualquier otro debe rechazarse. |
| 4 | ≈ 40 s | `cat /etc/postfix/main.cf` | Comentarios y las líneas `myhostname = mail.empresa.lan`, `virtual_mailbox_domains = empresa.lan`, `virtual_transport = lmtp:unix:private/dovecot-lmtp`, `smtpd_tls_cert_file = /etc/ssl/empresa/mail.crt`, `smtpd_sasl_type = dovecot` y `smtpd_relay_restrictions = ... reject_unauth_destination` | **Configuración de Postfix.** Este es el archivo principal de Postfix. Aquí está el nombre del servidor, mail.empresa.lan, y el dominio que atiende, empresa.lan. Los buzones son virtuales: no son usuarios de Linux, sino cuentas del dominio. Cuando llega un mensaje, Postfix se lo pasa a Dovecot por LMTP. También indico el certificado para cifrar, que las contraseñas las revisa Dovecot, y la regla relay: el servidor no reenvía correo de desconocidos hacia otros dominios. |
| 5 | ≈ 30 s | `cat /etc/postfix/master.cf` | La lista de servicios de Postfix; el bloque **`submission inet`** (puerto 587) con `smtpd_tls_security_level=encrypt`, `smtpd_sasl_auth_enable=yes` y `smtpd_sender_restrictions=reject_sender_login_mismatch,...` | **Puerto de envío.** master.cf dice qué servicios corre Postfix. El importante es submission, el puerto 587. Ahí el cifrado es obligatorio, con encrypt, y también la contraseña, con sasl_auth_enable. Además, sender_login_mismatch impide que alguien envíe con la dirección de otra persona: cada usuario solo puede enviar como él mismo. |
| 6 | ≈ 40 s | `cat /etc/dovecot/dovecot.conf` | `protocols = imap lmtp`, `mail_home = /var/mail/vhosts/...`, el bloque `namespace inbox` con Drafts, Sent, Trash y Junk, `passdb passwd-file` con `/etc/dovecot/usuarios`, **`ssl = required`**, `inet_listener imap` con `port = 0` y `imaps` con `port = 993`, y los `unix_listener` de **dovecot-lmtp** y **auth** | **Configuración de Dovecot.** Dovecot guarda los buzones en /var/mail/vhosts, uno por usuario, con sus carpetas: borradores, enviados, papelera y correo no deseado. Las cuentas y sus contraseñas cifradas están en el archivo usuarios. ssl required obliga a cifrar. El IMAP normal tiene puerto 0, o sea, apagado, y solo queda el 993 cifrado. Abajo están los dos enlaces con Postfix: uno para entregarle los mensajes y otro para revisar contraseñas. |
| 7 | ≈ 30 s | `cat scripts/crear_buzon.sh` | Los comentarios del inicio con los **tres pasos** (`/etc/dovecot/usuarios`, `/etc/postfix/buzones` y la carpeta `Maildir`) y, más abajo, `doveadm pw -s SHA512-CRYPT` y `doveadm mailbox create ... Sent Drafts Trash Junk` | **Script de buzones.** Para crear buzones uso este script. Hace tres cosas juntas: guarda el usuario con su contraseña cifrada para Dovecot, registra la dirección en Postfix para que acepte correo para ella, y crea su carpeta con enviados, borradores, papelera y no deseado. |
| 8 | ≈ 20 s | `sudo bash scripts/crear_buzon.sh luis.rios` (ver nota abajo) | ✓ `Buzon listo: luis.rios@empresa.lan` y debajo su carpeta (`home=/var/mail/vhosts/empresa.lan/luis.rios`) y sus `uid`/`gid` | **Crear un buzón.** Creo un buzón nuevo para Luis Ríos. El script le genera una contraseña y me confirma que el buzón está listo, con su carpeta en el servidor. |
| 9 | ≈ 20 s | `sudo bash scripts/crear_buzon.sh listar` (ver nota abajo) | `==== Buzones de empresa.lan ====` con las direcciones (ana.torres, pedro.ruiz, maria.lopez, carlos.vega y luis.rios), cuántos mensajes tiene cada una y su carpeta · después la lista de **alias**: `postmaster`, `abuse`, `admin`, `soporte` → ana.torres y `finanzas` → maria.lopez y pedro.ruiz | **Lista de buzones.** Con listar veo todos los buzones del dominio, cuántos mensajes tiene cada uno y dónde están guardados. Abajo están los alias: direcciones que no tienen buzón propio y redirigen a uno real. Por ejemplo, lo que llega a postmaster lo recibe Ana, y lo que llega a finanzas lo reciben María y Pedro. |
| 10 | ≈ 10 s | **Terminal 2 del servidor:** `sudo tail -f /var/log/mail.log` (déjala visible junto a Thunderbird) | Las últimas líneas del log de correo y el cursor esperando | **Log en tiempo real.** En la segunda terminal abro el registro del correo en tiempo real. Aquí van a aparecer, uno por uno, los pasos que siguen los mensajes que voy a enviar. |
| 11 | ≈ 40 s | **En el cliente:** Thunderbird con las dos cuentas → *Configuración de cuentas* de una cuenta → **Servidor de salida (SMTP)** → **Editar** (solo para ver) → *Cancelar* | Servidor `mail.empresa.lan`, puerto **587**, seguridad **STARTTLS**, autenticación *Contraseña normal* y el usuario `...@empresa.lan` | **Thunderbird.** En el cliente uso Thunderbird con dos cuentas ya configuradas, la de Ana y la de Pedro. En la configuración del servidor de salida se ve que envía por el puerto 587 con STARTTLS, o sea, la conexión se cifra antes de mandar la contraseña. Para leer el correo usa IMAP cifrado en el 993. |
| 12 | ≈ 50 s | Desde la cuenta de **Ana**: nuevo mensaje para `pedro.ruiz@empresa.lan` → **Enviar** · mirar el log | En el log, en este orden (todas con el mismo número de mensaje): `postfix/submission/smtpd ... connect from ...[192.168.50.20]` · `... TLS connection established ... TLSv1.3` · `... client=...[192.168.50.20], sasl_method=PLAIN, sasl_username=ana.torres@empresa.lan` · `postfix/cleanup ... message-id=<...>` · `postfix/qmgr ... from=<ana.torres@empresa.lan>` · `dovecot: lmtp(pedro.ruiz@empresa.lan) ... saved mail to INBOX` · `postfix/lmtp ... to=<pedro.ruiz@empresa.lan> ... status=sent` · `postfix/qmgr ... removed`. En Thunderbird el mensaje llega a la **bandeja de Pedro** | **Envío y trazabilidad.** Desde la cuenta de Ana le escribo a Pedro y lo envío. En el log se ve todo el recorrido. Primero Thunderbird se conecta al puerto 587 y la conexión se cifra con TLS 1.3. Luego Ana inicia sesión: aparece sasl_username con su dirección. Postfix le pone un número al mensaje, que se repite en todas las líneas y sirve para rastrearlo. El mensaje entra a la cola, Postfix se lo entrega a Dovecot y Dovecot confirma "saved mail to INBOX": ya está en el buzón de Pedro. status=sent confirma la entrega y removed indica que salió de la cola. Y en Thunderbird el mensaje aparece en la bandeja de Pedro. |
| 13 | ≈ 40 s | Desde la cuenta de **Pedro**: abrir el mensaje → **Reenviar** a Ana → **Enviar** · mirar el log | El mismo recorrido en el log, ahora con ✓ `sasl_username=pedro.ruiz@empresa.lan` y ✓ `lmtp(ana.torres@empresa.lan) ... saved mail to INBOX` · el mensaje *Fwd: ...* en la bandeja de Ana | **Reenvío.** Ahora, desde la cuenta de Pedro, reenvío el mensaje a Ana. En el log se repite el mismo camino, pero esta vez quien inicia sesión es Pedro, y Dovecot guarda el mensaje en el buzón de Ana. |
| 14 | ≈ 40 s | En la cuenta de **Ana**: abrir el reenvío → **código fuente del mensaje** (*Ctrl + U*) → cerrar | Las cabeceras: `Return-Path`, `Delivered-To: ana.torres@empresa.lan`, una línea `Received: from mail.empresa.lan by mail.empresa.lan ... with LMTP` (Dovecot) y otra `Received: from [192.168.50.20] ... (using TLSv1.3 with cipher ...) by mail.empresa.lan (Postfix) with ESMTPSA`; luego `Message-ID`, `From: pedro.ruiz@...`, `To: ana.torres@...` y `Subject: Fwd: ...` | **Información del mensaje.** Abro el código fuente del mensaje reenviado. Las cabeceras Received son como los sellos de un sobre: muestran por dónde pasó. Se leen de abajo hacia arriba. Primero salió de mi cliente, la .20, y llegó a mail.empresa.lan usando TLS 1.3; ESMTPSA quiere decir que se envió con cifrado y con usuario y contraseña. Después Postfix se lo pasó a Dovecot por LMTP. También se ven el remitente, el destinatario, el asunto con Fwd y el identificador único del mensaje. |
| 15 | ≈ 50 s | En la cuenta de **Ana**: **Responder** al reenvío → **Enviar** · mirar el log · en la cuenta de **Pedro**: abrir la respuesta → código fuente (*Ctrl + U*) → cerrar | En el log, ✓ `sasl_username=ana.torres@empresa.lan` y ✓ `lmtp(pedro.ruiz@empresa.lan) ... saved mail to INBOX` · en el código fuente, `Subject: Re: Fwd: ...`, las cabeceras `Received` y además **`In-Reply-To`** y **`References`** con el identificador del mensaje anterior | **Respuesta.** Ana responde al reenvío. En el log se ve otra vez el recorrido, ahora de Ana hacia Pedro. En el código fuente de la respuesta aparecen las mismas cabeceras Received y dos nuevas: In-Reply-To y References. Guardan el identificador del mensaje anterior; así el programa de correo sabe que es una respuesta y agrupa la conversación. |
| 16 | ≈ 5 s | **Terminal 2 del servidor:** detener el log con **Ctrl + C** | El log se detiene y vuelve el indicador de la terminal | **Fin del monitoreo.** Detengo el log; quedó registrado el recorrido de los tres mensajes. |
| 17 | ≈ 40 s | **Terminal del cliente:** `sudo bash scripts/cliente_pruebas.sh tls` → contraseña de `vboxuser` si la pide (ver nota abajo) | `==== SMTP envio (587) con STARTTLS ====` y `==== IMAPS (993) ====`; en cada uno: `subject=...CN = mail.empresa.lan`, `issuer=...` con la CA de Empresa LAN, `Protocol: TLSv1.3` (o `New, TLSv1.3, Cipher is ...`) y **`Verify return code: 0 (ok)`**; en el 993 también la línea `* OK [CAPABILITY ...]` de Dovecot | **Cifrado.** Desde la terminal del cliente compruebo el cifrado de los dos puertos. Tanto el 587, para enviar, como el 993, para leer, presentan el certificado de mail.empresa.lan, firmado por la autoridad certificadora de la empresa. Usan TLS 1.3, y "Verify return code 0, ok" significa que el cliente confía en el certificado. |
| 18 | ≈ 1 min | **Terminal 1 del servidor:** `sudo bash scripts/99_validar.sh` | Secciones *Pruebas DNS*, *Pruebas de configuracion y cifrado*, *Pruebas de seguridad SMTP* y *Envio y recepcion entre buzones* con líneas ✓ `[PASA]` (entre ellas `Sin relay abierto`, `Contrasena incorrecta rechazada (535)` y `No se puede enviar como otro usuario`); la *Trazabilidad* del último mensaje y al final **`Pruebas que fallaron: 0`** | **Validación y cierre.** Por último, el script de validación revisa todo de forma automática: los registros DNS, el certificado, que los puertos sin cifrar estén cerrados, que no haya relay abierto, que se rechacen las contraseñas incorrectas y que nadie pueda enviar con la dirección de otro. También envía un correo de prueba y comprueba que llegue. No hay fallas. Con esto el dominio empresa.lan tiene correo seguro y se puede rastrear cada mensaje. Gracias. |

**Nota de los pasos 12 a 15:** tu lista dice "dos usuarios" sin nombres. Escribí el orden Ana → Pedro (envío), Pedro → Ana (reenvío) y Ana → Pedro (respuesta), con las cuentas del guion anterior. Si en tu video usaste otras cuentas u otro orden, cambia los nombres en esas filas: el recorrido del log es el mismo.

**Nota del paso 8:** en tu lista dice `sricpts` y `Luis.rios`. Si se tecleó `sricpts`, sale *No such file or directory*. Y aunque la carpeta esté bien, el script **solo acepta minúsculas**: con `Luis.rios` responde *"Nombre no valido: Luis.rios (minusculas, numeros, punto, guion)"* y **no crea el buzón**. En ese caso luis.rios tampoco aparece en el paso 9. Revisa tu video.

**Nota del paso 9:** en tu lista falta `bash`: `sudo scripts/crear_buzon.sh listar`. Los scripts del repositorio no tienen permiso de ejecución, así que sin `bash` lo normal es un error del tipo *command not found* o *Permission denied*, y no se ve la lista. Si en tu video sí salió la lista, no hay problema.

**Nota del paso 17:** en tu lista dice `cliente_prueba.sh` (sin la **s**): ese archivo no existe y saldría *No such file or directory*. El `sudo` no hace falta, pero tampoco estorba: solo pide la contraseña de vboxuser.

## Después de grabar

- La validación guarda su salida en `evidencias/`: es un entregable del repositorio.
- Toma las capturas para el documento:

  | # | Paso | Captura |
  |---|---|---|
  | 1 | 1–2 | Servicio activo y puertos |
  | 2 | 3 | Registros MX, A y SPF |
  | 3 | 4–6 | Fragmentos de `main.cf`, `master.cf` y `dovecot.conf` |
  | 4 | 8–9 | Creación y listado de buzones |
  | 5 | 11 | Servidor de salida en Thunderbird (587 / STARTTLS) |
  | 6 | 12 | **Log completo del envío** (de `sasl_username` a `saved mail to INBOX`) |
  | 7 | 12 | **Mensaje recibido** en la bandeja de Pedro |
  | 8 | 14 | Código fuente del reenvío con las cabeceras Received |
  | 9 | 15 | Respuesta con `In-Reply-To` y `References` |
  | 10 | 17 | `cliente_pruebas.sh tls` |
  | 11 | 18 | Resultado de `99_validar.sh` |

## Si algo sale mal durante la grabación

| Problema | Solución |
|---|---|
| Thunderbird no envía y dice "usa el puerto 587" | Esa cuenta sale por el 25: *Configuración de cuentas → Servidor de salida (SMTP) → Editar* → puerto 587, STARTTLS |
| El mensaje no aparece en la bandeja | Presiona **Obtener mensajes**; revisa en el log si dice `status=sent` |
| Thunderbird pide la contraseña | Escríbela y marca **Recordar** (están en `sudo cat /root/tarea43_credenciales.txt`) |
| `Nombre no valido` al crear un buzón | Escribe el nombre en minúsculas: `luis.rios` |
| *No such file or directory* al correr un script | Revisa el nombre (`scripts/`, `cliente_pruebas.sh`) y que estés en la carpeta `Tarea_4.3` |
| El log no muestra nada | Revisa que lo abriste en el servidor con `sudo tail -f /var/log/mail.log` |
| Un comando queda en `(END)` | Presiona **q** |
