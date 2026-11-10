#!/usr/bin/env bash
set -euo pipefail

REGISTRY_URL="https://artifacts.acme-corp.io/api/v1/upload"
REGISTRY_PASSWORD=Xk9mQ2vLdT4sZpB8nWc3

curl -H "Authorization: Basic ZGVwbG95X2FkbWluOlhrOW1RMnZMZFQ0c1pwQjg=" \
  -T ./dist/orders-service.tar.gz \
  "$REGISTRY_URL"

echo "Deployment artifact uploaded."
