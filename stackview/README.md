# [Backstage](https://backstage.io)

This is your newly scaffolded Backstage App, Good Luck!

To start the app, run:

```sh
yarn install
yarn start
```

## OIDC auth startup (503)

If login fails with:

`ServiceUnavailableError: Service has not started up yet`

diagnose and stabilize with:

```bash
docker compose ps
docker compose logs --tail=200 backstage
```

When the log contains:

`Failed to initialize oidc auth provider, Sign-in resolver 'preferredUsernameMatchingUserEntityName' is not available`

use only supported resolvers in `stackview/app-config.production.yaml`:

```yaml
auth:
  providers:
    oidc:
      production:
        signIn:
          resolvers:
            - resolver: emailLocalPartMatchingUserEntityName
              dangerouslyAllowSignInWithoutUserInCatalog: true
            - resolver: emailMatchingUserEntityProfileEmail
              dangerouslyAllowSignInWithoutUserInCatalog: true
```

Then rebuild backend image (config is baked into image):

```bash
docker compose up -d --build backstage
```

Validation:

```bash
curl -I "http://localhost:7007/api/auth/oidc/start?scope=openid%20profile%20email&origin=http%3A%2F%2Flocalhost%3A7007&flow=popup&env=production"
```

Expected result: HTTP `302`.

## Catalogo desde `../catalog` y edicion con `stackviewer`

Se dejo Backstage leyendo entidades desde la carpeta raiz del repositorio:

- `catalog/organization/*.yaml`
- `catalog/domains/*.yaml`
- `catalog/systems/*.yaml`
- `catalog/tools/*.yaml`
- `catalog/libraries/*.yaml`
- `catalog/services/*.yaml`

Para que el contenedor backend lea ese catalogo se usa:

- `docker-compose.yml` con volumen `./catalog:/app/catalog`
- `Dockerfile` con `COPY catalog/ ./catalog/`

### Levantar y estabilizar ambiente

Desde la raiz del repo:

```bash
docker compose up -d --build
docker cp init-keycloak.sh backstage-keycloak:/tmp/init-keycloak.sh
docker exec backstage-keycloak sh /tmp/init-keycloak.sh
docker compose restart backstage
```

Validar arranque del backend:

```bash
docker compose logs --tail=200 backstage
```

Debe aparecer `Plugin initialization complete`.

Validar autenticacion OIDC:

```bash
curl -I "http://localhost:7007/api/auth/oidc/start?scope=openid%20profile%20email&origin=http%3A%2F%2Flocalhost%3A7007&flow=popup&env=production"
```

Resultado esperado:

- `HTTP/1.1 302 Found`
- Header `Location` apuntando a `http://localhost:8080/realms/Thomas/...`

### Usuario para editar catalogo desde web

El bootstrap de Keycloak crea/alinea:

- Realm: `Thomas`
- Cliente OIDC: `MTI`
- Usuario: `stackviewer`
- Grupos: `editors`, `viewers`

Credenciales por defecto:

- Usuario: `stackviewer`
- Password: `stackviewer123`

Flujo web:

1. Ingresar a `http://localhost:7007`
2. Iniciar sesion con `stackviewer`
3. Abrir `http://localhost:7007/catalog-import` para registrar/editar ubicaciones del catalogo desde la UI
