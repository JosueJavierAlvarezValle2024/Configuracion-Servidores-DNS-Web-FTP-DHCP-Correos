# Guía para grabar el video — Tarea 4.1 (DHCP y DNS)

El video debe demostrar:

1. La **asignación dinámica** de IP en el cliente.
2. La **reserva por MAC**.
3. La **renovación** de la concesión.
4. La **resolución de nombres directa e inversa** en la terminal.

La **cámara web** debe aparecer en la **esquina inferior derecha**.

Duración sugerida: **6 a 9 minutos**.

> **Cómo usar este guion:** primero graba **solo la pantalla, sin voz**, siguiendo los pasos y comandos. Después grábate con cámara y micrófono explicando ese video: los bloques **🎙️ Qué decir** están en el mismo orden que la grabación. Léelos como apoyo y dilo con tus palabras.

---

## 0. Preparación (antes de presionar "Grabar")

### 0.1 OBS Studio

1. **Fuentes → + → Captura de pantalla** (o *Captura de ventana* de VirtualBox).
2. **Fuentes → + → Dispositivo de captura de video** → elige tu cámara web.
3. Haz la cámara pequeña (aprox. 1/5 del ancho) arrastrando sus esquinas rojas y muévela a la **esquina inferior derecha**, con un margen pequeño.
4. Revisa que la cámara **no tape** la parte baja de la terminal: deja 2–3 líneas vacías al final de la terminal.
5. Haz una grabación de prueba de 10 segundos y revísala.

### 0.2 VirtualBox

| VM | Estado al iniciar | Red |
|---|---|---|
| **Xubuntuu** (servidor) | Encendida | Adaptador 1 = NAT · Adaptador 2 = Red interna `red-u4` |
| **Cliente-U4** | **Apagada** | Adaptador 1 = Red interna `red-u4` |

En **Cliente-U4** pon una **MAC nueva** para empezar con la IP dinámica:
**Configuración → Red → Adaptador 1 → Avanzado → botón azul circular junto a "Dirección MAC" → Aceptar.**

> La MAC original del cliente es **`080027818D77`**. Anótala: la vas a volver a escribir en el paso 5.

### 0.3 Servidor listo

En el servidor, abre **dos terminales** y en ambas entra a la tarea:

```bash
cd /home/vboxuser/Configuracion-Servidores-DNS-Web-FTP-DHCP-Correos/Unidad_4/Tarea_4.1
```

Actualiza el repo y comprueba que todo pasa antes de grabar:

```bash
git pull
sudo bash scripts/99_validar.sh
```

Debe terminar en **"Pruebas que fallaron: 0"**. Luego limpia la pantalla con `clear`.

### 0.4 Consejos

- Agranda la letra de la terminal: **Ctrl + +** (o *Editar → Preferencias → Apariencia*).
- Escribe despacio; si te equivocas, **flecha ↑** recupera el comando anterior.
- Si se abre `nano` por error: **Ctrl + X** para salir.
- Pegar en la terminal: **Ctrl + Shift + V**.
- Si no te sale `~`, escribe la ruta completa `/home/vboxuser/...`.

---

## 1. Presentación (≈ 20 s)

> 🎙️ **Qué decir:** Hola, soy Josué Javier Álvarez Valle, de la materia Administración de Servidores. En la Tarea 4.1 configuro los servicios base de una red: un servidor DHCP, que reparte las direcciones IP automáticamente, y un servidor DNS para el dominio empresa.lan, que traduce nombres a direcciones. La red es 192.168.50.0/24 y el servidor tiene la IP 192.168.50.10.

Muestra en pantalla un texto o diapositiva con:

- Tarea 4.1 — Servidor DHCP y DNS
- Nombre, materia y fecha
- Dominio `empresa.lan` · Red `192.168.50.0/24` · Servidor `192.168.50.10`

---

## 2. Servidor: configuración y servicios (≈ 1:30 min)

> 🎙️ **Qué decir:** El servidor tiene dos tarjetas de red: enp0s3 sale a internet y enp0s8 está en la red interna con la IP fija .10. Los dos servicios, isc-dhcp-server y named, están activos. En dhcpd.conf se ve el tiempo de concesión de una hora, el rango dinámico partido en dos para excluir de la .150 a la .159, y la reserva de cliente01 por su dirección MAC. La zona directa tiene los registros NS, MX, A y CNAME; la zona inversa, los PTR; y los reenviadores envían a Google y Cloudflare todo lo que no es de empresa.lan. En otra terminal dejo abierto el log del DHCP para ver las solicitudes en tiempo real.

