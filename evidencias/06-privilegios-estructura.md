# Evidencia 06 — Cambios de privilegios, estructura y exposición de contraseñas

* **Estudiante:** Genaro Isaac Cárdenas Soto (`@darksitoV`)
* **Actividad:** Actividad 6 — Cambios de privilegios y de estructura
* **Script relacionado:** [`sql/03-privilegios-estructura.sql`](../sql/03-privilegios-estructura.sql)

## 1. Sentencias ejecutadas y registro en bitácora

Con `log_statement = 'ddl'` activo se ejecutó en la sesión de `postgres`:
```sql
REVOKE UPDATE ON clientes FROM soporte_ana;
GRANT UPDATE ON clientes TO app_ventas;
ALTER TABLE clientes ADD COLUMN segmento VARCHAR(20);
CREATE ROLE rol_temporal LOGIN PASSWORD '<REDACTED>';
DROP ROLE rol_temporal;
```
*(En el script de demostración [`sql/03-privilegios-estructura.sql`](../sql/03-privilegios-estructura.sql) y en la captura de abajo la contraseña de prueba fue reemplazada por `<REDACTED>`.)*

**Consulta en `dba.bitacora`:**
```sql
SELECT num, linea FROM dba.bitacora WHERE linea LIKE '%statement:%' ORDER BY num;
```

```text
 num | linea
-----+-----------------------------------------------------------------------------------------------------------------------------
  37 | 2026-11-19 05:31:29.830 UTC [52] user=postgres db=comercial app=psql client=[local] LOG:  statement: REVOKE UPDATE ON clientes FROM soporte_ana;
  38 | 2026-11-19 05:31:29.832 UTC [52] user=postgres db=comercial app=psql client=[local] LOG:  statement: GRANT UPDATE ON clientes TO app_ventas;
  39 | 2026-11-19 05:31:29.833 UTC [52] user=postgres db=comercial app=psql client=[local] LOG:  statement: ALTER TABLE clientes ADD COLUMN segmento VARCHAR(20);
  40 | 2026-11-19 05:31:29.835 UTC [52] user=postgres db=comercial app=psql client=[local] LOG:  statement: CREATE ROLE rol_temporal LOGIN PASSWORD '<REDACTED>';
  41 | 2026-11-19 05:31:29.840 UTC [52] user=postgres db=comercial app=psql client=[local] LOG:  statement: DROP ROLE rol_temporal;
```

En la prueba en vivo se comprobó que la contraseña literal pasó a texto claro en la línea 40 de la bitácora, y ejecutar `DROP ROLE rol_temporal;` en la línea 41 no la borra del archivo de log. Si se hubiera usado el metacomando `\password`, el cliente `psql` habría calculado primero el hash SCRAM-SHA-256 antes de enviarlo al servidor.

## 2. Respuestas

1. **¿Qué tipo de evento es cada una de las tres primeras sentencias (privilegio o estructura)?**  
   - `REVOKE UPDATE ON clientes FROM soporte_ana`: evento de **privilegio** (aunque `soporte_ana` no tenía `UPDATE`, la revisión preventiva también queda registrada).  
   - `GRANT UPDATE ON clientes TO app_ventas`: evento de **privilegio**.  
   - `ALTER TABLE clientes ADD COLUMN segmento VARCHAR(20)`: evento de **estructura** (DDL sobre tabla).
2. **¿Por qué GRANT y REVOKE quedan registrados con `log_statement = 'ddl'`?**  
   Porque en PostgreSQL la categoría `'ddl'` incluye no solo la definición de objetos (`CREATE`, `ALTER`, `DROP`), sino también las sentencias de control de acceso y metadatos (`GRANT`, `REVOKE`, `COMMENT`), de modo que los cambios de permisos queden auditados aunque no se estén registrando consultas DML.
3. **Si la bitácora contiene contraseñas, ¿quién debería poder leerla? Relaciónalo con la gestión de secretos de la Unidad II.**  
   Solo personal mínimo indispensable con privilegios de DBA o auditoría de seguridad autorizada (nunca usuarios comunes ni cuentas de aplicación). En la Unidad II se vio que los secretos deben protegerse en almacenamiento y no exponerse en código ni logs; por eso las claves no deben mandarse en texto claro dentro de SQL, y las bitácoras que puedan haber capturado una deben tratarse con el mismo resguardo que un archivo de secretos o sanitizarse antes de compartirse.
