-- =============================================================================
--  empresa_db.sql - Base de datos de las paginas de prueba (Tarea 4.2)
--  Se carga con: sudo mariadb < config/empresa_db.sql
--  El usuario de la aplicacion (webapp) lo crea 01_web_lamp.sh con una
--  contrasena generada y SOLO permiso de lectura (SELECT).
-- =============================================================================
CREATE DATABASE IF NOT EXISTS empresa_db
    CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE empresa_db;

-- Directorio de empleados (los mismos usuarios de la Unidad 3)
DROP TABLE IF EXISTS empleados;
CREATE TABLE empleados (
    id           INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    nombre       VARCHAR(80)  NOT NULL,
    puesto       VARCHAR(60)  NOT NULL,
    departamento VARCHAR(40)  NOT NULL,
    correo       VARCHAR(80)  NOT NULL UNIQUE
);
INSERT INTO empleados (nombre, puesto, departamento, correo) VALUES
    ('Ana Torres',   'Jefa de Sistemas',       'Sistemas',    'ana.torres@empresa.lan'),
    ('Luis Ríos',    'Técnico de soporte',     'Sistemas',    'luis.rios@empresa.lan'),
    ('María López',  'Jefa de Finanzas',       'Finanzas',    'maria.lopez@empresa.lan'),
    ('Pedro Ruiz',   'Analista financiero',    'Finanzas',    'pedro.ruiz@empresa.lan'),
    ('Sofía Díaz',   'Auxiliar contable',      'Finanzas',    'sofia.diaz@empresa.lan'),
    ('Carlos Vega',  'Jefe de Operaciones',    'Operaciones', 'carlos.vega@empresa.lan'),
    ('Laura Mena',   'Operadora',              'Operaciones', 'laura.mena@empresa.lan'),
    ('Jorge Cano',   'Operador',               'Operaciones', 'jorge.cano@empresa.lan');

-- Avisos internos que muestra la intranet
DROP TABLE IF EXISTS avisos;
CREATE TABLE avisos (
    id     INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    fecha  DATE         NOT NULL,
    titulo VARCHAR(120) NOT NULL,
    area   VARCHAR(40)  NOT NULL
);
INSERT INTO avisos (fecha, titulo, area) VALUES
    ('2026-11-03', 'Nuevo servidor DHCP y DNS en la red 192.168.50.0/24', 'Sistemas'),
    ('2026-11-04', 'El sitio web y la intranet ya funcionan con HTTPS',  'Sistemas'),
    ('2026-11-04', 'Los archivos se comparten por SFTP/FTPS, no por USB', 'Sistemas'),
    ('2026-11-10', 'Cierre contable del mes',                             'Finanzas');
