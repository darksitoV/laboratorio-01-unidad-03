# Evidencia 01 — Configuración inicial de registro y preparación de `pg_hba.conf`

* **Estudiante:** Genaro Isaac Cárdenas Soto (`@darksitoV`)
* **Actividad:** Secciones 6.3, 6.4 y Actividad 1 (configuración por defecto)
* **Motor:** PostgreSQL 16.15 (contenedor `dba-u3-pg`, BD `comercial`)

## 1. Identificación del servidor desde el motor (Sección 6.3)

**Comandos ejecutados:**
```sql
SELECT version();
SHOW data_directory;
SHOW config_file;
SHOW hba_file;
```

**Resultado:**
```text
                                                      version
--------------------------------------------------------------------------------------------------------------------
 PostgreSQL 16.15 (Debian 16.15-1.pgdg13+2) on x86_64-pc-linux-gnu, compiled by gcc (Debian 14.2.0-19) 14.2.0, 64-bit

      data_directory
--------------------------
 /var/lib/postgresql/data

               config_file
------------------------------------------
 /var/lib/postgresql/data/postgresql.conf

               hba_file
--------------------------------------
 /var/lib/postgresql/data/pg_hba.conf
```

## 2. Revisión y ajuste de `pg_hba.conf` (Sección 6.4)

**Consulta inicial:**
```sql
SELECT line_number, type, database, user_name, address, auth_method
FROM pg_hba_file_rules
WHERE database = '{all}';
```

**Resultado antes del ajuste:**
```text
 line_number | type  | database | user_name |  address  |  auth_method
-------------+-------+----------+-----------+-----------+---------------
         117 | local | {all}    | {all}     |           | trust
         119 | host  | {all}    | {all}     | 127.0.0.1 | trust
         121 | host  | {all}    | {all}     | ::1       | trust
         128 | host  | {all}    | {all}     | all       | scram-sha-256
(4 rows)
```

Como las reglas `host` de `127.0.0.1` y `::1` tenían `trust`, se cambiaron a `scram-sha-256` en `/var/lib/postgresql/data/pg_hba.conf` y se recargó con `SELECT pg_reload_conf();`.

**Resultado después del ajuste:**
```text
 line_number | type  | database | user_name |  address  |  auth_method
-------------+-------+----------+-----------+-----------+---------------
         117 | local | {all}    | {all}     |           | trust
         119 | host  | {all}    | {all}     | 127.0.0.1 | scram-sha-256
         121 | host  | {all}    | {all}     | ::1       | scram-sha-256
         128 | host  | {all}    | {all}     | all       | scram-sha-256
(4 rows)
```

### Pregunta de la Sección 6.4

**¿Por qué una regla `trust` afecta lo que la bitácora puede demostrar sobre la identidad del usuario?**  
Con `trust`, PostgreSQL acepta cualquier conexión que coincida con la regla sin pedir contraseña ni validar credenciales. Cualquier proceso o persona dentro del rango autorizado puede indicar `-U app_ventas` o `-U postgres` al conectarse y el servidor lo dejará entrar y registrará ese rol como válido. Así la bitácora solo prueba qué nombre de usuario se envió en el saludo de conexión, no que quien se conectó realmente conociera el secreto del rol.

## 3. Parámetros de bitácora por defecto (Actividad 1)

**Comando ejecutado:**
```sql
SELECT name, setting, source FROM pg_settings
WHERE name IN ('log_destination', 'logging_collector', 'log_directory', 'log_filename',
               'log_connections', 'log_disconnections', 'log_line_prefix',
               'log_statement', 'log_min_error_statement', 'log_timezone')
ORDER BY name;
```

**Resultado obtenido:**
```text
          name           |            setting             |       source
-------------------------+--------------------------------+--------------------
 log_connections         | off                            | default
 log_destination         | stderr                         | default
 log_directory           | log                            | default
 log_disconnections      | off                            | default
 log_filename            | postgresql-%Y-%m-%d_%H%M%S.log | default
 logging_collector       | off                            | default
 log_line_prefix         | %m [%p]                        | default
 log_min_error_statement | error                          | default
 log_statement           | none                           | default
 log_timezone            | Etc/UTC                        | configuration file
(10 rows)
```

## 4. Interpretación y respuestas (Actividad 1)

1. **Con esta configuración, ¿se registra quién se conecta?**  
   No. `log_connections` y `log_disconnections` están en `off`, así que no queda rastro ni de inicios ni de cierres de sesión exitosos.
2. **¿Se registran las sentencias UPDATE?**  
   No. Como `log_statement` está en `none`, PostgreSQL no guarda ninguna sentencia DDL ni DML que se ejecute sin error.
3. **¿La línea de bitácora incluye el usuario o la dirección IP del cliente?**  
   No. `log_line_prefix` tiene solo `%m [%p]` (fecha/hora y PID). Faltan `%u`, `%d`, `%a` y `%h`.
4. **¿En qué zona horaria se registran los eventos? ¿Por qué importa al reconstruir una cronología?**  
   En `Etc/UTC` (viene del `postgresql.conf` de la imagen). Importa porque si el equipo cliente o los logs de la aplicación están en hora local (por ejemplo UTC-7 en Sinaloa) y no se toma en cuenta la diferencia horaria al cruzar eventos, las horas no cuadran y se puede interpretar mal el orden de los hechos.
5. **Con `logging_collector = off`, ¿quién decide dónde termina la bitácora: PostgreSQL o el mecanismo con que se desplegó el servidor?**  
   El mecanismo de despliegue. PostgreSQL simplemente manda los mensajes a `stderr`, y en este caso es el motor de contenedores (Podman) el que captura esa salida en sus logs internos, no PostgreSQL en `/var/lib/postgresql/data/log`.
