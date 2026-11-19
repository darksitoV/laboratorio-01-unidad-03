# Informe Técnico — LAB-01: Bitácoras y auditoría del dato en PostgreSQL

* **Materia:** Gestión de Seguridad y Desempeño de Bases de Datos
* **Unidad:** III — Auditoría, trazabilidad y gobierno práctico de datos
* **Estudiante:** Genaro Isaac Cárdenas Soto (`@darksitoV`)
* **Escenario:** Comercializadora Norte S.A. de C.V.

---

## 1. Despliegue y situación inicial

El laboratorio se realizó sobre la imagen oficial `postgres:16` desplegada en Podman como el contenedor `dba-u3-pg` con la base de datos `comercial`:

* **Versión exacta:** `PostgreSQL 16.15 (Debian 16.15-1.pgdg13+2) on x86_64-pc-linux-gnu`.
* **Rutas de motor:** directorio de datos `/var/lib/postgresql/data`, `postgresql.conf` y `pg_hba.conf` en esa misma ruta.
* **Ajuste previo de autenticación:** las reglas `host` para `127.0.0.1` y `::1` venían en `trust`; se cambiaron a `scram-sha-256` en `pg_hba.conf` para obligar la verificación de contraseña en conexiones TCP locales.

En la revisión inicial, PostgreSQL tenía apagado el colector (`logging_collector = off`), deshabilitados los registros de conexiones (`log_connections = off`, `log_disconnections = off`), `log_statement = none` y un prefijo mínimo `%m [%p]` sin usuario, base de datos, aplicación ni IP. Con esa configuración, al simular la actualización del RFC de María García (`id = 3`) como `app_ventas`, el cambio se aplicó (`UPDATE 1`) pero no dejó ningún rastro en la base de datos. No era posible responder ninguna de las preguntas de Dirección.

---

## 2. Configuración aplicada

Los parámetros se ajustaron mediante `ALTER SYSTEM` (escritos en `/var/lib/postgresql/data/postgresql.auto.conf`):

| Parámetro | Valor aplicado | Cómo entra en vigor | Justificación |
| :--- | :--- | :--- | :--- |
| `logging_collector` | `on` | **Reinicio** del servidor | Hace que PostgreSQL capture `stderr` en archivos dentro de `log/` accesibles desde SQL sin depender de la herramienta de contenedores |
| `log_connections` | `on` | **Recarga** (`pg_reload_conf()`) | Registra cada intento de conexión, autenticación y autorización (incluidos los rechazos `FATAL`) |
| `log_disconnections` | `on` | **Recarga** (`pg_reload_conf()`) | Registra cierre y duración exacta de cada sesión (`session time`) |
| `log_line_prefix` | `'%m [%p] user=%u db=%d app=%a client=%h '` | **Recarga** (`pg_reload_conf()`) | Incluye timestamp UTC, PID, rol autenticado, BD, `application_name` y dirección IP del cliente en cada línea |
| `log_statement` | `'ddl'` y luego `'mod'` | **Recarga** (`pg_reload_conf()`) | Con `'ddl'` registra cambios de estructura y privilegios (`GRANT`/`REVOKE`); con `'mod'` agrega modificaciones de datos (`INSERT`, `UPDATE`, `DELETE`) |

Además se mantuvo `log_min_error_statement = error` (por defecto) y se creó el esquema privado `dba` con la vista `dba.bitacora` sobre `pg_read_file(pg_current_logfile())`, revocando todo acceso a `PUBLIC`.

---

## 3. Eventos observados

Durante las pruebas quedaron registrados los seis tipos de eventos en `evidencias/bitacora-lab01.log`:

