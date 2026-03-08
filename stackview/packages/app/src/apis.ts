import {
  ScmIntegrationsApi,
  scmIntegrationsApiRef,
  ScmAuth,
} from '@backstage/integration-react';
import { OAuth2 } from '@backstage/core-app-api';
import {
  AnyApiFactory,
  BackstageIdentityApi,
  configApiRef,
  createApiFactory,
  createApiRef,
  discoveryApiRef,
  oauthRequestApiRef,
  OpenIdConnectApi,
  ProfileInfoApi,
  SessionApi,
} from '@backstage/core-plugin-api';

export const oidcAuthApiRef = createApiRef<
  OpenIdConnectApi & ProfileInfoApi & BackstageIdentityApi & SessionApi
>({
  id: 'auth.oidc',
});

const oidcProvider = {
  id: 'oidc',
  title: 'Keycloak',
  message: 'Sign in using Keycloak',
  icon: (_: { fontSize?: 'medium' | 'large' | 'small' | 'inherit' }) => null,
};

export const apis: AnyApiFactory[] = [
  createApiFactory({
    api: scmIntegrationsApiRef,
    deps: { configApi: configApiRef },
    factory: ({ configApi }) => ScmIntegrationsApi.fromConfig(configApi),
  }),
  createApiFactory({
    api: oidcAuthApiRef,
    deps: {
      discoveryApi: discoveryApiRef,
      oauthRequestApi: oauthRequestApiRef,
      configApi: configApiRef,
    },
    factory: ({ discoveryApi, oauthRequestApi, configApi }) =>
      OAuth2.create({
        discoveryApi,
        oauthRequestApi,
        configApi,
        environment: configApi.getOptionalString('auth.environment'),
        provider: oidcProvider,
        defaultScopes: ['openid', 'profile', 'email'],
      }),
  }),
  ScmAuth.createDefaultApiFactory(),
];
