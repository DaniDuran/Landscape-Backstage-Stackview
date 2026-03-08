# Landscape-Backstage-Stackview

Repositorio para ejecutar Backstage en Docker con autenticación OIDC usando un Keycloak propio incluido en el mismo docker-compose. 
Este proyecto Permite desplegar un Software Catalog corporativo con registro de frontend, backend, APIs, librerías y microservicios entre otros componentes.

## 1) Objetivo

Levantar un catalogo de arquitectura/software para registrar y relacionar:

- Proyectos (`System`)
- Microservicios/frontends/herramientas (`Component`)
- APIs (`API`)
- Librerias (`Component` tipo `library`)

## 2) Arquitectura del stack

El `docker-compose.yml` levanta estos servicios:

- `postgres`: base de datos de Backstage
- `keycloak-postgres`: base de datos de Keycloak
- `keycloak`: Identity Provider OIDC
- `backstage`: aplicacion principal

Puertos por defecto:

- Backstage: `http://localhost:7007`
- Keycloak: `http://localhost:8080`

## 3) Requisitos

- Docker Desktop con `docker compose`
- Git
- Opcional: Node.js 20+ (si quieres ejecutar Backstage fuera de Docker)

## 4) Estructura relevante

- `docker-compose.yml`: orquestacion de servicios
- `Dockerfile`: build de Backstage
- `.env.example`: variables de entorno base
- `stackview/app-config.production.yaml`: configuracion OIDC/DB en produccion
- `stackview/examples/org.yaml`: usuarios y grupos ejemplo
- `stackview/examples/entities.yaml`: sistemas/componentes/librerias ejemplo

## 5) Configuracion inicial

1. Copia variables de entorno:

```powershell
Copy-Item .env.example .env
```

2. Ajusta secretos obligatorios en `.env`:

- `BACKEND_SECRET`
- `AUTH_SESSION_SECRET`
- `KEYCLOAK_ADMIN_PASSWORD`
- `KEYCLOAK_CLIENT_SECRET`
- `KEYCLOAK_DB_PASSWORD`
- `OIDC_CLIENT_SECRET`
- `GITHUB_TOKEN` (si usaras integracion GitHub)

3. Asegura consistencia entre `.env` y Keycloak:

- `OIDC_CLIENT_ID` debe coincidir con `KEYCLOAK_CLIENT_ID`
- `OIDC_CLIENT_SECRET` debe coincidir con el secret del cliente en Keycloak
- `OIDC_METADATA_URL` debe apuntar al realm correcto

## 6) Levantar ambiente y configurar OIDC

### 6.1 Levantar contenedores

```bash
docker compose up -d --build
docker compose ps
```

Opcional (logs):

```bash
docker compose logs -f backstage
docker compose logs -f keycloak
```

### 6.2 Login administrativo por CLI en Keycloak

```bash
docker exec backstage-keycloak /opt/keycloak/bin/kcadm.sh config credentials --server http://localhost:8080 --realm master --user admin --password <KEYCLOAK_ADMIN_PASSWORD>
```

Si usas valores por defecto de ejemplo:

```bash
docker exec backstage-keycloak /opt/keycloak/bin/kcadm.sh config credentials --server http://localhost:8080 --realm master --user admin --password admin123
```

### 6.3 Crear y validar cliente OIDC (`MTI`) - Detallado

1. Crea el realm (si no existe):

```bash
docker exec backstage-keycloak /opt/keycloak/bin/kcadm.sh create realms -s realm=Thomas -s enabled=true
```

2. Verifica/ajusta el archivo `keycloak-client.json` en la raiz del repo:

```json
{
  "clientId": "MTI",
  "enabled": true,
  "protocol": "openid-connect",
  "publicClient": false,
  "secret": "stackview-client-secret",
  "standardFlowEnabled": true,
  "directAccessGrantsEnabled": true,
  "redirectUris": ["http://localhost:7007/api/auth/oidc/handler/frame"],
  "webOrigins": ["http://localhost:7007"],
  "attributes": {
    "post.logout.redirect.uris": "http://localhost:7007/*"
  }
}
```

3. Copia el archivo al contenedor:

```bash
docker cp keycloak-client.json backstage-keycloak:/tmp/keycloak-client.json
```

4. Autenticarse 
```bash
docker exec -it backstage-keycloak /opt/keycloak/bin/kcadm.sh config credentials --server http://localhost:8080 --realm master --user admin --password admin123
```
5. Crea el cliente en el realm:

```bash
docker exec backstage-keycloak /opt/keycloak/bin/kcadm.sh create clients -r Thomas -f /tmp/keycloak-client.json
```

5. Valida que el cliente exista:

```bash
docker exec backstage-keycloak /opt/keycloak/bin/kcadm.sh get clients -r Thomas -q clientId=MTI
```

6. Valida el endpoint OIDC discovery del realm:

```bash
curl http://localhost:8080/realms/Thomas/.well-known/openid-configuration
```

