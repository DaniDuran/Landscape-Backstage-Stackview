# Landscape-Backstage-Stackview
Este repositorio levanta Backstage en Docker con autenticación OIDC usando un Keycloak propio incluido en el mismo docker-compose. Permite desplegar un Software Catalog corporativo con registro de frontend, backend, APIs, librerías y microservicios entre otros componentes.

## 1) Requisitos

- Docker Desktop (con `docker compose`)
- Git
- (Opcional) Node.js 20+ si quieres crear/regenerar el proyecto Backstage fuera de Docker

## 2) Descarga del proyecto

```bash
git clone <tu-repo>
cd Backstage
```

Si necesitas crear el proyecto Backstage desde cero (carpeta `stackview`):

```bash
npx @backstage/create-app@latest --path stackview
```

## 3) Imagenes y servicios Docker

`docker-compose.yml` levanta 4 servicios:

- `postgres`: base de datos de Backstage
- `keycloak-postgres`: base de datos de Keycloak
- `keycloak`: servidor de identidad OIDC
- `backstage`: aplicacion Backstage (modo `production`)

## 4) Configuracion por variables (`.env`)

Copiar el ejemplo y ajustar secretos:

```bash
cp .env.example .env
```

Variables clave:

- Backstage:
  - `BACKSTAGE_PORT=7007`
  - `BACKEND_SECRET=...`
  - `AUTH_SESSION_SECRET=...` (obligatoria para OIDC)
- Postgres Backstage:
  - `POSTGRES_*`
- Keycloak:
  - `KEYCLOAK_ADMIN`, `KEYCLOAK_ADMIN_PASSWORD`
  - `KEYCLOAK_REALM=Thomas`
  - `KEYCLOAK_CLIENT_ID=MTI`
  - `KEYCLOAK_CLIENT_SECRET=stackview-client-secret`
- OIDC en Backstage:
  - `OIDC_CLIENT_ID=MTI`
  - `OIDC_CLIENT_SECRET=stackview-client-secret`
  - `OIDC_METADATA_URL=http://host.docker.internal:8080/realms/Thomas/.well-known/openid-configuration`
  - `OIDC_CALLBACK_URL=http://localhost:7007/api/auth/oidc/handler/frame`

## 5) Levantar la plataforma

```bash
docker compose up -d --build
```

Accesos:

- Backstage: http://localhost:7007
- Keycloak: http://localhost:8080

## 6) Crear reino, cliente y usuario en Keycloak (por consola)

### 6.1 Login administrativo en Keycloak CLI

```bash
docker exec backstage-keycloak /opt/keycloak/bin/kcadm.sh config credentials --server http://localhost:8080 --realm master --user admin --password admin123
```

### 6.2 Crear reino `Thomas`

```bash
docker exec backstage-keycloak /opt/keycloak/bin/kcadm.sh create realms -s realm=Thomas -s enabled=true
```

### 6.3 Crear cliente OIDC `MTI`

Crear archivo temporal `keycloak-client.json`:

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

Aplicar en Keycloak:

```bash
docker cp keycloak-client.json backstage-keycloak:/tmp/keycloak-client.json
docker exec backstage-keycloak /opt/keycloak/bin/kcadm.sh create clients -r Thomas -f /tmp/keycloak-client.json
rm keycloak-client.json
```

### 6.4 Crear usuario `stackviewer`

```bash
docker exec backstage-keycloak /opt/keycloak/bin/kcadm.sh create users -r Thomas -s username=stackviewer -s enabled=true -s email=stackviewer@local.dev -s emailVerified=true -s firstName=Stack -s lastName=Viewer
docker exec backstage-keycloak /opt/keycloak/bin/kcadm.sh set-password -r Thomas --username stackviewer --new-password stackview123 --temporary=false
```

## 7) Integracion Backstage-Keycloak

La integracion OIDC queda activa en `stackview/app-config.production.yaml` con:

- `auth.session.secret: ${AUTH_SESSION_SECRET}`
- `auth.providers.oidc.production.*`
- resolvers de login por email

La UI de Backstage usa el proveedor `oidc` (Keycloak) en la pantalla de login.

## 8) Verificacion rapida

1. Abre http://localhost:7007
2. Selecciona "Sign in with your Keycloak account"
3. Ingresa:
   - Usuario: `stackviewer`
   - Password: `stackview123`

Validacion tecnica (backend):

```bash
curl -I "http://localhost:7007/api/auth/oidc/start?env=production&origin=http://localhost:7007"
```

Debe responder `302` (redireccion a Keycloak).

## 9) Comandos utiles

