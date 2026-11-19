# Evidencia 15 — Exportación, verificación de integridad, cronología y respuestas a Dirección

* **Estudiante:** Genaro Isaac Cárdenas Soto (`@darksitoV`)
* **Actividades:** Actividad 16 (Exportar y conservar) y Actividad 17 (Reconstruir cronología y responder a Dirección)

## 1. Exportación sin secretos e integridad (Actividad 16)

El archivo vigente (`log/postgresql-2026-11-19_053118.log`) se exportó a `evidencias/bitacora-lab01.log` (UTF-8) sustituyendo la contraseña de prueba que quedó expuesta en la Actividad 6 por `<REDACTED>`, y se calculó su resumen SHA-256 guardado en `evidencias/bitacora-lab01.sha256`.

**Comandos utilizados (ejecutado contra el contenedor en UTF-8):**
```sql
SELECT replace(pg_read_file(pg_current_logfile()), '<contraseña_en_texto_claro>', '<REDACTED>');
```
```powershell
Get-FileHash evidencias/bitacora-lab01.log -Algorithm SHA256
```

**Hash obtenido en [`evidencias/bitacora-lab01.sha256`](bitacora-lab01.sha256):**
```text
0a51973c96577d091e4ca0dc1ded4c55c69e6ea318e8a199fff52bf1297729fd  bitacora-lab01.log
```

### Preguntas de la Actividad 16

1. **Un resumen SHA-256, ¿impide que alguien modifique la bitácora? ¿Qué permite demostrar?**  
   No impide que el archivo sea editado ni protege contra escritura. Sirve para **detectar** cualquier alteración posterior: si cambia aunque sea un solo byte del archivo, el SHA-256 recalculado ya no coincidirá con `0a51973c96577d091e4ca0dc1ded4c55c69e6ea318e8a199fff52bf1297729fd`.
2. **¿Dónde debería guardarse el hash para que sea útil como control de integridad?**  
   Fuera del servidor donde reside PostgreSQL y separado de la copia del `.log`, en un repositorio externo de solo adición/inmutable o custodiado por otra área (por ejemplo seguridad o SIEM), para que quien modifique el log local no pueda actualizar también el hash.
3. **La guía NIST SP 800-92 trata la conservación y protección de bitácoras. ¿Qué riesgos tiene conservar la bitácora solo en el servidor que la produce?**  
   Riesgo de pérdida definitiva ante un fallo del disco o recreación del contenedor, rotación que sobrescriba eventos antiguos sin respaldo y riesgo de manipulación si alguien compromete la cuenta administrativa del servidor.
4. **Propón durante cuánto tiempo conservarías esta bitácora y justifica tu criterio.**  
   En operación rápida (disco/SIEM en línea) al menos 90 días para atender incidentes recientes, y en archivo histórico comprimido de 1 a 5 años para alinearse con revisiones de auditoría interna y plazos de prescripción fiscal aplicables a los datos de facturación de la empresa.

---

## 2. Cronología reconstruida (Actividad 17)

| # | Fecha y hora (UTC) | Usuario | Cliente | Tipo de evento | Qué ocurrió | ¿Exitoso? | Fuente (línea / `id_evento`) |
| :- | :--- | :--- | :--- | :--- | :--- | :-: | :--- |
| 1 | `2026-11-19 05:31:23.431` | `[postmaster PID 1]` | — | Configuración | Activación de `log_connections`, `log_disconnections`, `log_line_prefix` y `log_statement = 'ddl'` | Sí | `bitacora-lab01.log` L14–L17 |
| 2 | `2026-11-19 05:31:26.559` | `app_ventas` | `127.0.0.1` | Acceso | Autenticación fallida por contraseña incorrecta (`scram-sha-256`) | No | `bitacora-lab01.log` L22–L23 |
| 3 | `2026-11-19 05:31:27.124` | `usuario_inexistente` | `127.0.0.1` | Acceso | Autenticación fallida porque el rol no existe | No | `bitacora-lab01.log` L25–L26 |
| 4 | `2026-11-19 05:31:27.708` | `app_ventas` | `127.0.0.1` (`app-ventas-web`) | Acceso | Acceso autorizado y consulta de conteo sobre `clientes` | Sí | `bitacora-lab01.log` L29–L31 |
| 5 | `2026-11-19 05:31:29.830–05:31:29.832` | `postgres` | `[local]` (`psql`) | Privilegio | `REVOKE UPDATE` a `soporte_ana` y `GRANT UPDATE` a `app_ventas` sobre `clientes` | Sí | `bitacora-lab01.log` L37–L38 |
| 6 | `2026-11-19 05:31:29.833` | `postgres` | `[local]` (`psql`) | Estructura | Se agregó la columna `segmento` a la tabla `clientes` | Sí | `bitacora-lab01.log` L39 |
| 7 | `2026-11-19 05:31:33.046` | `postgres` / `[PID 1]` | `[local]` | Configuración | Cambio de `log_statement` de `'ddl'` a `'mod'` | Sí | `bitacora-lab01.log` L55, L58 |
| 8 | `2026-11-19 05:31:35.598` | `app_ventas` | `127.0.0.1` (`app-ventas-web`) | Datos | `UPDATE clientes SET telefono = '6679990000' WHERE id = 3` | Sí | `bitacora-lab01.log` L62 |
| 9 | `2026-11-19 05:31:37.756` | `soporte_ana` | `127.0.0.1` (`psql`) | Error | `DELETE FROM clientes WHERE id = 5` rechazado por permisos | No | `bitacora-lab01.log` L71–L72 |
| 10 | `2026-11-19 05:31:38.321` | `postgres` | `[local]` (`psql`) | Error | `DROP ROLE soporte_ana` rechazado por privilegios dependientes | No | `bitacora-lab01.log` L77–L79 |
| 11 | `2026-11-19 05:33:16.078–05:33:17.294` | `postgres` | `[local]` (`psql`) | Estructura | Creación de esquema `auditoria`, tabla `cambios_clientes`, función y trigger | Sí | `bitacora-lab01.log` L147–L193 |
| 12 | `2026-11-19 05:33:19.450` | `app_ventas` | `127.0.0.1` (`app-ventas-web`) | Datos | `UPDATE clientes SET rfc = 'GAMA780912ZZZ' WHERE id = 3` (antes `GAMA780912XYZ`) | Sí | `bitacora-lab01.log` L201 / `auditoria` `id_evento = 1` |
| 13 | `2026-11-19 05:33:22.352` | `app_ventas` | `127.0.0.1` (`app-ventas-web`) | Error | Intentos rechazados de borrar en auditoría y desactivar trigger | No | `bitacora-lab01.log` L224–L229 |
| 14 | `2026-11-19 05:33:22.903–05:33:22.906` | `postgres` | `[local]` (`psql`) | Estructura / Datos | Desactiva trigger, ejecuta `UPDATE clientes SET rfc = 'GAMA780912GHI' WHERE id = 3`, reactiva trigger | Sí | `bitacora-lab01.log` L233–L235 |
| 15 | `2026-11-19 05:33:25.564` | `postgres` | `[local]` (`psql`) | Datos | `UPDATE clientes SET segmento = 'regular'` sobre 5 filas | Sí | `bitacora-lab01.log` L246 / `auditoria` eventos `UPDATE` |