7. Verifica coherencia final:

- `clientId` en Keycloak = `OIDC_CLIENT_ID` en `.env`
- `secret` en Keycloak = `OIDC_CLIENT_SECRET` en `.env`
- `redirectUris` incluye `http://localhost:7007/api/auth/oidc/handler/frame`
- `webOrigins` incluye `http://localhost:7007`

### 6.4 Crear usuario de prueba

```bash
docker exec backstage-keycloak /opt/keycloak/bin/kcadm.sh create users -r Thomas -s username=stackviewer -s enabled=true -s email=stackviewer@local.dev -s emailVerified=true -s firstName=Stack -s lastName=Viewer
docker exec backstage-keycloak /opt/keycloak/bin/kcadm.sh set-password -r Thomas --username stackviewer --new-password stackviewer123 --temporary=false
```

### 6.5 Probar login en Backstage

1. Abre `http://localhost:7007`
2. Pulsa `Sign in with your Keycloak account`
3. Ingresa:
   - Usuario: `stackviewer`
   - Password: `stackviewer123`

Chequeo tecnico:

```bash
curl -I "http://localhost:7007/api/auth/oidc/start?env=production&origin=http://localhost:7007"
```

Debe responder `302`.

## 7) Crear proyectos, APIs, librerias e interconectarlos

### 7.1 Define equipos duenos (owners)

Edita `stackview/examples/org.yaml` para crear grupos:

```yaml
apiVersion: backstage.io/v1alpha1
kind: Group
metadata:
  name: team-plataforma
spec:
  type: team
  children: []
```

### 7.2 Registra entidades de catalogo

Edita `stackview/examples/entities.yaml` agregando entidades con relaciones.

Ejemplo completo:

```yaml
---
apiVersion: backstage.io/v1alpha1
kind: System
metadata:
  name: cartera-digital
  description: Dominio principal de pagos y cartera
spec:
  owner: group:default/team-plataforma
---
apiVersion: backstage.io/v1alpha1
kind: API
metadata:
  name: orders-api
  description: API publica de ordenes
spec:
  type: openapi
  lifecycle: production
  owner: group:default/team-plataforma
  system: system:default/cartera-digital
  definition: |
    openapi: 3.0.3
    info:
      title: Orders API
      version: 1.0.0
    paths:
      /orders:
        get:
          responses:
            "200":
              description: OK
---
apiVersion: backstage.io/v1alpha1
kind: Component
metadata:
  name: ms-orders
spec:
  type: service
  lifecycle: production
  owner: group:default/team-plataforma
  system: system:default/cartera-digital
  providesApis:
    - api:default/orders-api
  dependsOn:
    - component:default/lb-auth
---
apiVersion: backstage.io/v1alpha1
kind: Component
metadata:
  name: lb-auth
spec:
  type: library
  lifecycle: production
  owner: group:default/team-plataforma
  system: system:default/cartera-digital
  subcomponentOf: component:default/ms-orders
---
apiVersion: backstage.io/v1alpha1
kind: Component
metadata:
  name: web-checkout
spec:
  type: website
  lifecycle: production
  owner: group:default/team-plataforma
  system: system:default/cartera-digital
  consumesApis:
    - api:default/orders-api
```

### 7.3 Relaciones recomendadas

Usa estos campos para interconectar:

- `system`: agrupa componentes/APIs por proyecto
- `owner`: asigna responsable (grupo/usuario)
- `providesApis`: un servicio expone APIs
- `consumesApis`: un frontend u otro servicio consume APIs
- `dependsOn`: dependencia tecnica entre componentes
- `subcomponentOf`: libreria/modulo parte de otro componente

### 7.4 Refrescar catalogo

Despues de editar archivos locales:

```bash
docker compose restart backstage
```

En UI:

1. Ir a `Catalog`
2. Abrir una entidad
3. Revisar `Relations` para confirmar enlaces

## 8) Comandos utiles

```bash
docker compose ps
docker compose logs -f backstage
docker compose logs -f keycloak
docker compose restart backstage
docker compose down
docker compose down -v
```

## 9) Troubleshooting

- Error `Authentication failed, authentication requires session support`:
  - Verifica `AUTH_SESSION_SECRET` en `.env`
  - Verifica `auth.session.secret` en `stackview/app-config.production.yaml`
  - Reconstruye backend: `docker compose up -d --build backstage`

- Error OIDC `ECONNREFUSED`:
  - Verifica `OIDC_METADATA_URL`
  - Verifica que `keycloak` este `Up` en `docker compose ps`

- Error DNS con host `keycloak` desde navegador:
  - `keycloak` solo existe dentro de la red Docker
  - Para navegador local usa `localhost` o `host.docker.internal`

## 10) Seguridad para entornos reales

- Cambia todos los secretos por valores robustos
- No uses `start-dev` de Keycloak en produccion real
- Implementa backup para volumenes `postgres_data` y `keycloak_postgres_data`
