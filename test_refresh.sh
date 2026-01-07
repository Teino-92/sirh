#!/bin/bash

echo "=== Step 1: Login pour obtenir un token ==="
response=$(curl -s -i -X POST http://localhost:3000/api/v1/login \
  -H "Content-Type: application/json" \
  -d '{"email": "admin@techcorp.fr", "password": "password123"}')

echo "$response" | head -20

echo ""
echo "=== Extraction du token ==="
token=$(echo "$response" | grep -i "^Authorization:" | sed 's/Authorization: Bearer //' | tr -d '\r\n ')
echo "Token (premier 50 chars): ${token:0:50}..."

echo ""
echo "=== Step 2: Test refresh endpoint ==="
refresh_response=$(curl -s -i -X POST http://localhost:3000/api/v1/refresh \
  -H "Authorization: Bearer $token" \
  -H "Content-Type: application/json")

echo "$refresh_response" | head -20

echo ""
echo "=== Extraction du nouveau token ==="
new_token=$(echo "$refresh_response" | grep -i "^Authorization:" | sed 's/Authorization: Bearer //' | tr -d '\r\n ')
echo "Nouveau token (premier 50 chars): ${new_token:0:50}..."

echo ""
echo "=== Comparaison ==="
if [ "$token" != "$new_token" ]; then
  echo "✅ SUCCÈS: Le token a été renouvelé (tokens différents)"
else
  echo "❌ ÉCHEC: Le token n'a pas changé"
fi

echo ""
echo "=== Body de la réponse refresh ==="
echo "$refresh_response" | tail -5