---

## 3. Respuestas a Dirección (basadas únicamente en la evidencia)

1. **¿Quién cambió el RFC la primera vez (Actividad 3)? ¿Y en las Actividades 7, 12 y 14?**
   * **Actividad 3 (`'GAMA780912XXX'`):** **No hay evidencia.** En ese momento `log_connections` y `log_disconnections` estaban en `off`, `log_statement` en `none` y aún no existía el disparador de auditoría. No quedó rastro ni en la bitácora ni en tablas.
   * **Actividad 7 (`'GAMA780912XYZ'`):** **No hay evidencia** de la sentencia ni de qué columna modificó. En la bitácora consta que `app_ventas` (`app-ventas-web`, `127.0.0.1`) se conectó y desconectó a las `05:31:31.937–05:31:31.941 UTC` (`bitacora-lab01.log` líneas 46–49), pero con `log_statement = 'ddl'` no se registraron sentencias DML.
   * **Actividad 12 (`'GAMA780912ZZZ'`):** Lo realizó el rol `app_ventas` desde `127.0.0.1` (`application_name = app-ventas-web`) a las `2026-11-19 05:33:19.450 UTC` (`bitacora-lab01.log` línea 201 y `auditoria.cambios_clientes` `id_evento = 1`).
   * **Actividad 14 (`'GAMA780912GHI'`):** Lo realizó `postgres` en sesión local (`[local]`, `psql`) a las `2026-11-19 05:33:22.904 UTC`, desactivando antes `trg_auditoria_clientes` (`bitacora-lab01.log` líneas 233–235). En `auditoria.cambios_clientes` **no hay evidencia** de ese evento porque el trigger estuvo deshabilitado.

2. **¿Quién cambió el teléfono?**  
   El rol `app_ventas` desde `127.0.0.1` (`app-ventas-web`) el `2026-11-19 05:31:35.598 UTC` mediante `UPDATE clientes SET telefono = '6679990000' WHERE id = 3` (`bitacora-lab01.log` línea 62). Respecto a qué número tenía antes, **no hay evidencia** porque en ese punto solo registraba la bitácora de sentencias, no había disparador por fila. *(Sobre la lectura posterior de `soporte_ana` en la Actividad 15 tampoco hay evidencia de qué consultó, solo su conexión en líneas 240–243).*

3. **¿Hubo intentos de acceso fallidos? ¿De qué usuarios y desde dónde?**  
   Sí, dos intentos fallidos desde `127.0.0.1`:
   * `app_ventas` el `2026-11-19 05:31:26.559 UTC` por contraseña incorrecta (`bitacora-lab01.log` líneas 21–23).
   * `usuario_inexistente` el `2026-11-19 05:31:27.124 UTC` porque el rol no existe (`bitacora-lab01.log` líneas 24–27).

4. **¿Qué valor tenía el RFC antes de cada cambio?**
   * Antes de la **Actividad 3**: **No hay evidencia** en la bitácora ni en la tabla de auditoría.
   * Antes de la **Actividad 7**: **No hay evidencia** en la bitácora ni en la tabla de auditoría.
   * Antes de la **Actividad 12**: `'GAMA780912XYZ'`, demostrado en `auditoria.cambios_clientes` (`id_evento = 1`, campo `valores_antes->>'rfc'`).
   * Antes de la **Actividad 14**: en `auditoria.cambios_clientes` **no hay evidencia** directa de esa operación porque el disparador se apagó temporalmente; el último estado acreditado antes de la línea 234 correspondía al `id_evento = 1` (`'GAMA780912ZZZ'`).
