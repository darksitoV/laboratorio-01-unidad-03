-- LAB-01 (Unidad III) - Actividad 4: Parametros de bitacora
-- Motor: PostgreSQL 16 | Base de datos: comercial

ALTER SYSTEM SET log_connections = on;
ALTER SYSTEM SET log_disconnections = on;
ALTER SYSTEM SET log_line_prefix = '%m [%p] user=%u db=%d app=%a client=%h ';
ALTER SYSTEM SET log_statement = 'ddl';

-- Recarga en caliente (asincrona)
SELECT pg_reload_conf();

-- Ejecutar en una consulta posterior para confirmar los nuevos valores
SELECT name, setting, source, sourcefile
FROM pg_settings
WHERE name IN ('log_connections', 'log_line_prefix', 'log_statement');

SELECT num, linea
FROM dba.bitacora
ORDER BY num DESC
LIMIT 10;
