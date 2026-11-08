# Guion del video — Tarea 4.1: DHCP y DNS (≈ 8 min)

El video debe demostrar:

1. La **asignación dinámica** de IP en el cliente.
2. La **reserva por MAC**.
3. La **renovación** de la concesión.
4. La **resolución de nombres directa e inversa** en la terminal.

La **cámara web** debe aparecer en la **esquina inferior derecha**.

> **Cómo usar este guion:** primero graba **solo la pantalla, sin voz**, siguiendo los pasos y comandos. Después grábate con cámara y micrófono explicando ese video: la columna **🎙️ Qué decir** de la tabla de pasos está junto a cada comando, en el mismo orden que la grabación. Léela como apoyo y dilo con tus palabras.

## Antes de grabar

- **OBS:** captura de pantalla completa (o de la ventana de VirtualBox) y la cámara web pequeña en la esquina inferior derecha. Deja 2–3 líneas vacías al final de la terminal para que la cámara no tape el texto. Haz una prueba de 10 segundos.
- **VirtualBox:**

  | VM | Estado al iniciar | Red |
  |---|---|---|
  | **Xubuntuu** (servidor) | Encendida | Adaptador 1 = NAT · Adaptador 2 = Red interna `red-u4` |
  | **Cliente-U4** | **Apagada** | Adaptador 1 = Red interna `red-u4` |

- En **Cliente-U4** pon una **MAC nueva**: *Configuración → Red → Adaptador 1 → Avanzado →* botón azul circular junto a "Dirección MAC" *→ Aceptar*. La MAC original es **`080027818D77`**: anótala, la vuelves a escribir en el paso 11.
- En el **servidor** abre **dos terminales** y en las dos entra a la tarea:
  `cd /home/vboxuser/Configuracion-Servidores-DNS-Web-FTP-DHCP-Correos/Unidad_4/Tarea_4.1`
- Comprueba que todo pasa: `sudo bash scripts/99_validar.sh` debe terminar en **"Pruebas que fallaron: 0"**. Después `clear`.
- Letra grande en la terminal (**Ctrl + +**). Si te equivocas, usa **Pausar grabación** en OBS.

## Pasos

Los pasos 2 a 8 y 10 se hacen en el **servidor**; los pasos 9 y 11 a 18, en el **cliente** (y VirtualBox); el 19, otra vez en el servidor.

