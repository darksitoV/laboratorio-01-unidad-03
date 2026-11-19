-- LAB-01 (Unidad III) - Actividad 2: Colector de bitacora y vista dba.bitacora
-- Motor: PostgreSQL 16 | Base de datos: comercial

-- 1. Activar el colector de bitacora (requiere reinicio del servidor)
ALTER SYSTEM SET logging_collector = on;

-- Verificar que queda pendiente de reinicio
SELECT name, setting, pending_restart
FROM pg_settings
WHERE name = 'logging_collector';

-- 2. Despues de reiniciar el servidor, comprobar el archivo vigente
SELECT name, setting, source
FROM pg_settings
WHERE name = 'logging_collector';

SELECT pg_current_logfile();

-- 3. Esquema privado para el DBA y vista sobre el archivo de bitacora actual
CREATE SCHEMA dba;
REVOKE ALL ON SCHEMA dba FROM PUBLIC;

CREATE VIEW dba.bitacora AS
SELECT t.n AS num, t.linea
FROM regexp_split_to_table(pg_read_file(pg_current_logfile()), E'\n')
     WITH ORDINALITY AS t(linea, n)
WHERE t.linea <> '';

-- 4. Consultas basicas de revision
SELECT num, linea FROM dba.bitacora ORDER BY num DESC LIMIT 10;
SELECT linea FROM dba.bitacora WHERE linea ILIKE '%update%';
SELECT linea FROM dba.bitacora WHERE linea ~ '(FATAL|ERROR)';
