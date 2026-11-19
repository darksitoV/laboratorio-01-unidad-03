-- LAB-01 (Unidad III) - Actividad 12: Consulta de campos modificados en auditoria
-- Motor: PostgreSQL 16 | Base de datos: comercial

-- Resumen de eventos registrados
SELECT id_evento, momento, usuario_sesion, usuario_efectivo, aplicacion, ip_cliente, operacion, id_cliente
FROM auditoria.cambios_clientes
ORDER BY id_evento;

-- Comparacion campo por campo entre valores_antes y valores_despues en UPDATE
SELECT a.id_evento, a.momento, a.usuario_sesion, a.ip_cliente,
       d.key                     AS campo,
       a.valores_antes ->> d.key AS antes,
       d.value #>> '{}'          AS despues
FROM auditoria.cambios_clientes a
CROSS JOIN LATERAL jsonb_each(a.valores_despues) d
WHERE a.operacion = 'UPDATE'
  AND a.valores_antes -> d.key IS DISTINCT FROM d.value
ORDER BY a.id_evento;

-- Ejemplo de restauracion del RFC anterior para id = 3 (no ejecutado automaticamente)
-- UPDATE clientes SET rfc = 'GAMA780912XYZ' WHERE id = 3;