```bash
docker compose ps
docker compose logs -f backstage
docker compose logs -f keycloak
docker compose down
docker compose down -v
```

## 10) Troubleshooting

- Error `Authentication failed, authentication requires session support`:
  - Verifica `AUTH_SESSION_SECRET` en `.env`
  - Verifica `auth.session.secret` en `stackview/app-config.production.yaml`
  - Rebuild: `docker compose up -d --build backstage`

- Error de conexion OIDC (`ECONNREFUSED`):
  - Verifica `OIDC_METADATA_URL` (para navegador local usar `host.docker.internal`)
  - Verifica que `keycloak` este `Up` en `docker compose ps`

- Error `DNS_PROBE_FINISHED_NXDOMAIN` con host `keycloak`:
  - No uses `keycloak` en URLs del navegador, ese host solo existe dentro de Docker.
  - Usa `OIDC_METADATA_URL=http://host.docker.internal:8080/realms/Thomas/.well-known/openid-configuration`.

## 11) Recomendaciones para produccion

- Cambiar todos los secretos por valores fuertes.
- No usar `start-dev` de Keycloak en ambientes productivos reales.
- Agregar backup de volumenes de Postgres (`postgres_data`).


# Backstage Setup con Docker

Guía paso a paso para crear y ejecutar **Backstage** usando **Docker** y **PostgreSQL**.

---

# 1. Prerequisitos

Instalar las siguientes herramientas:

* **Node.js** (versión 18 o superior)
* **Yarn**
* **Docker**

Verificar instalación:

```bash
node -v
yarn -v
docker -v
```

---

# 2. Crear el proyecto Backstage

Ubicarse en el directorio de trabajo:

```bash
cd C:\WorkSpace\Arquitectura
```

Crear el proyecto:

```bash
npx @backstage/create-app@latest
```

Responder al prompt:

```
app name? backstage
```

Se generará la estructura del proyecto:

```
backstage
│
├── app-config.yaml
├── package.json
├── yarn.lock
├── packages
│   ├── app
│   └── backend
└── plugins
```

---

# 3. Probar Backstage localmente

Entrar al proyecto:

```bash
cd backstage
```

Instalar dependencias:

```bash
yarn install
```

Ejecutar en modo desarrollo:

```bash
yarn dev
```

Abrir en navegador:

```
http://localhost:3000
```

Si aparece la interfaz de Backstage, la instalación es correcta.

---

# 4. Crear Dockerfile

En la raíz del proyecto crear el archivo:

```
Dockerfile
```

Contenido:

```dockerfile
FROM node:18-bullseye-slim

WORKDIR /app

COPY package.json yarn.lock ./

RUN yarn install --frozen-lockfile

COPY . .

RUN yarn build

ENV NODE_ENV=production

EXPOSE 7007

CMD ["yarn", "start"]
```

---

# 5. Crear docker-compose

Crear archivo:

```
docker-compose.yml
```

Contenido:

```yaml
version: "3.8"

services:

  postgres:
    image: postgres:17
    environment:
      POSTGRES_USER: backstage
      POSTGRES_PASSWORD: backstage
      POSTGRES_DB: backstage
    ports:
      - "5432:5432"

  backstage:
    build: .
    ports:
      - "7007:7007"
    depends_on:
      - postgres
    environment:
      POSTGRES_HOST: postgres
      POSTGRES_PORT: 5432
      POSTGRES_USER: backstage
      POSTGRES_PASSWORD: backstage
      POSTGRES_DB: backstage
```

---

# 6. Configurar conexión a base de datos

Editar el archivo:

```
app-config.yaml
```

Agregar configuración:

```yaml
backend:
  database:
    client: pg
    connection:
      host: ${POSTGRES_HOST}
      port: ${POSTGRES_PORT}
      user: ${POSTGRES_USER}
      password: ${POSTGRES_PASSWORD}
      database: ${POSTGRES_DB}
```

---

# 7. Construir contenedores

Desde la raíz del proyecto ejecutar:

```bash
docker compose build
```

---

# 8. Ejecutar la aplicación

```bash
docker compose up
```

---

# 9. Acceder a Backstage

Abrir en navegador:

```
http://localhost:7007
```

---

# 10. Verificar contenedores en ejecución

```bash
docker ps
```

Deberían aparecer:

```
backstage
postgres
```

---

# Arquitectura resultante

```
Docker
   │
   ├── Backstage
   │      └── Software Catalog
   │
   └── PostgreSQL
```

Este entorno permite registrar:

* Frontend
* Backend
* APIs
* Librerías
* Microservicios
* Dependencias
* Equipos responsables
* Documentación técnica

---

