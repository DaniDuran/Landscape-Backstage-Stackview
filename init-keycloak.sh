#!/bin/bash

set -euo pipefail

KEYCLOAK=/opt/keycloak/bin/kcadm.sh
KEYCLOAK_SERVER="${KEYCLOAK_SERVER:-http://localhost:8080}"
KEYCLOAK_REALM="${KEYCLOAK_REALM:-Thomas}"
KEYCLOAK_CLIENT_ID="${KEYCLOAK_CLIENT_ID:-MTI}"
KEYCLOAK_CLIENT_SECRET="${KEYCLOAK_CLIENT_SECRET:-stackview-client-secret}"
KEYCLOAK_REDIRECT_URI="${KEYCLOAK_REDIRECT_URI:-http://localhost:7007/api/auth/oidc/handler/frame}"
KEYCLOAK_WEB_ORIGIN="${KEYCLOAK_WEB_ORIGIN:-http://localhost:7007}"
KEYCLOAK_ADMIN_USER="${KEYCLOAK_ADMIN_USER:-admin}"
KEYCLOAK_ADMIN_PASSWORD="${KEYCLOAK_ADMIN_PASSWORD:-admin123}"

STACKVIEWER_USER="${STACKVIEWER_USER:-stackviewer}"
STACKVIEWER_PASSWORD="${STACKVIEWER_PASSWORD:-stackviewer123}"
STACKVIEWER_EMAIL="${STACKVIEWER_EMAIL:-stackviewer@local.dev}"
STACKVIEWER_FIRST_NAME="${STACKVIEWER_FIRST_NAME:-Stack}"
STACKVIEWER_LAST_NAME="${STACKVIEWER_LAST_NAME:-Viewer}"

