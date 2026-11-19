# Evidencia 14 — Límites del mecanismo: lecturas y volumen de registros

* **Estudiante:** Genaro Isaac Cárdenas Soto (`@darksitoV`)
* **Actividad:** Actividad 15 — Límites: lecturas y volumen

## 1. Pruebas de lectura y modificación masiva

**Lectura ejecutada como `soporte_ana`:**
```bash
psql "postgresql://soporte_ana:<REDACTED>@127.0.0.1/comercial" -c "SELECT nombre, rfc, telefono FROM clientes WHERE id = 3"
```
```text
    nombre    |      rfc      |  telefono
--------------+---------------+------------
 María García | GAMA780912GHI | 6679990000
```

**Actualización masiva sin `WHERE` como `postgres` y verificaciones:**
```sql
UPDATE clientes SET segmento = 'regular';

SELECT count(*) AS lineas_bitacora FROM dba.bitacora
WHERE linea LIKE '%statement: UPDATE clientes SET segmento%';

SELECT operacion, count(*) FROM auditoria.cambios_clientes GROUP BY operacion ORDER BY operacion;

SELECT count(*) AS lecturas_soporte FROM dba.bitacora
WHERE linea LIKE '%user=soporte_ana%SELECT nombre, rfc%';
```

**Resultados:**
```text
UPDATE 5
 lineas_bitacora
-----------------
               1

 operacion | count
-----------+-------
 DELETE    |     1
 INSERT    |     1
 UPDATE    |     6

 lecturas_soporte
------------------
                0
```

El `UPDATE` afectó a los 5 clientes de la tabla: en la bitácora generó **1 línea** (`statement: UPDATE clientes SET segmento = 'regular';`, línea 246), y en `auditoria.cambios_clientes` agregó **5 filas nuevas** de golpe (pasando de 1 a 6 eventos `UPDATE`). Por su parte, la lectura de `soporte_ana` devolvió `0` coincidencias porque no existe trigger para `SELECT` y `log_statement = 'mod'` ignora lecturas.

## 2. Preguntas

1. **Si `clientes` tuviera un millón de registros, ¿qué ocurriría con la auditoría tras un `UPDATE` sin `WHERE`?**  
   El disparador `FOR EACH ROW` generaría un millón de registros JSONB en `auditoria.cambios_clientes` dentro de la misma transacción. Esto multiplicaría la escritura en disco y WAL, volvería muy lenta la operación e incluso podría agotar espacio o causar contención de I/O.
2. **Propón quién podría autorizar la depuración de `auditoria.cambios_clientes`.**  
   Un responsable de Auditoría Interna o Seguridad de la Información junto con el Propietario del Dato y el área Legal, nunca el DBA ni un desarrollador por decisión propia, dejando registro del respaldo o archivado previo.
3. **¿Por qué `log_statement = 'all'` puede convertir la bitácora en un nuevo depósito de datos sensibles?**  
   Porque guarda todas las consultas de lectura con sus literales y condiciones (`WHERE correo = ...`, `WHERE rfc = ...`), concentrando búsquedas y parámetros con datos personales en un archivo plano fuera del control de permisos por tabla.
