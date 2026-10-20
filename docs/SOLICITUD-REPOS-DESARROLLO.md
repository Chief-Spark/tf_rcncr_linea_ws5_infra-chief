# Tickets de creacion de repos de desarrollo

> Un ticket por repo en **DevSecOps SPLatam → Radicar solicitud de Creacion de
> Repositorio**. Plantilla y reglas tomadas de la guia "Solicitud de repositorios".
> Inventario y contrato de cada repo: [INVENTARIO-IAC-Y-REPOS.md](INVENTARIO-IAC-Y-REPOS.md).

## Datos comunes

| Campo | Valor |
|---|---|
| Country | Colombia |
| Project Key | `COAWSPPR` (mismo proyecto que `TF_RCNCR_LINEA_WS5_INFRA`) |
| App type | AWS |
| AppID (Sonar y Checkmarx) | 29197 |

## Reglas de nombre aplicadas

- Mayusculas, sin vocales salvo la que inicia una palabra, palabras separadas por `_`.
- Prefijo AWS: `A_`.
- Raiz comun `RCNCR_LN` (Reconocer Linea). El repo de IaC existente conserva
  `LINEA` con vocales; para los nuevos se aplica la regla estricta.

| Componente | Repo | Combinacion valida |
|---|---|---|
| RecLineaCloud | `A_RCNCR_LN_RCLNCLD` | AWS – LAMBDA-JAVA |
| Lambda Authorizer | `A_RCNCR_LN_ATHRZR` | AWS – LAMBDA-ZIP |
| Validation | `A_RCNCR_LN_VLDTN` | AWS – LAMBDA-ZIP |
| RecMas_Transform_and_Upload | `A_RCNCR_LN_RCMS_TRNSFRM` | AWS – GLUE-PYTHON |

LAMBDA-ZIP es la combinacion valida para Lambdas Python (no existe LAMBDA-PYTHON).

---

## Ticket 1 — RecLineaCloud

```
Buenos dias, solicito la creacion del siguiente repositorio en Bitbucket:

Country: Colombia
ProjectKey: COAWSPPR
Tecnologia: AWS
Lenguaje: LAMBDA-JAVA
Nombre Repositorio: A_RCNCR_LN_RCLNCLD

Adicional aplicaciones: Sonar y Checkmarx con AppID 29197.

Contexto: codigo de la Lambda RecLineaCloud (Java 21) del stack Reconocer
Master Linea (SLCOPRBA-1437). La infraestructura ya esta desplegada por
COAWSPPR/TF_RCNCR_LINEA_WS5_INFRA en la cuenta 647096294147; este repo solo
publica el codigo en la funcion dev-647096294147-rcncr-ws5-reclineacloud-lambda.

Gracias
```

## Ticket 2 — Lambda Authorizer

```
Buenos dias, solicito la creacion del siguiente repositorio en Bitbucket:

Country: Colombia
ProjectKey: COAWSPPR
Tecnologia: AWS
Lenguaje: LAMBDA-ZIP
Nombre Repositorio: A_RCNCR_LN_ATHRZR

Adicional aplicaciones: Sonar y Checkmarx con AppID 29197.

Contexto: codigo Python 3.13 de la Lambda Authorizer (Okta) del API Reconocer
Master Linea (SLCOPRBA-1437). La infraestructura ya esta desplegada por
COAWSPPR/TF_RCNCR_LINEA_WS5_INFRA en la cuenta 647096294147; este repo solo
publica el codigo en la funcion dev-647096294147-rcncr-ws5-authorizer-lambda.

Gracias
```

## Ticket 3 — Validation

```
Buenos dias, solicito la creacion del siguiente repositorio en Bitbucket:

Country: Colombia
ProjectKey: COAWSPPR
Tecnologia: AWS
Lenguaje: LAMBDA-ZIP
Nombre Repositorio: A_RCNCR_LN_VLDTN

Adicional aplicaciones: Sonar y Checkmarx con AppID 29197.

Contexto: codigo Python 3.13 de la Lambda Validation del flujo Update RecMaster
(SLCOPRBA-1437). La infraestructura ya esta desplegada por
COAWSPPR/TF_RCNCR_LINEA_WS5_INFRA en la cuenta 647096294147; este repo solo
publica el codigo en la funcion dev-647096294147-rcncr-ws5-validation-lambda.

Gracias
```

## Ticket 4 — Glue RecMas_Transform_and_Upload

```
Buenos dias, solicito la creacion del siguiente repositorio en Bitbucket:

Country: Colombia
ProjectKey: COAWSPPR
Tecnologia: AWS
Lenguaje: GLUE-PYTHON
Nombre Repositorio: A_RCNCR_LN_RCMS_TRNSFRM

Adicional aplicaciones: Sonar y Checkmarx con AppID 29197.

Contexto: script PySpark del Glue Job RecMas_Transform_and_Upload del flujo
Update RecMaster (SLCOPRBA-1437). El job ya esta desplegado por
COAWSPPR/TF_RCNCR_LINEA_WS5_INFRA en la cuenta 647096294147
(dev-647096294147-rcncr-ws5-recmas-transform-upload); este repo publica el
script en s3://dev-647096294147-rcncr-ws5-upload-staging-s3/glue-scripts/.

Gracias
```

---

## Seguimiento

Al radicar, anotar el numero de ticket en la columna **Ticket** de
`INVENTARIO-IAC-Y-REPOS.md` (seccion 1).
