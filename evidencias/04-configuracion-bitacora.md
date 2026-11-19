# Evidencia 04 — Configuración de parámetros de bitácora

* **Estudiante:** Genaro Isaac Cárdenas Soto (`@darksitoV`)
* **Actividad:** Actividad 4 — Configurar la bitácora
* **Script relacionado:** [`sql/02-configuracion-bitacora.sql`](../sql/02-configuracion-bitacora.sql)

## 1. Cambios aplicados y verificación

Se ejecutaron los `ALTER SYSTEM` y la recarga:
```sql
ALTER SYSTEM SET log_connections = on;
ALTER SYSTEM SET log_disconnections = on;
ALTER SYSTEM SET log_line_prefix = '%m [%p] user=%u db=%d app=%a client=%h ';
ALTER SYSTEM SET log_statement = 'ddl';
SELECT pg_reload_conf();
```

En una consulta nueva (por la naturaleza asíncrona de `pg_reload_conf()`), se comprobó el origen en `pg_settings`:
```sql
SELECT name, setting, source, sourcefile
FROM pg_settings
WHERE name IN ('log_connections', 'log_line_prefix', 'log_statement');
```

```text
      name       |                 setting                 |       source       |                  sourcefile
-----------------+-----------------------------------------+--------------------+-----------------------------------------------
 log_connections | on                                      | configuration file | /var/lib/postgresql/data/postgresql.auto.conf
 log_line_prefix | %m [%p] user=%u db=%d app=%a client=%h  | configuration file | /var/lib/postgresql/data/postgresql.auto.conf
 log_statement   | ddl                                     | configuration file | /var/lib/postgresql/data/postgresql.auto.conf
(3 rows)
```

Al revisar las últimas 10 líneas de `dba.bitacora`:
```sql
SELECT num, linea FROM dba.bitacora ORDER BY num DESC LIMIT 10;
```

```text
 num | linea
-----+----------------------------------------------------------------------------------------------------------------------
  19 | 2026-11-19 05:31:26.015 UTC [42] user=postgres db=comercial app=[unknown] client=[local] LOG:  connection authorized: user=postgres database=comercial application_name=psql
  18 | 2026-11-19 05:31:26.014 UTC [42] user=[unknown] db=[unknown] app=[unknown] client=[local] LOG:  connection received: host=[local]
  17 | 2026-11-19 05:31:23.431 UTC [1] user= db= app= client= LOG:  parameter "log_statement" changed to "ddl"
  16 | 2026-11-19 05:31:23.431 UTC [1] user= db= app= client= LOG:  parameter "log_line_prefix" changed to "%m [%p] user=%u db=%d app=%a client=%h "
  15 | 2026-11-19 05:31:23.431 UTC [1] LOG:  parameter "log_disconnections" changed to "on"
  14 | 2026-11-19 05:31:23.431 UTC [1] LOG:  parameter "log_connections" changed to "on"
  13 | 2026-11-19 05:31:23.430 UTC [1] LOG:  received SIGHUP, reloading configuration files
  12 | 2026-11-19 05:31:19.064 UTC [1] LOG:  database system is ready to accept connections
```

Se observa que las líneas 14 a 17 registraron los cambios de parámetros bajo el PID `1` tras la señal SIGHUP de la línea 13, y a partir de la línea 18 ya se registra cada conexión nueva (incluida la propia del administrador `postgres`).

## 2. Preguntas

1. **¿Por qué el proceso que registra el cambio es el principal y no tu sesión?**  
   Porque `ALTER SYSTEM` solo escribe el cambio en disco (`postgresql.auto.conf`). Quien recibe la señal `SIGHUP`, relee los archivos de configuración y aplica los parámetros globalmente para todo el servidor es el proceso padre (postmaster, PID `1`), por eso los mensajes `parameter ... changed to ...` salen sin `user=`, `db=` ni `client=`.
2. **¿Qué pasaría si alguien ejecutara `ALTER SYSTEM SET log_statement = 'none'`? ¿Quedaría rastro?**  
   Sí quedaría rastro. Como `log_statement` valía `'ddl'` (o `'mod'`), la sentencia `ALTER SYSTEM` sí quedaría registrada antes de aplicarse, y además al recargar el PID `1` imprimiría `parameter "log_statement" changed to "none"`.
3. **¿Por qué no se recomienda editar `postgresql.auto.conf` a mano?**  
   Porque ese archivo lo gestiona exclusivamente PostgreSQL mediante `ALTER SYSTEM`; editarlo manualmente puede introducir errores de sintaxis que impidan recargar o reiniciar el servicio, además de que cualquier `ALTER SYSTEM` futuro reescribe el archivo y puede pisar ediciones o comentarios manuales.
