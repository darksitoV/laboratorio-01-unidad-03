# Evidencia 10 — Diseño del esquema y tabla de auditoría de datos

* **Estudiante:** Genaro Isaac Cárdenas Soto (`@darksitoV`)
* **Actividad:** Actividad 10 — Diseñar y crear el registro de auditoría
* **Script relacionado:** [`sql/04-esquema-auditoria.sql`](../sql/04-esquema-auditoria.sql)

## 1. Diseño de columnas y justificación

| Campo propuesto | Tipo | ¿Qué pregunta responde? | ¿Puede ser nulo? ¿Por qué? |
| :--- | :--- | :--- | :--- |
| `id_evento` | `BIGSERIAL` | Identificador único y orden secuencial del evento | No (`PRIMARY KEY`); cada fila necesita llave única |
| `momento` | `TIMESTAMPTZ` | ¿Cuándo ocurrió el cambio? | No (`NOT NULL DEFAULT now()`); sin fecha no sirve como registro cronológico |
| `usuario_sesion` | `TEXT` | ¿Quién inició la sesión que provocó el cambio? | No (`NOT NULL DEFAULT session_user`); siempre hay un rol autenticado |
| `usuario_efectivo` | `TEXT` | ¿Con qué privilegios efectivos corrió la inserción? | No (`NOT NULL DEFAULT current_user`); distingue `SECURITY DEFINER` del usuario real |
| `aplicacion` | `TEXT` | ¿Desde qué aplicación se conectó el cliente? | Sí (`DEFAULT current_setting('application_name')`); algunos clientes no la mandan o va vacía |
| `ip_cliente` | `INET` | ¿Desde qué equipo/IP llegó la operación? | Sí (`DEFAULT inet_client_addr()`); en conexiones por socket Unix local devuelve `NULL` |
| `operacion` | `TEXT` | ¿Qué tipo de cambio se aplicó (`INSERT`, `UPDATE`, `DELETE`)? | No (`NOT NULL`); identifica la acción exacta del disparador |
| `id_cliente` | `BIGINT` | ¿Sobre qué registro de `clientes` recayó el cambio? | Sí (aunque en `clientes` siempre viene de `NEW.id` u `OLD.id`); facilita filtrar historial por cliente |
| `valores_antes` | `JSONB` | ¿Qué valores tenía la fila antes del cambio? | Sí; en un `INSERT` no existe registro previo |
| `valores_despues` | `JSONB` | ¿Con qué valores quedó la fila tras el cambio? | Sí; en un `DELETE` la fila deja de existir después |

## 2. Creación en PostgreSQL y verificación

Se ejecutó [`sql/04-esquema-auditoria.sql`](../sql/04-esquema-auditoria.sql) para crear el esquema `auditoria` sin permisos para `PUBLIC` y la tabla `auditoria.cambios_clientes`.

**Comprobación (`\dn+ auditoria` y `\d auditoria.cambios_clientes`):**
```text
CREATE SCHEMA
REVOKE
CREATE TABLE

                      List of schemas
   Name    |  Owner   |  Access privileges   | Description
-----------+----------+----------------------+-------------
 auditoria | postgres | postgres=UC/postgres |

                                                 Table "auditoria.cambios_clientes"
      Column      |           Type           | Collation | Nullable |                            Default
------------------+--------------------------+-----------+----------+---------------------------------------------------------------
 id_evento        | bigint                   |           | not null | nextval('auditoria.cambios_clientes_id_evento_seq'::regclass)
 momento          | timestamp with time zone |           | not null | now()
 usuario_sesion   | text                     |           | not null | SESSION_USER
 usuario_efectivo | text                     |           | not null | CURRENT_USER
 aplicacion       | text                     |           |          | current_setting('application_name'::text)
 ip_cliente       | inet                     |           |          | inet_client_addr()
 operacion        | text                     |           | not null |
 id_cliente       | bigint                   |           |          |
 valores_antes    | jsonb                    |           |          |
 valores_despues  | jsonb                    |           |          |
```

## 3. Preguntas

1. **¿Por qué `momento` usa `TIMESTAMPTZ` y no `TIMESTAMP`?**  
   Porque `TIMESTAMPTZ` almacena el instante exacto referido a UTC y lo muestra con la zona horaria correspondiente, evitando ambigüedades si cambia el huso horario del servidor o al comparar con bitácoras en UTC.
2. **¿Por qué se guarda el registro completo en `JSONB` y no solo la columna que cambió?**  
   Porque de esa forma la tabla de auditoría sigue funcionando aunque en el futuro se agreguen o eliminen columnas en `clientes` (como pasó con `segmento`), y guarda la fotografía entera de la fila para recuperar cualquier atributo con operadores `JSONB`.
3. **La tabla de auditoría también contendrá RFC. ¿Qué implica eso para su clasificación y su control de acceso?**  
   Al almacenar `valores_antes` y `valores_despues` con RFC, correo y teléfono, `auditoria.cambios_clientes` pasa a contener datos personales sensibles con el mismo nivel de criticidad que `clientes`. Por eso se aisló en el esquema `auditoria` con `REVOKE ALL ... FROM PUBLIC`, dejando lectura únicamente al administrador/auditor.