| # | Tiempo | Comandos / acciones | Qué debe aparecer | 🎙️ Qué decir |
|---|---|---|---|---|
| 1 | ≈ 20 s | Pantalla inicial: el servidor con sus dos terminales abiertas | — | **Presentación.** Hola, soy Josué Javier Álvarez Valle, de la materia Administración de Servidores. En la Tarea 4.1 configuro los servicios base de una red: un servidor DHCP, que reparte las direcciones IP automáticamente, y un servidor DNS para el dominio empresa.lan, que traduce nombres a direcciones. La red es 192.168.50.0/24 y el servidor tiene la IP 192.168.50.10. |
| 2 | ≈ 15 s | **Terminal 1 del servidor:** `ip -br addr` | `lo`, `enp0s3` con una IP `10.0.2.x` (NAT) y `enp0s8` con **192.168.50.10/24**, ambas `UP` | **Red del servidor.** El servidor tiene dos tarjetas de red: enp0s3 sale a internet por el NAT de VirtualBox, y enp0s8 está en la red interna con la IP fija 192.168.50.10. |
| 3 | ≈ 15 s | `systemctl status isc-dhcp-server named -n 0` (si aparece `(END)` o `:`, presiona **q**) | ✓ Los dos servicios en **active (running)** | **Servicios.** Los dos servicios están activos: isc-dhcp-server, que es el DHCP, y named, que es el DNS de BIND9. |
| 4 | ≈ 30 s | `cat /etc/dhcp/dhcpd.conf` | `default-lease-time 3600`, `max-lease-time 14400`, los dos `range` (`.100`–`.149` y `.160`–`.200`) y el bloque `host cliente01` con `hardware ethernet 08:00:27:81:8d:77` y `fixed-address 192.168.50.20` | **Configuración del DHCP.** Aquí está la configuración del DHCP. La concesión dura una hora y como máximo cuatro. El rango dinámico va de la .100 a la .200, pero está partido en dos para excluir de la .150 a la .159. Abajo está la reserva: el equipo con esta MAC siempre recibe la 192.168.50.20. |
| 5 | ≈ 20 s | `cat /etc/bind/zones/db.empresa.lan` | El `SOA`, `NS ns1.empresa.lan.`, `MX 10 mail.empresa.lan.`, los registros `A` (srv01, ns1, mail, cliente01, impresora01) y los `CNAME` (www, ftp, intranet, webmail) | **Zona directa.** Esta es la zona directa de empresa.lan. Tiene el servidor de nombres NS, el de correo MX, los registros A que convierten un nombre en IP y los alias CNAME, como www, que apunta a srv01. |
| 6 | ≈ 15 s | `cat /etc/bind/zones/db.rev` | Zona `50.168.192.in-addr.arpa` con `10 PTR srv01.empresa.lan.`, `20 PTR cliente01.empresa.lan.` y `21 PTR impresora01.empresa.lan.` | **Zona inversa.** La zona inversa hace lo contrario: con los registros PTR, a partir de la IP se obtiene el nombre. Por ejemplo, la .10 es srv01 y la .20 es cliente01. |
| 7 | ≈ 15 s | `cat /etc/bind/named.conf.options` | `forwarders { 8.8.8.8; 1.1.1.1; };`, `forward first;` y `allow-query { red_interna; };` | **Reenviadores.** En las opciones de BIND están los reenviadores: todo lo que no es de empresa.lan, como google.com, se pregunta a Google y a Cloudflare. Además, solo la red interna puede hacer consultas. |
| 8 | ≈ 10 s | **Terminal 2 del servidor:** `sudo journalctl -u isc-dhcp-server -f` (déjala visible a un lado) | Las últimas líneas del log y el cursor esperando eventos nuevos | **Log en tiempo real.** En la segunda terminal dejo abierto el log del DHCP para ver en vivo las solicitudes de los clientes. |
| 9 | ≈ 40 s | **En VirtualBox:** encender **Cliente-U4** (ya con la MAC nueva). En el cliente, abrir una terminal: `ip -br addr` · `cat /sys/class/net/enp0s3/address` | En la terminal 2 del servidor: `DHCPDISCOVER` → `DHCPOFFER on 192.168.50.1xx` → `DHCPREQUEST` → `DHCPACK on 192.168.50.1xx` · en el cliente, `enp0s3` con una IP entre **.100 y .200** (nunca .150–.159) · la MAC nueva, distinta de `08:00:27:81:8d:77` | **Asignación dinámica.** Enciendo el cliente con una MAC que el servidor no conoce. En el log aparece el proceso DORA: Discover, el cliente busca un servidor; Offer, el servidor le ofrece una IP; Request, el cliente la acepta; y Ack, el servidor la confirma. Como esa MAC no tiene reserva, recibe una IP del rango dinámico. Aquí se ve la IP y la MAC con la que la pidió. |
| 10 | ≈ 20 s | **Terminal 1 del servidor:** `tail -n 12 /var/lib/dhcp/dhcpd.leases` | El bloque `lease 192.168.50.1xx {` con `starts`, `ends`, `binding state active` y `hardware ethernet` con la MAC nueva del cliente | **Concesión registrada.** El servidor guarda cada concesión dinámica en el archivo dhcpd.leases: la IP entregada, cuándo empieza, cuándo vence y la MAC del equipo que la tiene. |
| 11 | ≈ 40 s | **En VirtualBox:** apagar Cliente-U4 → *Configuración → Red → Adaptador 1 → Avanzado → Dirección MAC* = **`080027818D77`** → *Aceptar* → encender Cliente-U4 y abrir una terminal | En la terminal 2 del servidor: ✓ `DHCPACK on 192.168.50.20 to 08:00:27:81:8d:77` | **Reserva por MAC.** Apago el cliente y le regreso su MAC original, que sí está registrada en el servidor. Al encenderlo, el log muestra que el servidor le entrega la 192.168.50.20, la IP reservada para esa MAC. |
| 12 | ≈ 10 s | ⚠️ `cd /home/vboxuser/Configuracion-Servidores-DNS-Web-FTP-DHCP-Correos/Unidad_4/Tarea_4.1` (**no está en tu lista**, ver nota abajo) | La terminal queda en la carpeta `Tarea_4.1` | **Carpeta de la tarea.** En el cliente entro a la carpeta de la tarea, donde está el script de pruebas. |
| 13 | ≈ 40 s | `bash scripts/cliente_pruebas.sh` | `MAC en uso: 08:00:27:81:8d:77`, `enp0s3` con **192.168.50.20/24**, `dhcp_lease_time = 3600`, `routers = 192.168.50.10`, `domain_name = empresa.lan`, ✓ `>> IP RESERVADA por MAC: 192.168.50.20`; después el DNS configurado, `nslookup` directa e inversa y la tabla de registros con `dig` | **Datos recibidos.** El script del cliente muestra todo lo que recibió del servidor: la IP reservada .20, el tiempo de concesión de una hora, la puerta de enlace, el servidor DNS y el dominio empresa.lan. Al final hace un resumen rápido de las consultas DNS. |
| 14 | ≈ 30 s | ⚠️ `bash scripts/cliente_pruebas.sh renovar` (en tu lista va **sin** `renovar`, ver nota abajo) | `==== Renovando la concesion DHCP de enp0s3 ====` y `Concesion solicitada de nuevo` · en la terminal 2 del servidor, ✓ `DHCPREQUEST for 192.168.50.20` y `DHCPACK on 192.168.50.20` otra vez · el cliente conserva la **.20** | **Renovación.** Con la opción renovar, el cliente se desconecta y vuelve a pedir su IP. En el log del servidor aparece de nuevo la solicitud y la confirmación, y el cliente conserva su IP reservada con un nuevo tiempo de concesión. |
| 15 | ≈ 15 s | `clear` · `nslookup www.empresa.lan 192.168.50.10` · `dig cliente01.empresa.lan A +short` | `Server: 192.168.50.10`, `www.empresa.lan canonical name = srv01.empresa.lan.` y `Address: 192.168.50.10` · `192.168.50.20` | **Resolución directa.** Ahora pruebo el DNS. Al buscar www.empresa.lan, mi servidor responde que es un alias de srv01 y que su IP es la .10. Con dig, cliente01 da la .20. Eso es la resolución directa: de nombre a IP. |
| 16 | ≈ 15 s | `nslookup 192.168.50.10 192.168.50.10` · `dig -x 192.168.50.20 +short` | `10.50.168.192.in-addr.arpa name = srv01.empresa.lan.` · `cliente01.empresa.lan.` | **Resolución inversa.** Ahora al revés: busco la IP 192.168.50.10 y obtengo el nombre srv01.empresa.lan, y la .20 es cliente01. Eso es la resolución inversa, con los registros PTR. |
| 17 | ≈ 15 s | `dig empresa.lan MX +short` · `dig empresa.lan NS +short` | `10 mail.empresa.lan.` · `ns1.empresa.lan.` | **Otros registros.** El registro MX indica que el correo del dominio lo recibe mail.empresa.lan, con prioridad 10, y el NS indica que el servidor de nombres es ns1. |
| 18 | ≈ 20 s | `dig www.google.com +short` · `ping -c 2 www.google.com` | Una o varias IP públicas de Google · `2 packets transmitted, 2 received, 0% packet loss` | **Reenviadores e internet.** www.google.com no es de mi dominio, así que mi servidor reenvía la pregunta y devuelve su IP. Con ping compruebo que el cliente sale a internet a través del servidor. |
| 19 | ≈ 40 s | **Terminal 1 del servidor:** `sudo bash scripts/99_validar.sh` (sube un poco para mostrar las secciones *Pruebas DHCP* y *Pruebas DNS*) | La tabla de concesiones, los últimos eventos DHCP y todas las líneas ✓ `[PASA]`, entre ellas `cliente01 recibio su IP reservada 192.168.50.20` y `Nombre inexistente responde NXDOMAIN`; al final **`Pruebas que fallaron: 0`** | **Validación y cierre.** El script de validación comprueba de forma automática el DHCP y el DNS: la sintaxis, los rangos, la reserva, las zonas y cada tipo de registro. No hay ninguna falla. Con esto la red asigna direcciones de forma automática y resuelve los nombres del dominio. Gracias. |

