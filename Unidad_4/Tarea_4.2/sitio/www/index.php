<?php
// =============================================================================
//  index.php - Pagina de prueba de www.empresa.lan (Tarea 4.2)
//  Ruta en el servidor: /var/www/empresa/www/index.php
//
//  Comprueba las tres piezas del stack:
//    1) Apache sirviendo el sitio por HTTPS (datos de la conexion TLS)
//    2) PHP generando la pagina
//    3) MariaDB: lista los empleados de la tabla empresa_db.empleados
// =============================================================================
declare(strict_types=1);

$h = fn($s) => htmlspecialchars((string) $s, ENT_QUOTES, 'UTF-8');

// --- Datos de la conexion (Apache los entrega por SSLOptions +StdEnvVars) ---
$https = ($_SERVER['HTTPS'] ?? '') === 'on';
$conexion = [
    'Sitio (virtual host)' => $_SERVER['SERVER_NAME'] ?? '',
    'Protocolo'            => $https ? 'HTTPS' : 'HTTP (sin cifrar)',
    'Versión TLS'          => $_SERVER['SSL_PROTOCOL'] ?? '—',
    'Cifrado'              => $_SERVER['SSL_CIPHER'] ?? '—',
    'Certificado para'     => $_SERVER['SSL_SERVER_S_DN_CN'] ?? '—',
    'Emitido por'          => $_SERVER['SSL_SERVER_I_DN_CN'] ?? '—',
    'Tu dirección IP'      => $_SERVER['REMOTE_ADDR'] ?? '',
    'Versión de PHP'       => PHP_VERSION,
];

// --- Consulta a MariaDB (las credenciales estan fuera del sitio web) ---
$empleados = [];
$versionBd = '';
$errorBd   = false;
try {
    $cfg = parse_ini_file('/etc/tarea42/db.ini');
    if ($cfg === false) {
        throw new RuntimeException('No se pudo leer /etc/tarea42/db.ini');
    }
    $pdo = new PDO(
        "mysql:host=localhost;dbname={$cfg['base']};charset=utf8mb4",
        $cfg['usuario'],
        $cfg['clave'],
        [PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION]
    );
    $versionBd = (string) $pdo->query('SELECT VERSION()')->fetchColumn();
    $empleados = $pdo->query(
        'SELECT nombre, puesto, departamento, correo FROM empleados ORDER BY departamento, nombre'
    )->fetchAll(PDO::FETCH_ASSOC);
} catch (Throwable $e) {
    // El detalle va al log de Apache; al visitante solo se le avisa
    error_log('Tarea 4.2 - error de base de datos: ' . $e->getMessage());
    $errorBd = true;
}
?>
<!DOCTYPE html>
<html lang="es">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Empresa LAN · Sitio corporativo</title>
<style>
    body { margin: 0; font-family: "Segoe UI", Arial, sans-serif; background: #f3f4f6; color: #1f2937; }
    header { background: #1f3864; color: #fff; padding: 28px 40px; }
    header h1 { margin: 0 0 6px; font-size: 28px; }
    header p { margin: 0; opacity: .85; }
    main { max-width: 980px; margin: 30px auto; padding: 0 20px; }
    .tarjeta { background: #fff; border-radius: 10px; padding: 22px 26px; margin-bottom: 24px; box-shadow: 0 1px 3px rgba(0,0,0,.12); }
    h2 { margin-top: 0; color: #1f3864; font-size: 20px; }
    table { width: 100%; border-collapse: collapse; font-size: 15px; }
    th, td { text-align: left; padding: 8px 10px; border-bottom: 1px solid #e5e7eb; }
    th { background: #eef2ff; color: #1f3864; }
    .ok  { display: inline-block; background: #d1fae5; color: #065f46; padding: 3px 10px; border-radius: 12px; font-weight: 600; }
    .mal { display: inline-block; background: #fee2e2; color: #991b1b; padding: 3px 10px; border-radius: 12px; font-weight: 600; }
    footer { text-align: center; color: #6b7280; font-size: 13px; padding: 20px; }
    a { color: #2563eb; }
</style>
</head>
<body>
<header>
    <h1>Empresa LAN</h1>
    <p>Sitio corporativo · www.empresa.lan · servidor srv01 (192.168.50.10)</p>
</header>
<main>
    <section class="tarjeta">
        <h2>Conexión segura
            <?= $https ? '<span class="ok">Cifrada con TLS</span>' : '<span class="mal">Sin cifrar</span>' ?></h2>
        <table>
            <?php foreach ($conexion as $dato => $valor): ?>
                <tr><th style="width:35%"><?= $h($dato) ?></th><td><?= $h($valor) ?></td></tr>
            <?php endforeach; ?>
        </table>
    </section>

    <section class="tarjeta">
        <h2>Directorio de empleados
            <?php if ($errorBd): ?>
                <span class="mal">MariaDB: sin conexión</span>
            <?php else: ?>
                <span class="ok">MariaDB: conectado (<?= $h($versionBd) ?>)</span>
            <?php endif; ?></h2>
        <?php if ($errorBd): ?>
            <p>No se pudo consultar la base de datos. Revisa el log de errores de Apache.</p>
        <?php else: ?>
            <p><?= count($empleados) ?> registros leídos de la tabla <code>empresa_db.empleados</code>.</p>
            <table>
                <tr><th>Nombre</th><th>Puesto</th><th>Departamento</th><th>Correo</th></tr>
                <?php foreach ($empleados as $e): ?>
                    <tr><td><?= $h($e['nombre']) ?></td><td><?= $h($e['puesto']) ?></td>
                        <td><?= $h($e['departamento']) ?></td><td><?= $h($e['correo']) ?></td></tr>
                <?php endforeach; ?>
            </table>
        <?php endif; ?>
    </section>

    <section class="tarjeta">
        <h2>Otros servicios</h2>
        <p>Intranet (solo red interna): <a href="https://intranet.empresa.lan/">https://intranet.empresa.lan</a></p>
        <p>Archivos: SFTP y FTPS en <code>ftp.empresa.lan</code> (usuarios autorizados).</p>
    </section>
</main>
<footer>Tarea 4.2 · Apache + PHP <?= $h(PHP_VERSION) ?> + MariaDB · <?= $h(date('d/m/Y H:i')) ?></footer>
</body>
</html>
