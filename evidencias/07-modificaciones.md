# Evidencia 07 — Modificaciones de datos: comparación entre `ddl` y `mod`

* **Estudiante:** Genaro Isaac Cárdenas Soto (`@darksitoV`)
* **Actividad:** Actividad 7 — Modificaciones de datos: `ddl` frente a `mod`

## 1. Comportamiento con `log_statement = 'ddl'`

**Comando ejecutado como `app_ventas`:**
```bash
psql "postgresql://app_ventas:<REDACTED>@127.0.0.1/comercial?application_name=app-ventas-web" -c "UPDATE clientes SET rfc = 'GAMA780912XYZ' WHERE id = 3"
```

**Consulta en `dba.bitacora`:**
```sql
SELECT num, linea FROM dba.bitacora WHERE linea LIKE '%user=app_ventas%' ORDER BY num DESC LIMIT 5;
```

```text
 num | linea
-----+----------------------------------------------------------------------------------------------------------------------
  49 | 2026-11-19 05:31:31.941 UTC [56] user=app_ventas db=comercial app=app-ventas-web client=127.0.0.1 LOG:  disconnection: session time: 0:00:00.013 user=app_ventas database=comercial host=127.0.0.1 port=51166
  48 | 2026-11-19 05:31:31.937 UTC [56] user=app_ventas db=comercial app=[unknown] client=127.0.0.1 LOG:  connection authorized: user=app_ventas database=comercial application_name=app-ventas-web
  47 | 2026-11-19 05:31:31.937 UTC [56] user=app_ventas db=comercial app=[unknown] client=127.0.0.1 LOG:  connection authenticated: identity="app_ventas" method=scram-sha-256 (/var/lib/postgresql/data/pg_hba.conf:119)
```
Aparece la conexión y desconexión del PID `56`, pero ningún `statement: UPDATE`, porque `ddl` no registra sentencias DML.

## 2. Cambio a `log_statement = 'mod'`

**Comandos ejecutados:**
```sql
ALTER SYSTEM SET log_statement = 'mod';
SELECT pg_reload_conf();
```
```bash
psql "postgresql://app_ventas:<REDACTED>@127.0.0.1/comercial?application_name=app-ventas-web" -c "UPDATE clientes SET telefono = '6679990000' WHERE id = 3" -c "SELECT nombre, rfc FROM clientes WHERE id = 3"
```

**Salida de `SELECT`:**
```text
    nombre    |      rfc
--------------+---------------
 María García | GAMA780912XYZ
```

**Consulta en `dba.bitacora`:**
```sql
SELECT num, linea FROM dba.bitacora
WHERE linea LIKE '%log_statement%' OR linea LIKE '%user=app_ventas%statement:%'
ORDER BY num;
```

```text
 num | linea
-----+----------------------------------------------------------------------------------------------------------------------
  17 | 2026-11-19 05:31:23.431 UTC [1] user= db= app= client= LOG:  parameter "log_statement" changed to "ddl"
  55 | 2026-11-19 05:31:33.020 UTC [60] user=postgres db=comercial app=psql client=[local] LOG:  statement: ALTER SYSTEM SET log_statement = 'mod';
  58 | 2026-11-19 05:31:33.046 UTC [1] user= db= app= client= LOG:  parameter "log_statement" changed to "mod"
  62 | 2026-11-19 05:31:35.598 UTC [62] user=app_ventas db=comercial app=app-ventas-web client=127.0.0.1 LOG:  statement: UPDATE clientes SET telefono = '6679990000' WHERE id = 3
```

En la línea 62 ya queda registrado quién (`app_ventas`), cuándo (`05:31:35.598 UTC`), desde dónde (`127.0.0.1`), la aplicación (`app-ventas-web`) y el `UPDATE`. El `SELECT` sobre `nombre, rfc` no quedó registrado.

## 3. Preguntas

1. **¿Qué nivel habría registrado la lectura del RFC? ¿Qué costo tendría en un servidor con miles de consultas por minuto?**  
   El nivel `log_statement = 'all'`. En un servidor con miles de lecturas por minuto generaría un crecimiento acelerado de archivos de bitácora, mayor uso de disco/I-O y ruido en las revisiones, además de llegar a registrar consultas con datos personales o filtros sensibles en texto plano.
2. **¿Qué le falta a esta bitácora para revertir el cambio con certeza?**  
   Le falta el valor anterior del campo antes de ejecutarse el `UPDATE`. La bitácora solo dice que `telefono` pasó a `'6679990000'`, pero sin el valor viejo (`'6673456789'`) no se puede restaurar con certeza solo leyendo este archivo.
