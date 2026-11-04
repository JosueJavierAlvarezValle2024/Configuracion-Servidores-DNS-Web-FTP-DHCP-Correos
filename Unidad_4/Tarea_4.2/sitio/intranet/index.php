<?php
// =============================================================================
//  index.php - Pagina de la intranet (Tarea 4.2)
//  Ruta en el servidor: /var/www/empresa/intranet/index.php
//  Virtual host intranet.empresa.lan: solo responde a la red 192.168.50.0/24
// =============================================================================
declare(strict_types=1);

$h = fn($s) => htmlspecialchars((string) $s, ENT_QUOTES, 'UTF-8');

$avisos  = [];
$errorBd = false;
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
    $avisos = $pdo->query('SELECT fecha, titulo, area FROM avisos ORDER BY fecha DESC')
                  ->fetchAll(PDO::FETCH_ASSOC);
} catch (Throwable $e) {
    error_log('Tarea 4.2 (intranet) - error de base de datos: ' . $e->getMessage());
    $errorBd = true;
}
?>
<!DOCTYPE html>
<html lang="es">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Intranet · Empresa LAN</title>
<style>
    body { margin: 0; font-family: "Segoe UI", Arial, sans-serif; background: #ecfdf5; color: #1f2937; }
    header { background: #065f46; color: #fff; padding: 28px 40px; }
    header h1 { margin: 0 0 6px; font-size: 28px; }
    header p { margin: 0; opacity: .85; }
    main { max-width: 900px; margin: 30px auto; padding: 0 20px; }
    .tarjeta { background: #fff; border-radius: 10px; padding: 22px 26px; margin-bottom: 24px; box-shadow: 0 1px 3px rgba(0,0,0,.12); }
    h2 { margin-top: 0; color: #065f46; font-size: 20px; }
    table { width: 100%; border-collapse: collapse; font-size: 15px; }
    th, td { text-align: left; padding: 8px 10px; border-bottom: 1px solid #e5e7eb; }
    th { background: #d1fae5; color: #065f46; }
    footer { text-align: center; color: #6b7280; font-size: 13px; padding: 20px; }
</style>
</head>
<body>
<header>
    <h1>Intranet</h1>
    <p>intranet.empresa.lan · acceso solo desde la red interna 192.168.50.0/24</p>
</header>
<main>
    <section class="tarjeta">
        <h2>Tu equipo</h2>
        <table>
            <tr><th style="width:35%">Dirección IP</th><td><?= $h($_SERVER['REMOTE_ADDR'] ?? '') ?></td></tr>
            <tr><th>Sitio (virtual host)</th><td><?= $h($_SERVER['SERVER_NAME'] ?? '') ?></td></tr>
            <tr><th>Conexión</th><td><?= $h($_SERVER['SSL_PROTOCOL'] ?? 'sin TLS') ?> · <?= $h($_SERVER['SSL_CIPHER'] ?? '') ?></td></tr>
        </table>
    </section>
    <section class="tarjeta">
        <h2>Avisos internos</h2>
        <?php if ($errorBd): ?>
            <p>No se pudo consultar la base de datos.</p>
        <?php else: ?>
            <table>
                <tr><th>Fecha</th><th>Aviso</th><th>Área</th></tr>
                <?php foreach ($avisos as $a): ?>
                    <tr><td><?= $h(date('d/m/Y', strtotime($a['fecha']))) ?></td>
                        <td><?= $h($a['titulo']) ?></td><td><?= $h($a['area']) ?></td></tr>
                <?php endforeach; ?>
            </table>
        <?php endif; ?>
    </section>
</main>
<footer>Tarea 4.2 · Intranet de Empresa LAN</footer>
</body>
</html>
