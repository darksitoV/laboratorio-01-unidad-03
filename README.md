# LAB-01: Bitácoras y auditoría del dato en PostgreSQL

Materia: Gestión de Seguridad y Desempeño de Bases de Datos  
Unidad III: Auditoría, trazabilidad y gobierno práctico de datos  
Alumno: Genaro Isaac Cárdenas Soto (@darksitoV)

## Despliegue y versión del servidor

La práctica se corrió en un contenedor de Podman con la imagen oficial `postgres:16` (contenedor `dba-u3-pg`, base de datos `comercial`).

Versión del servidor:

```text
PostgreSQL 16.15 (Debian 16.15-1.pgdg13+2) on x86_64-pc-linux-gnu, compiled by gcc (Debian 14.2.0-19) 14.2.0, 64-bit
```

Las sesiones de administrador y las conexiones por red (`127.0.0.1`) se ejecutaron con `psql` dentro del mismo contenedor. Se realizaron las Partes A y B del laboratorio y el contenedor se conservó para el LAB-03.