get_single_id_by_name() {
  local cmd="$1"
  local expected_name="$2"
  local value
  value=$(
    $cmd --fields id,name --format csv | while IFS= read -r line; do
      [ -z "$line" ] && continue
      id=""
      name=""
      id=${line%%,*}
      name=${line#*,}
      id=${id//\"/}
      name=${name//\"/}
      name=${name//$'\r'/}
      if [ "$name" = "$expected_name" ]; then
        echo "$id"
        break
      fi
    done
  )
  echo "$value"
}

echo "Login as Keycloak admin"
$KEYCLOAK config credentials \
  --server "$KEYCLOAK_SERVER" \
  --realm master \
  --user "$KEYCLOAK_ADMIN_USER" \
  --password "$KEYCLOAK_ADMIN_PASSWORD"

echo "Ensure realm '$KEYCLOAK_REALM' exists"
if ! $KEYCLOAK get "realms/$KEYCLOAK_REALM" >/dev/null 2>&1; then
  $KEYCLOAK create realms -s realm="$KEYCLOAK_REALM" -s enabled=true >/dev/null
fi

echo "Ensure OIDC client '$KEYCLOAK_CLIENT_ID' exists and is aligned"
CLIENT_UUID=$($KEYCLOAK get clients -r "$KEYCLOAK_REALM" -q clientId="$KEYCLOAK_CLIENT_ID" --fields id --format csv | tail -n1 | tr -d '\r"')
if [ -z "$CLIENT_UUID" ]; then
  $KEYCLOAK create clients -r "$KEYCLOAK_REALM" \
    -s clientId="$KEYCLOAK_CLIENT_ID" \
    -s enabled=true \
    -s protocol=openid-connect \
    -s publicClient=false \
    -s clientAuthenticatorType=client-secret \
    -s secret="$KEYCLOAK_CLIENT_SECRET" \
    -s standardFlowEnabled=true \
    -s directAccessGrantsEnabled=true \
    -s "redirectUris=[\"$KEYCLOAK_REDIRECT_URI\"]" \
    -s "webOrigins=[\"$KEYCLOAK_WEB_ORIGIN\"]" \
    -s "attributes.\"post.logout.redirect.uris\"=$KEYCLOAK_WEB_ORIGIN/*" >/dev/null
  CLIENT_UUID=$($KEYCLOAK get clients -r "$KEYCLOAK_REALM" -q clientId="$KEYCLOAK_CLIENT_ID" --fields id --format csv | tail -n1 | tr -d '\r"')
else
  $KEYCLOAK update "clients/$CLIENT_UUID" -r "$KEYCLOAK_REALM" \
    -s enabled=true \
    -s publicClient=false \
    -s clientAuthenticatorType=client-secret \
    -s secret="$KEYCLOAK_CLIENT_SECRET" \
    -s standardFlowEnabled=true \
    -s directAccessGrantsEnabled=true \
    -s "redirectUris=[\"$KEYCLOAK_REDIRECT_URI\"]" \
    -s "webOrigins=[\"$KEYCLOAK_WEB_ORIGIN\"]" \
    -s "attributes.\"post.logout.redirect.uris\"=$KEYCLOAK_WEB_ORIGIN/*" >/dev/null
fi

echo "Ensure groups mapper exists on client '$KEYCLOAK_CLIENT_ID'"
GROUPS_MAPPER_ID=$(
  get_single_id_by_name \
    "$KEYCLOAK get clients/$CLIENT_UUID/protocol-mappers/models -r $KEYCLOAK_REALM" \
    "groups"
)
if [ -z "$GROUPS_MAPPER_ID" ]; then
  $KEYCLOAK create "clients/$CLIENT_UUID/protocol-mappers/models" -r "$KEYCLOAK_REALM" \
    -s name=groups \
    -s protocol=openid-connect \
    -s protocolMapper=oidc-group-membership-mapper \
    -s 'config."claim.name"=groups' \
    -s 'config."full.path"=false' \
    -s 'config."access.token.claim"=true' \
    -s 'config."id.token.claim"=true' \
    -s 'config."userinfo.token.claim"=true' \
    -s 'config."multivalued"=true' >/dev/null
fi

ensure_group() {
  local group_name="$1"
  local group_id
  group_id=$(get_single_id_by_name "$KEYCLOAK get groups -r $KEYCLOAK_REALM -q search=$group_name" "$group_name")
  if [ -z "$group_id" ]; then
    $KEYCLOAK create groups -r "$KEYCLOAK_REALM" -s name="$group_name" >/dev/null
    group_id=$(get_single_id_by_name "$KEYCLOAK get groups -r $KEYCLOAK_REALM -q search=$group_name" "$group_name")
  fi
  echo "$group_id"
}

echo "Ensure groups 'editors' and 'viewers' exist"
EDITORS_GROUP_ID=$(ensure_group editors)
VIEWERS_GROUP_ID=$(ensure_group viewers)

echo "Ensure user '$STACKVIEWER_USER' exists"
STACKVIEWER_ID=$($KEYCLOAK get users -r "$KEYCLOAK_REALM" -q username="$STACKVIEWER_USER" --fields id --format csv | tail -n1 | tr -d '\r"')
if [ -z "$STACKVIEWER_ID" ]; then
  $KEYCLOAK create users -r "$KEYCLOAK_REALM" \
    -s username="$STACKVIEWER_USER" \
    -s enabled=true \
    -s email="$STACKVIEWER_EMAIL" \
    -s emailVerified=true \
    -s firstName="$STACKVIEWER_FIRST_NAME" \
    -s lastName="$STACKVIEWER_LAST_NAME" >/dev/null
  STACKVIEWER_ID=$($KEYCLOAK get users -r "$KEYCLOAK_REALM" -q username="$STACKVIEWER_USER" --fields id --format csv | tail -n1 | tr -d '\r"')
fi

echo "Set password for '$STACKVIEWER_USER'"
$KEYCLOAK set-password -r "$KEYCLOAK_REALM" --username "$STACKVIEWER_USER" --new-password "$STACKVIEWER_PASSWORD" >/dev/null

ensure_user_in_group() {
  local user_id="$1"
  local group_id="$2"
  local group_name="$3"
  local current
  current=$(get_single_id_by_name "$KEYCLOAK get users/$user_id/groups -r $KEYCLOAK_REALM" "$group_name")
  if [ -z "$current" ]; then
    $KEYCLOAK update "users/$user_id/groups/$group_id" -r "$KEYCLOAK_REALM" -n >/dev/null
  fi
}

echo "Ensure '$STACKVIEWER_USER' is member of editors/viewers"
ensure_user_in_group "$STACKVIEWER_ID" "$EDITORS_GROUP_ID" editors
ensure_user_in_group "$STACKVIEWER_ID" "$VIEWERS_GROUP_ID" viewers

echo "Keycloak bootstrap completed successfully"
