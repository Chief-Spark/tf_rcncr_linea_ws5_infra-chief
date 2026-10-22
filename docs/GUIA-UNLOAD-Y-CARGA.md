# Guia para desarrollo: UNLOAD de Reconocer y carga en DynamoDB y Redshift Bureau

> Para el equipo que escribe el UNLOAD en Redshift Reconocer y el COPY en Redshift
> Bureau. Decisiones tomadas el 2026-10-21 y 2026-10-22 (traza en
> [SOLICITUD-REPOS-DESARROLLO.md, seccion 7](SOLICITUD-REPOS-DESARROLLO.md#7-analisis-en-curso-novedades-hacia-la-cuenta-batch)).
> Datos de las tablas: `DICCIONARIO_DATOS_7_TABLAS_DOMINIO.md`.
>
> Nombres de develop. En otros ambientes cambia el prefijo `dev-647096294147-`.

## Indice

1. [El flujo en una mirada](#1-el-flujo-en-una-mirada)
2. [Reglas comunes](#2-reglas-comunes)
3. [Paso 1: UNLOAD de las 7 tablas](#3-paso-1-unload-de-las-7-tablas)
4. [Paso 2: archivo final 7_tablas_finish.json](#4-paso-2-archivo-final-7_tablas_finishjson)
5. [Paso 3: carga en DynamoDB (cuenta 147)](#5-paso-3-carga-en-dynamodb-cuenta-147)
6. [Paso 4: COPY en Redshift Bureau (cuenta Batch)](#6-paso-4-copy-en-redshift-bureau-cuenta-batch)
7. [Validaciones](#7-validaciones)
8. [Pendientes antes de la primera corrida](#8-pendientes-antes-de-la-primera-corrida)

---

## 1. El flujo en una mirada

Diagrama editable (draw.io): [arquitectura-reconocer-linea.drawio](arquitectura-reconocer-linea.drawio),
pagina "1. Carga de datos (novedades)".

```
Redshift Reconocer (147)
  1. UNLOAD de las 7 tablas  ─►  s3://<triggers>/nov/<run_id>/data/<tabla>/
  2. Escribe el CTL final    ─►  s3://<triggers>/nov/<run_id>/7_tablas_finish.json
                                        │
                     ┌──────────────────┴──────────────────┐
                     ▼                                     ▼
       EventBridge (147)                         EventBridge default (Batch 651706752126)
       Step Function Update RecMaster            Step Function Upload
         FULL  → S3 Import (tabla nueva)           COPY a tablas temporales
         DELTA → Glue (escribe encima)             FULL  → reemplaza la tabla final
       DynamoDB reconocer_master                   DELTA → MERGE en la tabla final
```

- Los dos flujos arrancan **al mismo tiempo** con el mismo archivo final.
- **El archivo final se escribe solo cuando las 7 tablas terminaron.** Si se
  escribe antes, los flujos arrancan con datos incompletos.
- Bucket (develop): `dev-647096294147-rcncr-ws5-triggers-reconocer-s3`.

---

## 2. Reglas comunes

**`run_id`**: fecha y hora (UTC) + tipo de carga. Ej.: `20261022T053000Z_FULL`,
`20261022T053000Z_DELTA`.

**Carpetas** (una por corrida; dentro, una por tabla):
```
nov/<run_id>/data/mat_info_basica/
nov/<run_id>/data/mat_info_ubicacion/
nov/<run_id>/data/mat_info_actividad_economica/
nov/<run_id>/data/mat_ubicacion_agregada/
nov/<run_id>/data/mat_info_contactabilidad/
nov/<run_id>/data/mat_info_punto_interes/
nov/<run_id>/data/mat_info_movilidad/
nov/<run_id>/7_tablas_finish.json
```
Dentro de `data/` **solo van archivos de datos**: el S3 Import carga todo lo que
encuentre ahi.

**Formato**: CSV con encabezado, comprimido GZIP.

**Columnas de cada archivo**, en este orden:
1. `pk` = `tipo_identificacion || '#' || numero_identificacion`. Ej.: `CC#1020304050`.
2. `sk` = de que tabla viene la fila (tabla de la seccion 3).
3. Solo en d5 y d7: `tipo_identificacion` y `numero_identificacion` (vienen del
   cruce con d1).
4. Todas las columnas de la tabla, **incluidas las 3 de trazabilidad**
   (`lote`, `fecha_actualizacion`, `usuario_bd`).

**`pk` y `sk` nunca pueden ir vacios.** Si una parte puede ser NULL, usar
`COALESCE(..., '')` al armarlas, y excluir las filas sin tipo o numero de
identificacion (contarlas y reportarlas).

**NULL y vacio**: no significan lo mismo (d5: NULL = "no se sabe"; d4 `genero`:
vacio). Se define en la prueba de develop (seccion 8) como se escriben en el
CSV y como quedan en DynamoDB.

---

## 3. Paso 1: UNLOAD de las 7 tablas

### Plantilla

```sql
UNLOAD ('<SELECT de la tabla>')
TO 's3://dev-647096294147-rcncr-ws5-triggers-reconocer-s3/nov/<run_id>/data/<tabla>/'
IAM_ROLE 'arn:aws:iam::647096294147:role/BURoleFor-dev-647096294147-rcncr-ws5-redshift-unload'
FORMAT AS CSV
HEADER
GZIP
CLEANPATH;   -- si se repite el mismo run_id, borra lo anterior de esa carpeta

SELECT pg_last_unload_count();  -- filas escritas: va al archivo final
```

Dentro del texto del UNLOAD, cada comilla simple se escribe doble (`'#'` →
`''#''`).

### `pk`, `sk` y cruces por tabla

| | Tabla | Filas por persona | `sk` | Cruce |
|---|---|---|---|---|
| d4 | `mat_info_basica` | 1 | `INFO_BASICA` | — |
| d1 | `mat_info_ubicacion` | N | `UBICACION#<id>` | — |
| d2 | `mat_info_actividad_economica` | N | `ACTIVIDAD#<ciiu>` | — |
| d3 | `mat_ubicacion_agregada` | N | `UBIC_AGREGADA#<ubicacion_codigodane>#<ubicacion_ciudad>#<ubicacion_departamento>#<ubicacion_dato>` | — |
| d5 | `mat_info_contactabilidad` | N | `CONTACTABILIDAD#<ubicacion_id>` | con d1: `c.ubicacion_id = u.id` |
| d7 | `mat_info_punto_interes` | N | `PUNTO_INTERES#<ubicacion_id>#<id>` | con d1: `p.ubicacion_id = u.cod_dw_ubic` |
| d6 | `mat_info_movilidad` | 0..N | `MOVILIDAD#<id>` | — |

Notas:
- **d3**: su llave son 7 columnas; 3 identifican a la persona (van en el `pk`) y
  4 la ubicacion (van en el `sk`). `ubicacion_dato` va **al final** porque las
  direcciones pueden traer `#`.
- **d5**: de su llave `(id, sector, ubicacion_id)`, `id` y `sector` siempre son
  NULL; solo se usa `ubicacion_id`.
- **d7**: la ubicacion fisica puede ser de varias personas. **Se duplica por
  persona** (decision 2026-10-22): una fila por cada persona que tenga esa
  ubicacion. Usar `SELECT DISTINCT` para no repetir la misma persona.

### Ejemplos de SELECT

d4 `mat_info_basica`:
```sql
SELECT tipo_identificacion || '#' || numero_identificacion::VARCHAR AS pk,
       'INFO_BASICA' AS sk,
       b.*
FROM bdm_datos.mat_info_basica b
WHERE tipo_identificacion IS NOT NULL AND numero_identificacion IS NOT NULL
```

d3 `mat_ubicacion_agregada`:
```sql
SELECT tipo_identificacion || '#' || numero_identificacion::VARCHAR AS pk,
       'UBIC_AGREGADA#' || COALESCE(ubicacion_codigodane, '') || '#'
         || COALESCE(ubicacion_ciudad, '') || '#'
         || COALESCE(ubicacion_departamento, '') || '#'
         || COALESCE(ubicacion_dato, '') AS sk,
       a.*
FROM bdm_datos.mat_ubicacion_agregada a
WHERE tipo_identificacion IS NOT NULL AND numero_identificacion IS NOT NULL
```

d5 `mat_info_contactabilidad` (cruce 1 a 1 con d1):
```sql
SELECT u.tipo_identificacion || '#' || u.numero_identificacion::VARCHAR AS pk,
       'CONTACTABILIDAD#' || c.ubicacion_id::VARCHAR AS sk,
       u.tipo_identificacion,
       u.numero_identificacion,
       c.*
FROM bdm_datos.mat_info_contactabilidad c
JOIN bdm_datos.mat_info_ubicacion u ON u.id = c.ubicacion_id
WHERE u.tipo_identificacion IS NOT NULL AND u.numero_identificacion IS NOT NULL
```

d7 `mat_info_punto_interes` (duplicado por persona):
```sql
SELECT DISTINCT
       u.tipo_identificacion || '#' || u.numero_identificacion::VARCHAR AS pk,
       'PUNTO_INTERES#' || p.ubicacion_id::VARCHAR || '#' || p.id::VARCHAR AS sk,
       u.tipo_identificacion,
       u.numero_identificacion,
       p.*
FROM bdm_datos.mat_info_punto_interes p
JOIN bdm_datos.mat_info_ubicacion u ON u.cod_dw_ubic = p.ubicacion_id
WHERE u.tipo_identificacion IS NOT NULL AND u.numero_identificacion IS NOT NULL
```

d1, d2 y d6 siguen el patron de d4 con su `sk` de la tabla.

---

## 4. Paso 2: archivo final `7_tablas_finish.json`

Se escribe **despues** de que terminan los 7 UNLOAD, con los conteos de
`pg_last_unload_count()`:

```json
{
  "run_id": "20261022T053000Z_FULL",
  "tipo_carga": "FULL",
  "fecha_fin": "2026-10-22T05:30:00Z",
  "dominios": [
    {
      "nombre": "mat_info_basica",
      "s3_path": "s3://dev-647096294147-rcncr-ws5-triggers-reconocer-s3/nov/20261022T053000Z_FULL/data/mat_info_basica/",
      "registros_esperados": 125000
    }
  ]
}
```
Una entrada en `dominios` por cada una de las 7 tablas. `tipo_carga` = `FULL` o
`DELTA`.

**Como escribirlo**
- **Recomendado:** que el proceso que orquesta el calculo lo suba con un
  `PutObject` a `nov/<run_id>/7_tablas_finish.json`. El nombre queda exacto.
- **Desde Redshift:** un UNLOAD de una consulta que arme el JSON, con
  `PARALLEL OFF` y `EXTENSION 'json'`, sin `CSV` ni `GZIP`. **Ojo:** Redshift
  agrega `000` al nombre (`7_tablas_finish000.json`). Si se usa esta opcion,
  avisar al equipo de IaC para que la regla de EventBridge acepte ese nombre.

---

## 5. Paso 3: carga en DynamoDB (cuenta 147)

No la programa quien hace el UNLOAD; la hace la Step Function Update RecMaster
(IaC) y el Glue (repo `A_RCNCR_LN_RCMS_TRNSFRM`). Se describe para que el CSV
cumpla lo que se necesita.

**Tabla**: una sola, `reconocer_master`, llave `pk` + `sk` (las dos texto).

**FULL**
1. La Step Function lanza el **S3 Import** sobre `nov/<run_id>/data/`. El S3
   Import crea una **tabla nueva** con las filas de las 7 tablas.
2. Validation compara los conteos con `registros_esperados`.
3. Se cambia el puntero de tabla vigente en **Metadata & Control**.
4. Se borra la tabla anterior.

**DELTA**
- El Glue lee `nov/<run_id>/data/<tabla>/` y escribe cada fila en la tabla
  vigente (si ya existe la misma `pk` + `sk`, la reemplaza). No hay borrados.

**Lo que esto exige del CSV**
- Los nombres de columna del encabezado son los nombres de los atributos en
  DynamoDB. `pk` y `sk` deben llamarse exactamente asi.
- El S3 Import guarda todo como **texto** (salvo `pk`/`sk`). El Glue de DELTA
  debe escribir tambien como texto.
- `tipo_identificacion` en el `pk` debe usar el mismo valor que recibe el API
  (`GET /v1/sujetos/{tipo}/{numero}/...`), por ejemplo `CC`.

---

## 6. Paso 4: COPY en Redshift Bureau (cuenta Batch)

Lo ejecuta la Step Function Upload de la cuenta Batch. Las tablas de Bureau se
llaman igual y tienen las mismas columnas que las 7 de Reconocer.

### Por que tablas temporales (staging)
El CSV trae columnas que las tablas de Bureau no tienen (`pk`, `sk` y, en d5/d7,
`tipo_identificacion` y `numero_identificacion`). El COPY carga primero en una
tabla temporal con esas columnas, y de ahi pasa a la tabla final.

Tabla temporal = `pk VARCHAR(300)`, `sk VARCHAR(1024)`, (en d5/d7:
`tipo_identificacion VARCHAR(30)`, `numero_identificacion BIGINT`) y luego las
mismas columnas de la tabla final, **en el mismo orden** que el CSV.

### COPY
```sql
COPY stg_mat_info_basica
FROM 's3://dev-647096294147-rcncr-ws5-triggers-reconocer-s3/nov/<run_id>/data/mat_info_basica/'
IAM_ROLE 'arn:aws:iam::651706752126:role/<rol del Redshift Bureau>,arn:aws:iam::647096294147:role/BURoleFor-dev-647096294147-rcncr-ws5-redshift-copy-xacct'
FORMAT AS CSV
IGNOREHEADER 1
GZIP
REGION 'us-east-1';
```
Los dos roles separados por coma son el **role chaining**: el rol de Bureau
asume el de la 147, que es el unico que puede leer el bucket.

### FULL: reemplazar la tabla final
```sql
BEGIN;
DELETE FROM bdm_datos.mat_info_basica;
INSERT INTO bdm_datos.mat_info_basica
SELECT DISTINCT <columnas de la tabla final> FROM stg_mat_info_basica;
COMMIT;
```
Usar `DELETE` y no `TRUNCATE`: en Redshift, `TRUNCATE` confirma la transaccion
en el acto y la tabla quedaria vacia mientras otros la consultan (Bureau no se
pausa).

### DELTA: actualizar o insertar (MERGE)
```sql
MERGE INTO bdm_datos.mat_info_basica USING (
  SELECT DISTINCT <columnas de la tabla final> FROM stg_mat_info_basica
) s
ON bdm_datos.mat_info_basica.id = s.id
WHEN MATCHED THEN UPDATE SET <columna> = s.<columna>, ...
WHEN NOT MATCHED THEN INSERT VALUES (s.<columna>, ...);
```

Llave del `ON` por tabla:

| Tabla | Llave |
|---|---|
| d4 `mat_info_basica` | `id` |
| d1 `mat_info_ubicacion` | `id` |
| d2 `mat_info_actividad_economica` | `info_basica_id`, `ciiu` |
| d3 `mat_ubicacion_agregada` | `info_basica`, `tipo_identificacion`, `numero_identificacion`, `ubicacion_dato`, `ubicacion_codigodane`, `ubicacion_ciudad`, `ubicacion_departamento` |
| d5 `mat_info_contactabilidad` | `ubicacion_id` |
| d7 `mat_info_punto_interes` | `id`, `ubicacion_id` |
| d6 `mat_info_movilidad` | `id` |

- El `SELECT DISTINCT` quita los duplicados de d7 (vienen uno por persona). El
  MERGE falla si dos filas de origen chocan con la misma fila final.
- En d3, si alguna columna de la llave puede ser NULL, comparar con
  `COALESCE(...)` en el `ON` (NULL = NULL no es verdadero en SQL).

---

## 7. Validaciones

| Donde | Que se valida |
|---|---|
| UNLOAD | Filas por tabla (`pg_last_unload_count()`) y filas excluidas por no tener tipo o numero |
| DynamoDB | Validation compara lo cargado con `registros_esperados` del archivo final |
| Bureau | Filas cargadas en cada tabla temporal contra `registros_esperados` (en d7, antes del `DISTINCT`) |

Si una validacion falla, no se cambia el puntero (DynamoDB) ni se hace el
`COMMIT` (Bureau).

---

## 8. Pendientes antes de la primera corrida

1. **Prueba de NULL y vacio** en develop: UNLOAD de pocas filas de d4 y d5, S3
   Import, y revisar como quedan `genero` vacio y los NULL de d5.
2. **Prueba del S3 Import con las 7 tablas juntas** en `data/` (archivos con
   encabezados distintos).
3. Definir quien escribe `7_tablas_finish.json` (seccion 4).
4. Asociar el rol `redshift-unload` al cluster Redshift Reconocer.
5. ARN del rol del Redshift Bureau (para crear el rol `redshift-copy-xacct`).
6. Cambios de IaC en la 147: regla de EventBridge con `7_tablas_finish.json`,
   reenvio a la cuenta Batch y Step Function con FULL (S3 Import) y DELTA (Glue).
