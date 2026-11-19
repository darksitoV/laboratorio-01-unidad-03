-- LAB-01 (Unidad III) - Actividad 6: Cambios de privilegios, estructura y fuga de secretos
-- Motor: PostgreSQL 16 | Base de datos: comercial

-- Revision y ajuste de privilegios sobre clientes
REVOKE UPDATE ON clientes FROM soporte_ana;
GRANT UPDATE ON clientes TO app_ventas;

-- Cambio de estructura
ALTER TABLE clientes ADD COLUMN segmento VARCHAR(20);

-- Demostracion de riesgo: crear un rol pasando la clave en la sentencia
-- (En el script entregado se sustituye la clave de practica por <REDACTED>)
CREATE ROLE rol_temporal LOGIN PASSWORD '<REDACTED>';
DROP ROLE rol_temporal;

-- Revision de sentencias registradas
SELECT num, linea
FROM dba.bitacora
WHERE linea LIKE '%statement:%'
ORDER BY num;
