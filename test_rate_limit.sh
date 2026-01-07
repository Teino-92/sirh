#!/bin/bash

echo "=== Test Rate Limiting Login (5 attempts / 20 seconds) ==="
echo ""

for i in {1..7}; do
  echo "Tentative #$i:"
  response=$(curl -s -i -X POST http://localhost:3000/api/v1/login \
    -H "Content-Type: application/json" \
    -d '{"email": "admin@techcorp.fr", "password": "wrong_password"}')

  status=$(echo "$response" | head -1)
  echo "  Status: $status"

  # Extract rate limit headers if present
  retry_after=$(echo "$response" | grep -i "Retry-After:" | cut -d' ' -f2 | tr -d '\r')
  rate_limit=$(echo "$response" | grep -i "X-RateLimit-Limit:" | cut -d' ' -f2 | tr -d '\r')
  remaining=$(echo "$response" | grep -i "X-RateLimit-Remaining:" | cut -d' ' -f2 | tr -d '\r')

  if [ ! -z "$rate_limit" ]; then
    echo "  Rate Limit: $rate_limit"
    echo "  Remaining: $remaining"
    echo "  Retry After: $retry_after seconds"
  fi

  # Show error if throttled
  if echo "$status" | grep -q "429"; then
    error=$(echo "$response" | tail -1)
    echo "  Error: $error"
  fi

  echo ""
done

echo "Test terminé!"
