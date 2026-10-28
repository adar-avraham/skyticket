#!/usr/bin/env bash
# up.sh — build (or rebuild) all of SkyTicket on floci with one command.
set -euo pipefail

# Safety check: the data load and deploy below use the aws CLI
if [[ "${AWS_ENDPOINT_URL:-}" != *localhost* ]]; then
  echo "STOP: not pointed at floci. Run:  eval \"\$(floci env)\"" >&2
  exit 1
fi

# 1. Things that should exist: Terraform
terraform -chdir=infra init -input=false
terraform -chdir=infra apply -auto-approve

# 2. Actions: load the flights, upload the website
aws dynamodb batch-write-item --request-items file://data/flights.json
./deploy.sh