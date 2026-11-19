# Evidencia 13 — Intentos de manipulación sobre el mecanismo de auditoría

* **Estudiante:** Genaro Isaac Cárdenas Soto (`@darksitoV`)
* **Actividad:** Actividad 14 — Intentar manipular la auditoría

## 1. Pruebas desde la aplicación y desde administrador

**Intento de borrado y desactivación como `app_ventas`:**
```bash
psql "postgresql://app_ventas:<REDACTED>@127.0.0.1/comercial?application_name=app-ventas-web" -c "DELETE FROM auditoria.cambios_clientes" -c "ALTER TABLE clientes DISABLE TRIGGER trg_auditoria_clientes"
```
```text
ERROR:  permission denied for schema auditoria
LINE 1: DELETE FROM auditoria.cambios_clientes
                    ^
ERROR:  must be owner of table clientes
```

**Evasión simulada desde `postgres`:**
```sql
ALTER TABLE clientes DISABLE TRIGGER trg_auditoria_clientes;
UPDATE clientes SET rfc = 'GAMA780912GHI' WHERE id = 3;
ALTER TABLE clientes ENABLE TRIGGER trg_auditoria_clientes;
SELECT count(*) FROM auditoria.cambios_clientes;
```
```text
ALTER TABLE
UPDATE 1
ALTER TABLE
 count
-------
     3
```
El conteo en `auditoria.cambios_clientes` permaneció en `3` filas: ese cambio no generó registro en la tabla de auditoría.

**Consulta en `dba.bitacora`:**
```sql
SELECT num, linea FROM dba.bitacora
WHERE linea ~ 'statement: (ALTER TABLE clientes (DIS|EN)ABLE|UPDATE clientes SET rfc = .GAMA780912GHI)'
ORDER BY num;
```

```text
 num | linea
-----+----------------------------------------------------------------------------------------------------------------------
 227 | 2026-11-19 05:33:22.352 UTC [131] user=app_ventas db=comercial app=app-ventas-web client=127.0.0.1 LOG:  statement: ALTER TABLE clientes DISABLE TRIGGER trg_auditoria_clientes
 233 | 2026-11-19 05:33:22.903 UTC [133] user=postgres db=comercial app=psql client=[local] LOG:  statement: ALTER TABLE clientes DISABLE TRIGGER trg_auditoria_clientes;
 234 | 2026-11-19 05:33:22.904 UTC [133] user=postgres db=comercial app=psql client=[local] LOG:  statement: UPDATE clientes SET rfc = 'GAMA780912GHI' WHERE id = 3;
 235 | 2026-11-19 05:33:22.906 UTC [133] user=postgres db=comercial app=psql client=[local] LOG:  statement: ALTER TABLE clientes ENABLE TRIGGER trg_auditoria_clientes;
```
La línea 227 muestra además que el intento fallido de `app_ventas` también quedó escrito, porque con `ddl`/`mod` el servidor registra la sentencia antes de validar si falla por permisos.

## 2. Preguntas

1. **¿Qué evidencia permite detectar que hubo un cambio sin auditar?**  
   La bitácora del servidor (`dba.bitacora`): en las líneas 233, 234 y 235 quedaron registrados el apagado de `trg_auditoria_clientes`, el `UPDATE` sobre `id = 3` ejecutado por `postgres` y la reactivación inmediata del trigger.
2. **¿Qué control administrativo (no técnico) reduciría este riesgo?**  
   Exigir control de cambios aprobado para cualquier alteración en triggers o esquemas productivos, junto con revisiones periódicas de las bitácoras por una persona distinta al DBA.
3. **Relaciona esta actividad con el principio de separación de funciones de la Unidad II.**  
   Mientras `app_ventas` no pudo alterar el disparador porque no es dueña de la tabla ni tiene acceso al esquema `auditoria`, un superusuario como `postgres` sí puede apagar cualquier mecanismo interno del servidor. La separación de funciones implica que quien administra la operación diaria del SGBD no debe controlar la custodia final ni el borrado de las bitácoras; estas deben replicarse a un servidor o SIEM operado por seguridad/auditoría.