**Terminal 1 del servidor:**

```bash
ip -br addr
```
> Se ve `enp0s3` (NAT) y `enp0s8` con **192.168.50.10**.

```bash
systemctl status isc-dhcp-server named -n 0
```
> Los dos servicios en **active (running)**. Si abajo aparece `(END)` o `:`, presiona **q** para volver.

```bash
cat /etc/dhcp/dhcpd.conf
```
> Señala: tiempos de concesión, los **dos `range`** (la exclusión .150–.159) y la **reserva `host cliente01`**.

```bash
cat /etc/bind/zones/db.empresa.lan
```
> Señala los registros **NS, MX, A y CNAME**.

```bash
cat /etc/bind/zones/db.rev
```
> Señala los registros **PTR**.

```bash
cat /etc/bind/named.conf.options
```
> Los **reenviadores** 8.8.8.8 y 1.1.1.1.

**Terminal 2 del servidor** (déjala visible a un lado durante el resto del video):

```bash
sudo journalctl -u isc-dhcp-server -f
```

---

## 3. Cliente: asignación DINÁMICA (≈ 1 min)

> 🎙️ **Qué decir:** Enciendo el cliente con una MAC que el servidor no conoce. En el log aparece el proceso DORA: Discover, el cliente busca un servidor; Offer, el servidor le ofrece una IP; Request, el cliente la acepta; y Ack, el servidor la confirma. Como esa MAC no tiene reserva, recibe una IP del rango dinámico.

1. **Enciende Cliente-U4** (con la MAC nueva). Mientras arranca, mira la terminal 2 del servidor:
   aparecen **DHCPDISCOVER → DHCPOFFER → DHCPREQUEST → DHCPACK** con una IP **.10x**.
2. En el cliente, abre una terminal:

```bash
ip -br addr
```
> IP entre **192.168.50.100 y .200** (nunca .150–.159).

```bash
cat /sys/class/net/enp0s3/address
```
> Muestra la MAC nueva (distinta a `08:00:27:81:8d:77`).

---

## 4. Servidor: concesión registrada (≈ 30 s)

> 🎙️ **Qué decir:** El servidor guarda cada concesión dinámica en el archivo dhcpd.leases: la IP entregada, cuándo empieza, cuándo vence y la MAC del equipo que la tiene.

**Terminal 1 del servidor:**

```bash
tail -n 12 /var/lib/dhcp/dhcpd.leases
```
> El bloque `lease 192.168.50.10x` con `starts`, `ends`, `hardware ethernet` (la MAC nueva) y `binding state active`.

---

## 5. Cliente: RESERVA por MAC (≈ 1:30 min)

> 🎙️ **Qué decir:** Ahora regreso el cliente a su MAC original, que sí está registrada. Al encender, el log muestra DHCPACK con la 192.168.50.20, la IP reservada. El script del cliente confirma todos los datos que recibió: la IP, la puerta de enlace, el servidor DNS, el dominio y el tiempo de concesión.

1. **Apaga Cliente-U4.**
2. En VirtualBox: **Configuración → Red → Adaptador 1 → Avanzado → Dirección MAC** → escribe **`080027818D77`** → **Aceptar**.
3. **Enciende Cliente-U4.** En la terminal 2 del servidor aparece **`DHCPACK on 192.168.50.20 to 08:00:27:81:8d:77`**.
4. En el cliente:

```bash
cd /home/vboxuser/Configuracion-Servidores-DNS-Web-FTP-DHCP-Correos/Unidad_4/Tarea_4.1
bash scripts/cliente_pruebas.sh
```
> Muestra la MAC `08:00:27:81:8d:77`, la IP **192.168.50.20**, el tiempo de concesión (3600 s), puerta de enlace, DNS y dominio recibidos, y la línea **">> IP RESERVADA por MAC"**.

---

## 6. Cliente: RENOVACIÓN de la concesión (≈ 40 s)

> 🎙️ **Qué decir:** Con la opción renovar, el cliente suelta su IP y la vuelve a pedir. En el log se repite el ciclo completo y el cliente conserva su IP reservada con un nuevo vencimiento.

