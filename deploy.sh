#!/usr/bin/env bash
# deploy.sh — upload the SkyTicket frontend to its S3 bucket.
set -euo pipefail

BUCKET="skyticket-web"

# Safety check: only deploy to floci, never to real AWS.
if [[ "${AWS_ENDPOINT_URL:-}" != *localhost* ]]; then
  echo "STOP: not pointed at floci. Run:  eval \"\$(floci env)\"" >&2
  exit 1
fi

aws s3 sync frontend/ "s3://$BUCKET" --delete
echo "Deployed: http://$BUCKET.s3-website.localhost.floci.io:4566/"
