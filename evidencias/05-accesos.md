# Evidencia 05 — Registro e interpretación de accesos exitosos y fallidos

* **Estudiante:** Genaro Isaac Cárdenas Soto (`@darksitoV`)
* **Actividad:** Actividad 5 — Accesos exitosos y fallidos

## 1. Pruebas de conexión ejecutadas

```bash
psql "postgresql://app_ventas:<REDACTED>@127.0.0.1/comercial" -c "SELECT 1"
psql "postgresql://usuario_inexistente:<REDACTED>@127.0.0.1/comercial" -c "SELECT 1"
psql "postgresql://app_ventas:<REDACTED>@127.0.0.1/comercial?application_name=app-ventas-web" -c "SELECT count(*) FROM clientes"
```

**Salida en cliente:**
```text
psql: error: connection to server at "127.0.0.1", port 5432 failed: FATAL:  password authentication failed for user "app_ventas"
psql: error: connection to server at "127.0.0.1", port 5432 failed: FATAL:  password authentication failed for user "usuario_inexistente"
 count
-------
     5
```

**Consulta en `dba.bitacora`:**
```sql
SELECT num, linea FROM dba.bitacora WHERE linea LIKE '%client=127.0.0.1%' ORDER BY num;
```

```text
 num | linea
-----+----------------------------------------------------------------------------------------------------------------------------------------------------------------------
  21 | 2026-11-19 05:31:26.550 UTC [44] user=[unknown] db=[unknown] app=[unknown] client=127.0.0.1 LOG:  connection received: host=127.0.0.1 port=50044
  22 | 2026-11-19 05:31:26.559 UTC [44] user=app_ventas db=comercial app=[unknown] client=127.0.0.1 FATAL:  password authentication failed for user "app_ventas"
  23 | 2026-11-19 05:31:26.559 UTC [44] user=app_ventas db=comercial app=[unknown] client=127.0.0.1 DETAIL:  Connection matched file "/var/lib/postgresql/data/pg_hba.conf" line 119: "host    all             all             127.0.0.1/32            scram-sha-256"
  24 | 2026-11-19 05:31:27.116 UTC [46] user=[unknown] db=[unknown] app=[unknown] client=127.0.0.1 LOG:  connection received: host=127.0.0.1 port=50054
  25 | 2026-11-19 05:31:27.124 UTC [46] user=usuario_inexistente db=comercial app=[unknown] client=127.0.0.1 FATAL:  password authentication failed for user "usuario_inexistente"
  26 | 2026-11-19 05:31:27.124 UTC [46] user=usuario_inexistente db=comercial app=[unknown] client=127.0.0.1 DETAIL:  Role "usuario_inexistente" does not exist.
  28 | 2026-11-19 05:31:27.700 UTC [48] user=[unknown] db=[unknown] app=[unknown] client=127.0.0.1 LOG:  connection received: host=127.0.0.1 port=50064
  29 | 2026-11-19 05:31:27.708 UTC [48] user=app_ventas db=comercial app=[unknown] client=127.0.0.1 LOG:  connection authenticated: identity="app_ventas" method=scram-sha-256 (/var/lib/postgresql/data/pg_hba.conf:119)
  30 | 2026-11-19 05:31:27.708 UTC [48] user=app_ventas db=comercial app=[unknown] client=127.0.0.1 LOG:  connection authorized: user=app_ventas database=comercial application_name=app-ventas-web
  31 | 2026-11-19 05:31:27.712 UTC [48] user=app_ventas db=comercial app=app-ventas-web client=127.0.0.1 LOG:  disconnection: session time: 0:00:00.012 user=app_ventas database=comercial host=127.0.0.1 port=50064
```

## 2. Análisis campo por campo (línea 22)

| Campo | Valor observado | Significado |
| :--- | :--- | :--- |
| Fecha y hora | `2026-11-19 05:31:26.559 UTC` | Momento exacto del rechazo en UTC |
| PID | `44` | Identificador del proceso backend que atendió el intento |
| Usuario | `app_ventas` | Rol declarado en la petición de conexión |
| Base de datos | `comercial` | Base solicitada por el cliente |
| Aplicación | `[unknown]` | Aún no se aplicaba el parámetro de sesión tras fallar la autenticación |
| Cliente | `127.0.0.1` | IP desde donde llegó la conexión TCP |
| Severidad | `FATAL` | Error que cierra de inmediato el intento de sesión |
| Mensaje | `password authentication failed for user "app_ventas"` | Contraseña incorrecta para el rol indicado |
| Regla aplicada | `pg_hba.conf` línea 119 | Regla que exigió `scram-sha-256` (línea 23 `DETAIL`) |

## 3. Preguntas

1. **La bitácora registra el usuario `app_ventas` en el intento fallido. ¿Eso prueba que la aplicación de ventas intentó entrar? ¿Qué prueba realmente?**  
   No. Solo prueba que alguien desde `127.0.0.1` intentó conectarse declarando llamarse `app_ventas` y falló la contraseña. Un atacante o un usuario local puede probar ese nombre de rol manualmente desde otra terminal.
2. **¿Qué información adicional registra PostgreSQL cuando el rol no existe? ¿Por qué aparece en la bitácora y no en el mensaje que recibe el cliente?**  
   En la línea 26 agrega `DETAIL: Role "usuario_inexistente" does not exist.` Al cliente solo le devuelve el error genérico `password authentication failed` para evitar enumeración de usuarios: no revelarle a quien ataca qué nombres de cuenta sí existen en la base y cuáles no.
3. **¿Por qué `app=[unknown]` en el intento fallido, pero `app=app-ventas-web` en la desconexión?**  
   Porque el valor de `application_name` se establece en el paquete de arranque ya aceptada la sesión o justo en la autorización (línea 30). En un acceso fallido (línea 22) el cliente ni siquiera logra completar esa etapa, así que el prefijo `%a` queda en `[unknown]`.
4. **¿Qué patrón de varias líneas te haría sospechar de un ataque de fuerza bruta? Escribe la consulta que contaría los intentos fallidos por usuario.**  
   Muchos eventos `FATAL: password authentication failed` seguidos desde la misma IP en pocos segundos o minutos, probando distintas claves sobre un mismo usuario o varios nombres inexistentes.

   Consulta ejecutada en `dba.bitacora` y resultado obtenido:
   ```sql
   SELECT (regexp_match(linea, 'user=([^ ]+)'))[1] AS usuario,
          count(*) AS intentos_fallidos
   FROM dba.bitacora
   WHERE linea LIKE '%FATAL:  password authentication failed%'
   GROUP BY usuario
   ORDER BY intentos_fallidos DESC;
   ```

   ```text
          usuario       | intentos_fallidos
   ---------------------+-------------------
    app_ventas          |                 1
    usuario_inexistente |                 1
   (2 rows)
   ```
