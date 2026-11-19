# Evidencia 02 — Activación del colector y vista `dba.bitacora`

* **Estudiante:** Genaro Isaac Cárdenas Soto (`@darksitoV`)
* **Actividad:** Actividad 2 — Que el servidor administre su propia bitácora
* **Script relacionado:** [`sql/01-colector-y-vista.sql`](../sql/01-colector-y-vista.sql)

## 1. Comandos ejecutados y salida

Primero se habilitó el colector y se revisó si requería reinicio:
```sql
ALTER SYSTEM SET logging_collector = on;
SELECT name, setting, pending_restart FROM pg_settings WHERE name = 'logging_collector';
```

```text
ALTER SYSTEM
       name        | setting | pending_restart
-------------------+---------+-----------------
 logging_collector | off     | f
```
*Nota: antes del reinicio del contenedor (`podman restart dba-u3-pg`), el valor en memoria seguía en `off` aunque ya estaba guardado en `postgresql.auto.conf`.*

Después de reiniciar el contenedor y reconectar como `postgres`:
```sql
SELECT name, setting, source FROM pg_settings WHERE name = 'logging_collector';
SELECT pg_current_logfile();
```

```text
       name        | setting |       source
-------------------+---------+--------------------
 logging_collector | on      | configuration file

          pg_current_logfile
--------------------------------------
 log/postgresql-2026-11-19_053118.log
```

Con el archivo activo ubicado, se creó el esquema privado `dba` y la vista `dba.bitacora` (ver [`sql/01-colector-y-vista.sql`](../sql/01-colector-y-vista.sql)) y se consultaron las últimas 10 líneas:

```sql
SELECT num, linea FROM dba.bitacora ORDER BY num DESC LIMIT 10;
```

```text
 num | linea
-----+---------------------------------------------------------------------------------------------------------------
  12 | 2026-11-19 05:31:19.064 UTC [1] LOG:  database system is ready to accept connections
  11 | 2026-11-19 05:31:19.057 UTC [23] LOG:  checkpoint complete: wrote 98 buffers (0.6%); ...
  10 | 2026-11-19 05:31:19.019 UTC [23] LOG:  checkpoint starting: end-of-recovery immediate wait
   9 | 2026-11-19 05:31:18.995 UTC [25] LOG:  redo done at 0/1989428 system usage: ...
   ...
   3 | 2026-11-19 05:31:18.757 UTC [1] LOG:  listening on IPv6 address "::", port 5432
```

## 2. Interpretación y preguntas

1. **¿Por qué `logging_collector` requiere reinicio y `log_statement` solo recarga?**  
   Porque `logging_collector` lanza un proceso auxiliar separado del servidor (`syslogger`) que toma el control de `stderr` y abre el manejador de archivos desde el arranque del postmaster. En cambio, `log_statement` es solo una bandera que cada proceso cliente lee en memoria al recibir la señal SIGHUP con `pg_reload_conf()`.
2. **¿Qué ventaja tiene que la bitácora se lea con SQL y no con una herramienta del sistema operativo o del contenedor? ¿Qué riesgo introduce?**  
   La ventaja es que funciona igual sin importar si PostgreSQL corre en Linux, Windows o contenedor, no exige acceso a la shell del host ni permisos de SO, y permite filtrar con `WHERE` o `ORDER BY` usando números de línea. El riesgo viene de las funciones usadas por debajo: `pg_read_file()` permite leer cualquier archivo al que tenga acceso el proceso del servidor; por eso debe quedar restringida solo a superusuarios y en un esquema sin permisos para `PUBLIC`.
3. **¿Quién debería poder consultar `dba.bitacora`?**  
   Únicamente el DBA (o un rol específico de auditoría bajo supervisión), nunca cuentas de aplicación ni `PUBLIC`. Con `REVOKE ALL ON SCHEMA dba FROM PUBLIC;` queda bloqueado el acceso de lectura a usuarios comunes como `app_ventas` o `soporte_ana`.
