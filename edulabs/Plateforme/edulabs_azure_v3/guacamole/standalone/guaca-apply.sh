#!/usr/bin/env bash
# Usage: ./guac_apply.sh guacamole.yaml

GUAC_HOST="http://192.168.10.8:8080/guacamole"
ADMIN_USER="adminsql"
ADMIN_PASS="adminpasssql"

YAML_FILE="$1"

if [[ -z "$YAML_FILE" ]]; then
  echo "Usage: $0 guacamole.yaml"
  exit 1
fi

# Obtenir un token
TOKEN=$(curl -s -X POST "$GUAC_HOST/api/tokens" \
  -d "username=$ADMIN_USER&password=$ADMIN_PASS" | jq -r .authToken)

if [[ "$TOKEN" == "null" ]]; then
  echo "❌ Erreur: impossible d'obtenir un token"
  exit 1
fi

# Nombre d’utilisateurs dans le YAML
USER_COUNT=$(yq '.users | length' "$YAML_FILE")

for i in $(seq 0 $((USER_COUNT - 1))); do
  user_json=$(yq -o=json ".users[$i]" "$YAML_FILE")
  USERNAME=$(echo "$user_json" | jq -r .username)
  PASSWORD=$(echo "$user_json" | jq -r .password)

  echo "➡️ Création utilisateur $USERNAME"

  curl -s -X POST "$GUAC_HOST/api/session/data/mysql/users?token=$TOKEN" \
    -H "Content-Type: application/json" \
    -d "{\"username\":\"$USERNAME\",\"password\":\"$PASSWORD\",\"attributes\":{}}" >/dev/null

  # Nombre de connexions pour cet utilisateur
  CONN_COUNT=$(echo "$user_json" | jq '.connections | length')

  for j in $(seq 0 $((CONN_COUNT - 1))); do
    conn_json=$(echo "$user_json" | jq -c ".connections[$j]")
    CONN_NAME=$(echo "$conn_json" | jq -r .name)

    echo "   ➡️ Création connexion $CONN_NAME"

    RESP=$(echo "$conn_json" | curl -s -X POST "$GUAC_HOST/api/session/data/mysql/connections?token=$TOKEN" \
      -H "Content-Type: application/json" -d @-)

    CONN_ID=$(echo "$RESP" | jq -r .identifier)

    curl -s -X PATCH "$GUAC_HOST/api/session/data/mysql/users/$USERNAME/permissions?token=$TOKEN" \
      -H "Content-Type: application/json" \
      -d "[{\"op\":\"add\",\"path\":\"/connectionPermissions/$CONN_ID\",\"value\":\"READ\"}]" >/dev/null

    echo "   ✅ Connexion $CONN_NAME liée à $USERNAME"
  done
done