'use strict';

var crypto = require('node:crypto');
var openidClient = require('openid-client');
var pluginAuthNode = require('@backstage/plugin-auth-node');
var types = require('@backstage/types');
var config = require('@backstage/config');

function _interopDefaultCompat (e) { return e && typeof e === 'object' && 'default' in e ? e : { default: e }; }

var crypto__default = /*#__PURE__*/_interopDefaultCompat(crypto);

const HTTP_OPTION_TIMEOUT = 1e4;
const createHttpOptionsProvider = ({ timeout }) => (_url, options) => {
  return {
    ...options,
    timeout: timeout ?? HTTP_OPTION_TIMEOUT
  };
};
const oidcAuthenticator = pluginAuthNode.createOAuthAuthenticator({
  defaultProfileTransform: async (input) => ({
    profile: {
      email: input.fullProfile.userinfo.email,
      picture: input.fullProfile.userinfo.picture,
      displayName: input.fullProfile.userinfo.name
    }
  }),
  scopes: {
    persist: true,
    required: ["openid", "profile", "email"]
  },
  initialize({ callbackUrl, config: config$1 }) {
    const clientId = config$1.getString("clientId");
    const clientSecret = config$1.getString("clientSecret");
    const metadataUrl = config$1.getString("metadataUrl");
    const customCallbackUrl = config$1.getOptionalString("callbackUrl");
    const tokenEndpointAuthMethod = config$1.getOptionalString(
      "tokenEndpointAuthMethod"
    );
    const tokenSignedResponseAlg = config$1.getOptionalString(
      "tokenSignedResponseAlg"
    );
    const initializedPrompt = config$1.getOptionalString("prompt");
    const startUrlSearchParams = config$1.getOptional("startUrlSearchParams") || {};
    if (config$1.has("scope")) {
      throw new Error(
        'The oidc provider no longer supports the "scope" configuration option. Please use the "additionalScopes" option instead.'
      );
    }
    const timeoutMilliseconds = config$1.has("timeout") ? types.durationToMilliseconds(
      config.readDurationFromConfig(config$1, { key: "timeout" })
    ) : void 0;
    const httpOptionsProvider = createHttpOptionsProvider({
      timeout: timeoutMilliseconds
    });
    openidClient.Issuer[openidClient.custom.http_options] = httpOptionsProvider;
    const promise = openidClient.Issuer.discover(metadataUrl).then((issuer) => {
      issuer[openidClient.custom.http_options] = httpOptionsProvider;
      issuer.Client[openidClient.custom.http_options] = httpOptionsProvider;
      const client = new issuer.Client({
        access_type: "offline",
        // this option must be passed to provider to receive a refresh token
        client_id: clientId,
        client_secret: clientSecret,
        redirect_uris: [customCallbackUrl || callbackUrl],
        response_types: ["code"],
        token_endpoint_auth_method: tokenEndpointAuthMethod || "client_secret_basic",
        id_token_signed_response_alg: tokenSignedResponseAlg || "RS256"
      });
      client[openidClient.custom.http_options] = httpOptionsProvider;
      const strategy = new openidClient.Strategy(
        {
          client,
          passReqToCallback: false
        },
        (tokenset, userinfo, done) => {
          if (typeof done !== "function") {
            throw new Error(
              "OIDC IdP must provide a userinfo_endpoint in the metadata response"
            );
          }
          done(
            void 0,
            { tokenset, userinfo },
            { refreshToken: tokenset.refresh_token }
          );
        }
      );
      const helper = pluginAuthNode.PassportOAuthAuthenticatorHelper.from(strategy);
      return { helper, client, strategy };
    });
    return { initializedPrompt, promise, searchParams: startUrlSearchParams };
  },
  async start(input, ctx) {
    const { initializedPrompt, promise, searchParams } = ctx;
    const { helper } = await promise;
    const options = {
      ...searchParams,
      scope: input.scope,
      state: input.state,
      nonce: crypto__default.default.randomBytes(16).toString("base64")
    };
    const prompt = initializedPrompt || "none";
    if (prompt !== "auto") {
      options.prompt = prompt;
    }
    return helper.start(input, {
      ...options
    });
  },
  async authenticate(input, ctx) {
    const { strategy } = await ctx.promise;
    const { result, privateInfo } = await pluginAuthNode.PassportHelpers.executeFrameHandlerStrategy(input.req, strategy);
    return {
      fullProfile: result,
      session: {
        accessToken: result.tokenset.access_token,
        tokenType: result.tokenset.token_type ?? "bearer",
        scope: result.tokenset.scope,
        expiresInSeconds: result.tokenset.expires_in,
        idToken: result.tokenset.id_token,
        refreshToken: privateInfo.refreshToken
      }
    };
  },
  async refresh(input, ctx) {
    const { client } = await ctx.promise;
    const tokenset = await client.refresh(input.refreshToken);
    if (!tokenset.access_token) {
      throw new Error("Refresh failed");
    }
    const userinfo = await client.userinfo(tokenset.access_token);
    return new Promise((resolve, reject) => {
      if (!tokenset.access_token) {
        reject(new Error("Refresh Failed"));
      }
      resolve({
        fullProfile: { userinfo, tokenset },
        session: {
          accessToken: tokenset.access_token,
          tokenType: tokenset.token_type ?? "bearer",
          scope: tokenset.scope,
          expiresInSeconds: tokenset.expires_in,
          idToken: tokenset.id_token,
          refreshToken: tokenset.refresh_token
        }
      });
    });
  },
  async logout(input, ctx) {
    const { client } = await ctx.promise;
    const issuer = client.issuer;
    if (input.refreshToken && issuer.revocation_endpoint) {
      await client.revoke(input.refreshToken);
    }
  }
});

exports.oidcAuthenticator = oidcAuthenticator;
//# sourceMappingURL=authenticator.cjs.js.map
