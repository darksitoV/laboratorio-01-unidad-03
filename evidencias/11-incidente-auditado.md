# Evidencia 11 — Función, disparador e incidente auditado

* **Estudiante:** Genaro Isaac Cárdenas Soto (`@darksitoV`)
* **Actividades:** Actividad 11 (Función y disparador) y Actividad 12 (El incidente auditado)
* **Scripts relacionados:** [`sql/05-funcion-disparador.sql`](../sql/05-funcion-disparador.sql), [`sql/06-campos-modificados.sql`](../sql/06-campos-modificados.sql)

## 1. Creación de la función y el disparador (Actividad 11)

Se ejecutó [`sql/05-funcion-disparador.sql`](../sql/05-funcion-disparador.sql) creando `auditoria.registrar_cambio_cliente()` con `SECURITY DEFINER`, `SET search_path = pg_catalog, public`, revocando ejecución a `PUBLIC` y activando `trg_auditoria_clientes` `AFTER INSERT OR UPDATE OR DELETE` en `clientes`.

**Verificación en `pg_trigger`:**
```sql
SELECT tgname, tgenabled, tgrelid::regclass FROM pg_trigger WHERE NOT tgisinternal;
```
```text
         tgname         | tgenabled | tgrelid
------------------------+-----------+----------
 trg_auditoria_clientes | O         | clientes
```

**Registro DDL en `dba.bitacora`:**
```text
 147 | 2026-11-19 05:33:16.078 UTC [113] user=postgres db=comercial app=psql client=[local] LOG:  statement: CREATE SCHEMA auditoria;
 148 | 2026-11-19 05:33:16.100 UTC [113] user=postgres db=comercial app=psql client=[local] LOG:  statement: REVOKE ALL ON SCHEMA auditoria FROM PUBLIC;
 149 | 2026-11-19 05:33:16.102 UTC [113] user=postgres db=comercial app=psql client=[local] LOG:  statement: CREATE TABLE auditoria.cambios_clientes (
 167 | 2026-11-19 05:33:17.285 UTC [117] user=postgres db=comercial app=psql client=[local] LOG:  statement: CREATE OR REPLACE FUNCTION auditoria.registrar_cambio_cliente()
 190 | 2026-11-19 05:33:17.293 UTC [117] user=postgres db=comercial app=psql client=[local] LOG:  statement: REVOKE ALL ON FUNCTION auditoria.registrar_cambio_cliente() FROM PUBLIC;
 191 | 2026-11-19 05:33:17.294 UTC [117] user=postgres db=comercial app=psql client=[local] LOG:  statement: CREATE TRIGGER trg_auditoria_clientes
```

### Preguntas de la Actividad 11

1. **¿Por qué se ejecuta `REVOKE ALL ON FUNCTION ... FROM PUBLIC` si el disparador seguirá funcionando para `app_ventas`?**  
   Para evitar que otros roles puedan consultar o invocar la función de forma directa fuera del contexto de un disparador; PostgreSQL ejecuta el trigger internamente cuando ocurre el evento en la tabla `clientes`, sin requerir permiso explícito de ejecución para `app_ventas`.
2. **¿Qué pasaría si la función no fuera `SECURITY DEFINER`? (Hipótesis previa)**  
   Si usara `SECURITY INVOKER` (por defecto), correría con los privilegios de `app_ventas`. Como `app_ventas` no tiene acceso al esquema `auditoria`, el `INSERT` dentro del trigger fallaría por falta de permisos y haría fallar también el `UPDATE` en `clientes`.
3. **Consulta `dba.bitacora`. ¿Quedó registrada la creación del esquema, la tabla, la función y el disparador? ¿Por qué?**  
   Sí, quedaron en las líneas 147, 149, 167 y 191 porque `log_statement` estaba configurado en `'mod'`, nivel que abarca tanto modificaciones DML como sentencias DDL.

## 2. Simulación y revisión del incidente (Actividad 12)

**Comandos ejecutados como `app_ventas`:**
```bash
psql "postgresql://app_ventas:<REDACTED>@127.0.0.1/comercial?application_name=app-ventas-web" -c "UPDATE clientes SET rfc = 'GAMA780912ZZZ' WHERE id = 3"
psql "postgresql://app_ventas:<REDACTED>@127.0.0.1/comercial" -c "SELECT * FROM auditoria.cambios_clientes"
```

**Resultado:**
```text
UPDATE 1
ERROR:  permission denied for schema auditoria
LINE 1: SELECT * FROM auditoria.cambios_clientes
```

**Consulta en la sesión de administrador (`\x` y [`sql/06-campos-modificados.sql`](../sql/06-campos-modificados.sql)):**
```text
-[ RECORD 1 ]----+------------------------------
id_evento        | 1
momento          | 2026-11-19 05:33:19.450681+00
usuario_sesion   | app_ventas
usuario_efectivo | postgres
aplicacion       | app-ventas-web
ip_cliente       | 127.0.0.1
operacion        | UPDATE
id_cliente       | 3
```

**Comparación campo por campo (`valores_antes` frente a `valores_despues`):**
```text
 id_evento |            momento            | usuario_sesion | ip_cliente | campo |     antes     |    despues
-----------+-------------------------------+----------------+------------+-------+---------------+---------------
         1 | 2026-11-19 05:33:19.450681+00 | app_ventas     | 127.0.0.1  | rfc   | GAMA780912XYZ | GAMA780912ZZZ
```

### Preguntas de la Actividad 12

1. **Compara tu hipótesis de la Actividad 11 con este resultado.**  
   El resultado coincide con la idea: `app_ventas` actualizó `clientes` sin problemas y el disparador logró escribir en `auditoria.cambios_clientes` gracias a `SECURITY DEFINER` (por eso `usuario_efectivo` aparece como `postgres`), mientras que cuando `app_ventas` quiso leer la auditoría el acceso fue rechazado. Guardar `session_user` en `usuario_sesion` permitió atribuir el cambio a `app_ventas`.
2. **Escribe la sentencia `UPDATE` que restauraría el valor anterior.**
   ```sql
   UPDATE clientes SET rfc = 'GAMA780912XYZ' WHERE id = 3;
   ```
3. **¿Qué columna conserva más valor para una investigación: `aplicacion` o `ip_cliente`? ¿Cuál puede falsificar el cliente con más facilidad?**  
   `ip_cliente` aporta mayor confianza porque la toma el servidor desde la conexión TCP de red (`inet_client_addr()`), mientras que `aplicacion` (`application_name`) la envía el propio cliente en la cadena de conexión y puede cambiarse por cualquier texto arbitrario.