**Nota del paso 12:** el cliente se acaba de encender, así que su terminal abre en `/home/vboxuser`. Sin el `cd`, `bash scripts/cliente_pruebas.sh` responde *"No such file or directory"*. Si en tu video el script sí corrió, es que hiciste el `cd` con la grabación en pausa: en ese caso salta esta fila.

**Nota del paso 14:** en tu lista el script aparece **dos veces sin opción**. Sin `renovar` solo vuelve a mostrar los mismos datos y en el log del servidor **no aparece nada nuevo**, así que la renovación no queda demostrada. Revisa tu video: si en la segunda ejecución no se ve el título *"Renovando la concesion DHCP de enp0s3"*, graba solo este paso de nuevo con `renovar`.

## Después de grabar

- La validación guarda su salida en `evidencias/validacion_<fecha>.txt`: es un entregable del repositorio.
- Toma las capturas para la memoria técnica:

  | # | Paso | Captura |
  |---|---|---|
  | 1 | Antes de grabar | Red de las dos VMs en VirtualBox |
  | 2 | 3 | `systemctl status` de los dos servicios |
  | 3 | 4–6 | `dhcpd.conf`, `db.empresa.lan` y `db.rev` |
  | 4 | 9 | IP dinámica en el cliente + log DORA del servidor |
  | 5 | 10 | `dhcpd.leases` con la concesión |
  | 6 | 11 y 13 | `DHCPACK on 192.168.50.20` + `>> IP RESERVADA por MAC` |
  | 7 | 14 | Renovación de la concesión |
  | 8 | 15–16 | `nslookup` directa e inversa |
  | 9 | 15–18 | `dig` de A, PTR, MX, NS y google.com |
  | 10 | 19 | Resultado de `99_validar.sh` |

## Si algo sale mal durante la grabación

| Problema | Solución |
|---|---|
| El cliente se queda en "conectando" | En el servidor: `sudo systemctl restart isc-dhcp-server`; en el cliente: `bash scripts/cliente_pruebas.sh renovar` |
| El cliente no recibe la .20 | Revisa que la MAC en VirtualBox sea exactamente `080027818D77` |
| `cat` o `tail` dicen *No such file or directory* | El nombre lleva **d**: `dhcpd.conf` y `dhcpd.leases` |
| `nslookup` responde `REFUSED` o no hay respuesta | El cliente no tiene IP: revisa con `ip -br addr` |
| No aparecen eventos en el log | Vuelve a abrir `sudo journalctl -u isc-dhcp-server -f` |
| Te equivocaste en un comando | Sigue grabando y repítelo; luego se puede recortar en el editor |