1. **Configuración (líneas 13–17 y 55–58):** tras ejecutar `pg_reload_conf()`, el proceso principal `[1]` registró `received SIGHUP` y la transición de cada parámetro (`parameter "log_statement" changed to "ddl"` y posteriormente a `"mod"`).
2. **Acceso (líneas 21–31):** se diferenciaron claramente un rechazo por contraseña errónea para `app_ventas` (`FATAL: password authentication failed`, línea 22), un rechazo por rol inexistente (`DETAIL: Role "usuario_inexistente" does not exist`, línea 26) y una conexión exitosa con cierre (`LOG: connection authenticated` / `disconnection`, líneas 29–31).
3. **Privilegio (líneas 37–38):** `REVOKE UPDATE ON clientes FROM soporte_ana;` y `GRANT UPDATE ON clientes TO app_ventas;` quedaron capturados bajo `log_statement = 'ddl'`.
4. **Estructura (líneas 39 y 149):** tanto el agregado de la columna `segmento` a `clientes` como la creación del esquema, tabla, función y disparador en `auditoria` quedaron asentados en bitácora.
5. **Datos (líneas 62, 201 y 246):** ya con `log_statement = 'mod'`, se registraron las sentencias `UPDATE` sobre `telefono`, `rfc` y `segmento` indicando el rol y el cliente origen.
6. **Error (líneas 71–72, 77–79 y 224–229):** quedaron trazados los rechazos `ERROR: permission denied for table clientes` (`soporte_ana` intentando borrar), el rechazo de `DROP ROLE soporte_ana` por dependencias y los intentos de `app_ventas` contra la tabla de auditoría y el trigger.

---

## 4. Auditoría del dato

Para responder qué valor tenía un campo antes de modificarse, se creó el esquema separado `auditoria` (sin acceso a `PUBLIC`) con la tabla `auditoria.cambios_clientes`, que almacena `momento` (`TIMESTAMPTZ`), `usuario_sesion` (`session_user`), `usuario_efectivo` (`current_user`), `aplicacion`, `ip_cliente`, `operacion`, `id_cliente` y el estado completo antes y después en formato `JSONB`.

La función disparadora `auditoria.registrar_cambio_cliente()` se definió como `SECURITY DEFINER` con `SET search_path = pg_catalog, public`. Gracias a eso, cuando `app_ventas` ejecutó el `UPDATE` en la Actividad 12, el disparador escribió la fila con los permisos del propietario (`usuario_efectivo = postgres`), mientras que la aplicación siguió bloqueada para leer o borrar `auditoria.cambios_clientes`. El uso de `session_user` evitó el error de atribuir el cambio a `postgres`, permitiendo identificar a `app_ventas` (`app-ventas-web`, `127.0.0.1`) y demostrar mediante `jsonb_each` que el campo `rfc` cambió de `GAMA780912XYZ` a `GAMA780912ZZZ` (`id_evento = 1`).

---

## 5. Limitaciones

* **Lecturas (`SELECT`):** ni `log_statement = 'mod'` ni un disparador (que no existe para `SELECT` en PostgreSQL) registran consultas de lectura; en la Actividad 15 la lectura de `soporte_ana` sobre `nombre`, `rfc` y `telefono` dejó `0` registros. Activar `log_statement = 'all'` registraría todo, pero dispararía el consumo de almacenamiento y metería datos sensibles al log.
* **Volumen en operaciones masivas:** un `UPDATE clientes SET segmento = 'regular'` sin `WHERE` generó 1 sola línea en bitácora pero 5 filas en `auditoria.cambios_clientes` (una por cada fila tocada). En tablas grandes, un cambio masivo crece linealmente dentro de la misma transacción.
* **Administrador con control total:** como se probó en la Actividad 14, `postgres` pudo desactivar el trigger (`DISABLE TRIGGER`), modificar el RFC sin quedar en `auditoria.cambios_clientes` y reactivarlo. Aunque la bitácora del servidor sí dejó rastro de esas sentencias DDL, un administrador con acceso al sistema operativo o capacidad de apagar `log_statement` también podría evadir o alterar el archivo local.

---

## 6. Riesgos de la bitácora

