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