```bash
bash scripts/cliente_pruebas.sh renovar
```
> En la terminal 2 del servidor se ve de nuevo el ciclo **DISCOVER → OFFER → REQUEST → ACK** y el cliente conserva la **.20**.

Detén el log del servidor con **Ctrl + C** cuando termines este paso.

---

## 7. Cliente: resolución de nombres (≈ 2 min)

> 🎙️ **Qué decir:** Ahora pruebo el DNS. Al buscar www.empresa.lan, el servidor responde que es un alias de srv01 y que su IP es la .10: esa es la resolución directa. Al buscar la IP 192.168.50.10 obtengo el nombre srv01.empresa.lan: la resolución inversa. Con dig consulto también el registro MX del correo, el NS y el PTR del cliente. Por último, www.google.com comprueba que los reenviadores funcionan, y el ping demuestra que el cliente sale a internet a través del servidor.

Limpia la pantalla del cliente con `clear`. En `nslookup` se escribe la IP del servidor al final para que se vea que responde **tu** DNS (línea `Server: 192.168.50.10`).

**Resolución directa:**

```bash
nslookup www.empresa.lan 192.168.50.10
```
> `www.empresa.lan` es alias (**CNAME**) de `srv01.empresa.lan` → **192.168.50.10**.

```bash
dig cliente01.empresa.lan A +short
```
> **192.168.50.20**

**Resolución inversa:**

```bash
nslookup 192.168.50.10 192.168.50.10
```
> `10.50.168.192.in-addr.arpa name = srv01.empresa.lan.`

```bash
dig -x 192.168.50.20 +short
```
> **cliente01.empresa.lan.**

**Otros registros:**

```bash
dig empresa.lan MX +short
```
> **10 mail.empresa.lan.**

```bash
dig empresa.lan NS +short
```
> **ns1.empresa.lan.**

**Reenviadores (nombre de internet):**

```bash
dig www.google.com +short
```
> IPs públicas de Google: el servidor reenvió la consulta a 8.8.8.8 / 1.1.1.1.

```bash
ping -c 2 www.google.com
```
> El cliente sale a internet a través del servidor (NAT).

---

## 8. Cierre: validación automática (≈ 40 s)

> 🎙️ **Qué decir:** El script de validación comprueba de forma automática el DHCP y el DNS, y no hay ninguna falla. Con esto la red ya asigna direcciones de forma automática y resuelve los nombres del dominio. Gracias.

**Terminal 1 del servidor:**

```bash
sudo bash scripts/99_validar.sh
```
> Desplázate por la sección **Pruebas DHCP** y **Pruebas DNS** y termina en **"Pruebas que fallaron: 0"**.

Termina el video con un texto: *"Tarea 4.1 completada — DHCP y DNS funcionando en empresa.lan"*.

---

## Si algo sale mal durante la grabación

| Problema | Solución |
|---|---|
| El cliente se queda en "conectando" | En el servidor: `sudo systemctl restart isc-dhcp-server` y en el cliente `bash scripts/cliente_pruebas.sh renovar` |
| El cliente no recibe la .20 | Revisa que la MAC en VirtualBox sea exactamente `080027818D77` |
| `nslookup` responde `REFUSED` | El cliente no tiene IP: revisa con `ip -br addr` |
| No aparecen eventos en el log | Vuelve a abrir `sudo journalctl -u isc-dhcp-server -f` |
| Te equivocaste en un comando | Sigue grabando y repítelo; luego se puede recortar en el editor |

## Capturas para la memoria técnica

Toma captura en estos momentos (tecla **Impr Pant** o la herramienta de Xubuntu):

| # | Paso | Captura |
|---|---|---|
| 1 | 0.2 | Red de las dos VMs en VirtualBox |
| 2 | 2 | `systemctl status` de los dos servicios |
| 3 | 2 | `dhcpd.conf`, `db.empresa.lan` y `db.rev` |
| 4 | 3 | IP dinámica en el cliente + log DORA del servidor |
| 5 | 4 | `dhcpd.leases` con la concesión |
| 6 | 5 | IP reservada .20 + `DHCPACK on 192.168.50.20` |
| 7 | 6 | Renovación de la concesión |
| 8 | 7 | `nslookup` directa e inversa |
| 9 | 7 | `dig` de A, PTR, MX, NS y google.com |
| 10 | 8 | Resultado de `99_validar.sh` |
