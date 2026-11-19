# Evidencia 12 — Registro de altas y bajas en la auditoría

* **Estudiante:** Genaro Isaac Cárdenas Soto (`@darksitoV`)
* **Actividad:** Actividad 13 — Altas y bajas

## 1. Ejecución como administrador (`postgres`)

```sql
INSERT INTO clientes (nombre, correo, rfc, edad, ciudad, codigo_postal)
VALUES ('Pedro Ruiz', 'pedro.ruiz@example.test', 'RUPE950101AAA', 30, 'Guasave', '81000');

DELETE FROM clientes WHERE nombre = 'Pedro Ruiz';

SELECT id_evento, usuario_sesion, aplicacion, ip_cliente, operacion, id_cliente,
       valores_antes ->> 'rfc' AS rfc_antes, valores_despues ->> 'rfc' AS rfc_despues
FROM auditoria.cambios_clientes
ORDER BY id_evento;
```

**Resultado obtenido:**
```text
INSERT 0 1
DELETE 1
 id_evento | usuario_sesion |   aplicacion   | ip_cliente | operacion | id_cliente |   rfc_antes   |  rfc_despues
-----------+----------------+----------------+------------+-----------+------------+---------------+---------------
         1 | app_ventas     | app-ventas-web | 127.0.0.1  | UPDATE    |          3 | GAMA780912XYZ | GAMA780912ZZZ
         2 | postgres       | psql           |            | INSERT    |         34 |               | RUPE950101AAA
         3 | postgres       | psql           |            | DELETE    |         34 | RUPE950101AAA |
(3 rows)
```
*(El `id_cliente` asignado por la secuencia fue `34` tras la recuperación del reinicio del contenedor en la Actividad 2).*

## 2. Preguntas

1. **El cliente Pedro Ruiz ya no existe en `clientes`. ¿Dónde queda evidencia de que existió y de sus datos?**  
   En la tabla `auditoria.cambios_clientes`: el evento `2` conserva su alta completa en `valores_despues` y el evento `3` conserva todo su registro previo a la eliminación en `valores_antes`.
2. **¿Por qué `ip_cliente` está vacía en los eventos 2 y 3?**  
   Porque `postgres` ejecutó ambas sentencias conectado localmente por socket Unix (`[local]`), donde `inet_client_addr()` devuelve `NULL` al no existir conexión TCP/IP.
3. **La política de retención de la Unidad II pedía eliminar datos cuando ya no fueran necesarios. ¿Qué conflicto aparece? ¿Quién debe resolverlo?**  
   Choca el derecho/principio de eliminación cuando los datos dejan de ser necesarios (o ante una solicitud de cancelación) contra la obligación de conservar evidencia histórica en las tablas de auditoría. El DBA no debe decidir unilateralmente qué borrar; la regla debe aprobarla Cumplimiento / Legal junto con el propietario del dato (Data Owner), definiendo si los registros de auditoría se conservan un plazo fijo o se anonimizan después de cierto tiempo.
