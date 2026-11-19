# Evidencia 09 — Sesiones activas en `pg_stat_activity` frente a la bitácora

* **Estudiante:** Genaro Isaac Cárdenas Soto (`@darksitoV`)
* **Actividad:** Actividad 9 — Sesiones activas con `pg_stat_activity`

## 1. Monitoreo de sesión de larga duración

En una terminal aparte se ejecutó un proceso lento simulando un reporte:
```bash
psql "postgresql://soporte_ana:<REDACTED>@127.0.0.1/comercial?application_name=reporte-mensual" -c "SELECT pg_sleep(90)"
```

Mientras esa sesión seguía abierta, se consultó `pg_stat_activity` como `postgres`:
```sql
SELECT pid, usename, application_name, client_addr, backend_start, state, left(query, 30) AS query
FROM pg_stat_activity
WHERE backend_type = 'client backend';
```

**Resultado con la sesión en curso:**
```text
 pid |   usename   | application_name | client_addr |         backend_start         | state  |             query
-----+-------------+------------------+-------------+-------------------------------+--------+--------------------------------
  72 | soporte_ana | reporte-mensual  | 127.0.0.1   | 2026-11-19 05:31:40.418283+00 | active | SELECT pg_sleep(90)
  74 | postgres    | psql             |             | 2026-11-19 05:31:43.889481+00 | active | SELECT pid, usename, applicati
(2 rows)
```

Buscando ese mismo PID `[72]` en `dba.bitacora`:
```sql
SELECT num, linea FROM dba.bitacora WHERE linea LIKE '%[72]%' ORDER BY num;
```

```text
 num | linea
-----+----------------------------------------------------------------------------------------------------------------------
  84 | 2026-11-19 05:31:40.418 UTC [72] user=[unknown] db=[unknown] app=[unknown] client=127.0.0.1 LOG:  connection received: host=127.0.0.1 port=46442
  85 | 2026-11-19 05:31:40.426 UTC [72] user=soporte_ana db=comercial app=[unknown] client=127.0.0.1 LOG:  connection authenticated: identity="soporte_ana" method=scram-sha-256 (/var/lib/postgresql/data/pg_hba.conf:119)
  86 | 2026-11-19 05:31:40.426 UTC [72] user=soporte_ana db=comercial app=[unknown] client=127.0.0.1 LOG:  connection authorized: user=soporte_ana database=comercial application_name=reporte-mensual
```

Una vez transcurridos los 90 segundos, se repitió la consulta:
```text
 pid | usename  | application_name | client_addr |         backend_start         | state  |             query
-----+----------+------------------+-------------+-------------------------------+--------+--------------------------------
 107 | postgres | psql             |             | 2026-11-19 05:33:14.370962+00 | active | SELECT pid, usename, applicati
(1 row)
```

Al revisar `dba.bitacora` para `[72]` después de terminar el reporte, ya aparece el cierre en la línea 132:
```text
 132 | 2026-11-19 05:33:10.461 UTC [72] user=soporte_ana db=comercial app=reporte-mensual client=127.0.0.1 LOG:  disconnection: session time: 0:01:30.042 user=soporte_ana database=comercial host=127.0.0.1 port=46442
```

## 2. Preguntas

1. **¿Qué columna permite relacionar una sesión con sus líneas de bitácora?**  
   La columna `pid` de `pg_stat_activity` (`72`), que en el prefijo `log_line_prefix` sale entre corchetes (`[72]`).
2. **Después de que termina el reporte, ¿qué fuente conserva evidencia de que existió?**  
   Únicamente la bitácora del servidor (`dba.bitacora` y el archivo `.log` en disco). En `pg_stat_activity` solo aparecen las sesiones abiertas en ese instante, por eso en cuanto cerró `soporte_ana` desapareció de la vista.
3. **¿Por qué `client_addr` aparece vacío en la sesión del administrador?**  
   Porque `postgres` entró por el socket Unix local (`client=[local]`), no por TCP/IP, así que no hay dirección IP del cliente que mostrar.