* **Exposición de secretos:** al crear un rol pasando la contraseña directamente en SQL (`CREATE ROLE ... PASSWORD`), `log_statement` la escribió en texto claro en la línea 40 y borrar el rol no eliminó ese registro. Por eso debe usarse `\password` (que envía el hash SCRAM desde el cliente) y el acceso a `dba.bitacora` debe quedar limitado solo al administrador. Al preparar esta entrega, `evidencias/bitacora-lab01.log` se exportó sustituyendo la contraseña de prueba por `<REDACTED>` y se verificó su integridad con el resumen `SHA-256` en `evidencias/bitacora-lab01.sha256`.
* **Datos personales en el log:** las sentencias `INSERT`/`UPDATE` en `mod` y los archivos exportados contienen RFCs, nombres y teléfonos que exigen el mismo cuidado de confidencialidad y retención que la base productiva.
* **Pérdida por conservación local:** guardar las bitácoras únicamente dentro del servidor o contenedor las expone a rotación, fallos de almacenamiento o manipulación si se compromete el host; deben enviarse a un servidor externo independiente.

---

## 7. Cronología y conclusión

Con la configuración final (colector activo, prefijo completo, `log_statement = 'mod'`, `log_connections`/`log_disconnections` en `on` y el disparador en `auditoria.cambios_clientes`) **sí es posible demostrar** quién modificó un dato sensible, cuándo, desde qué dirección IP, con qué aplicación declarada y qué valor exacto tenía antes (`GAMA780912XYZ` -> `GAMA780912ZZZ` en el `id_evento = 1`). Al mismo tiempo, la cronología demostró de forma explícita las brechas previas: de la modificación inicial de la Actividad 3, del `UPDATE` hecho bajo `'ddl'` en la Actividad 7 y de la lectura de `soporte_ana` en la Actividad 15 **no hay evidencia** del detalle ejecutado, porque la auditoría no reconstruye eventos anteriores a su activación ni cubre consultas `SELECT` sin un módulo especializado.

---

## 8. Preguntas de reflexión (Sección 29)

1. **¿Por qué la auditoría no puede configurarse después de un incidente para investigarlo?**  
   Porque PostgreSQL solo escribe en bitácoras o tablas de auditoría los eventos que ocurren mientras esos mecanismos ya están habilitados. Lo que pasó antes con `log_statement = none` o sin disparador simplemente se ejecutó en memoria y disco sin dejar historial de sentencias ni valores previos.
2. **¿Por qué conviene que la bitácora la administre el propio servidor y no el mecanismo de despliegue?**  
   Cuando `logging_collector = on`, PostgreSQL escribe en archivos propios bajo `log_directory` de forma consistente en cualquier plataforma (Linux, Windows o contenedor) y permite consultarlos con funciones SQL (`pg_current_logfile()`, `pg_read_file()`). Si depende del despliegue (`stderr`), un reinicio del contenedor o una configuración distinta del demonio puede truncar o dispersar la salida.
3. **¿Por qué el prefijo de línea es tan importante como el nivel de `log_statement`?**  
   Porque `log_statement` decide *qué* sentencias se guardan, pero sin `log_line_prefix` (`%u`, `%d`, `%a`, `%h`) la bitácora diría qué se ejecutó mas no quién lo mandó, en qué base, desde qué IP ni bajo qué proceso (`%p`) agrupar toda la sesión.
4. **¿Qué diferencia práctica hay entre registrar la sentencia y registrar el cambio en el dato?**  
   Registrar la sentencia guarda el texto SQL (una línea por comando, sin saber qué valores había antes ni exactamente qué filas tocó un `UPDATE` masivo). Registrar el cambio en el dato con disparador guarda una fila por cada registro modificado con `valores_antes` y `valores_despues`, permitiendo revertir errores con exactitud.
5. **¿Qué evidencia ofrece `pg_stat_activity` que no ofrece la bitácora, y viceversa?**  
   `pg_stat_activity` muestra la fotografía en tiempo real de sesiones vivas (su estado `active`/`idle` y la consulta que está corriendo justo ahora antes de terminar). La bitácora guarda la historia cronológica de conexiones pasadas, fallos de autenticación, errores y sentencias ya finalizadas una vez cerrada la sesión.
6. **Si el administrador puede cambiar `log_statement` a `none` y desactivar el disparador, ¿quién audita al administrador?**  
   Los controles técnicos internos no bastan frente a un superusuario. Lo audita una combinación de envío en tiempo real de bitácoras hacia un repositorio externo o SIEM fuera de su control, separación de funciones entre DBA y seguridad/auditoría, y procesos administrativos de control de cambios que exigen revisar los cortes o desactivaciones en bitácora.
