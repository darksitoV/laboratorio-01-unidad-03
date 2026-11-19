# Evidencia 03 — Incidente simulado sin bitácora activa

* **Estudiante:** Genaro Isaac Cárdenas Soto (`@darksitoV`)
* **Actividad:** Actividad 3 — El incidente sin bitácora

## 1. Ejecución del cambio y búsqueda

**Comando ejecutado como `app_ventas` por TCP:**
```bash
psql "postgresql://app_ventas:<REDACTED>@127.0.0.1/comercial?application_name=app-ventas-web" -c "UPDATE clientes SET rfc = 'GAMA780912XXX' WHERE id = 3"
```

**Salida:**
```text
UPDATE 1
```

**Búsqueda en la vista de bitácora como `postgres`:**
```sql
SELECT linea FROM dba.bitacora
WHERE linea ILIKE '%update%' OR linea LIKE '%app_ventas%';
```

**Resultado obtenido:**
```text
 linea
-------
(0 rows)
```

Aunque el cambio sí se aplicó sobre el registro de María García (`id = 3`), el archivo `log/postgresql-2026-11-19_053118.log` sigue con solo las 12 líneas del arranque inicial.

## 2. Respuestas

1. **¿Puedes demostrar quién modificó el RFC?**  
   No. En la bitácora no hay rastro ni de la conexión de `app_ventas` ni de la consulta `UPDATE`.
2. **¿Puedes demostrar que el cambio no lo hizo `soporte_ana`?**  
   Con la bitácora, tampoco. Lo único que descartaría a `soporte_ana` en condiciones normales son los permisos `GRANT` de la Unidad II (ella solo tiene `SELECT` sobre `clientes`), pero si alguien hubiera usado su usuario tras algún descuido de permisos o si existiera duda sobre qué pasó realmente, no hay registro que pruebe qué sesión ejecutó qué.
3. **Los privilegios de la Unidad II, ¿impidieron el cambio? ¿Debían impedirlo?**  
   No lo impidieron y tampoco debían impedirlo: `app_ventas` necesita `UPDATE` sobre `clientes` para operar en el sistema de ventas. El control de acceso decide quién puede modificar un dato, pero la legitimidad o abuso dentro de un permiso válido se revisa con auditoría.
4. **¿Qué tendría que haber estado configurado antes del incidente?**  
   Al menos `log_connections = on`, `log_disconnections = on`, un `log_line_prefix` con `%u %d %a %h` y `log_statement = 'mod'` (o `all`), además de un mecanismo de auditoría a nivel de dato para saber qué valor había antes. Como ya pasó el `UPDATE`, activar esos parámetros ahora no recupera la evidencia del evento pasado.
