# Evidencia 08 — Errores de permisos y operaciones rechazadas

* **Estudiante:** Genaro Isaac Cárdenas Soto (`@darksitoV`)
* **Actividad:** Actividad 8 — Errores y operaciones rechazadas

## 1. Operaciones rechazadas ejecutadas

**Intento de borrado por `soporte_ana`:**
```bash
psql "postgresql://soporte_ana:<REDACTED>@127.0.0.1/comercial" -c "DELETE FROM clientes WHERE id = 5"
```
```text
ERROR:  permission denied for table clientes
```

**Intento de eliminar un rol con dependencias (`postgres`):**
```sql
DROP ROLE soporte_ana;
```
```text
ERROR:  role "soporte_ana" cannot be dropped because some objects depend on it
DETAIL:  privileges for table clientes
```

**Consulta en `dba.bitacora`:**
```sql
SELECT num, linea FROM dba.bitacora
WHERE linea ~ '(ERROR|STATEMENT|DETAIL):  (permission|privileges|role|DELETE|DROP)'
ORDER BY num;
```

```text
 num | linea
-----+----------------------------------------------------------------------------------------------------------------------
  71 | 2026-11-19 05:31:37.756 UTC [66] user=soporte_ana db=comercial app=psql client=127.0.0.1 ERROR:  permission denied for table clientes
  72 | 2026-11-19 05:31:37.756 UTC [66] user=soporte_ana db=comercial app=psql client=127.0.0.1 STATEMENT:  DELETE FROM clientes WHERE id = 5
  77 | 2026-11-19 05:31:38.321 UTC [68] user=postgres db=comercial app=psql client=[local] ERROR:  role "soporte_ana" cannot be dropped because some objects depend on it
  78 | 2026-11-19 05:31:38.321 UTC [68] user=postgres db=comercial app=psql client=[local] DETAIL:  privileges for table clientes
  79 | 2026-11-19 05:31:38.321 UTC [68] user=postgres db=comercial app=psql client=[local] STATEMENT:  DROP ROLE soporte_ana;
```

Gracias a `log_min_error_statement = error`, PostgreSQL escribió tanto el mensaje `ERROR:` como la sentencia `STATEMENT:` completa que causó el fallo, aunque `soporte_ana` no tuviera permiso para borrar.

## 2. Preguntas

1. **¿El intento de `soporte_ana` causó algún daño? ¿Por qué debe auditarse de todos modos?**  
   No causó daño en los datos porque el motor bloqueó el `DELETE`. Aun así debe auditarse porque los intentos fallidos repetidos indican errores de configuración en aplicaciones, pruebas no autorizadas de un usuario o posible escalamiento/reconocimiento interno.
2. **¿Qué diferencia hay entre un error de autorización (esta actividad) y uno de autenticación (Actividad 5)?**  
   En la Actividad 5 falló la **autenticación**: el cliente no probó su identidad (contraseña incorrecta o rol inexistente) y no llegó a abrir sesión. Aquí `soporte_ana` sí pasó la autenticación y abrió sesión, pero falló la **autorización**: su rol no tiene permiso `DELETE` sobre `clientes`.
3. **¿Qué indica el error de `DROP ROLE` sobre el orden correcto para dar de baja a un usuario?**  
   Indica que no se puede eliminar directamente un rol mientras conserve privilegios asignados o sea propietario de objetos. Primero hay que revocarle los permisos (`REVOKE`) y reasignar o eliminar objetos propios (`REASSIGN OWNED` / `DROP OWNED`), y al final ejecutar `DROP ROLE`.
