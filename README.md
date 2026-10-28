# ✈️ SkyTicket

A flight-tickets website on AWS, built as a DevOps learning project.
It runs locally on [floci](https://github.com/floci-io/floci), a free AWS emulator.

## Architecture (so far)

Browser → S3 static website (bucket `skyticket-web`)

Coming next: API Gateway → Lambda → DynamoDB, Terraform, CI/CD.

## Run it

```bash
floci start
eval "$(floci env)"
aws s3 mb s3://skyticket-web
aws s3 website s3://skyticket-web --index-document index.html --error-document error.html
./deploy.sh
```

Then open http://skyticket-web.s3-website.localhost.floci.io:4566/

## Safety

`deploy.sh` refuses to run unless the AWS CLI points at localhost,
so it can never deploy to a real AWS account by accident.

## Database (DynamoDB)

Table `skyticket-flights`: partition key `route` (e.g. `JFK-LHR`), sort key `departure` (e.g. `2026-11-05T08:30`).
A search for a route on a date is a single Query, not a Scan.

```bash
aws dynamodb create-table --table-name skyticket-flights \
  --attribute-definitions AttributeName=route,AttributeType=S AttributeName=departure,AttributeType=S \
  --key-schema AttributeName=route,KeyType=HASH AttributeName=departure,KeyType=RANGE \
  --billing-mode PAY_PER_REQUEST
aws dynamodb wait table-exists --table-name skyticket-flights
aws dynamodb batch-write-item --request-items file://data/flights.json
```

## Search API (Lambda)

`api/search.py` receives `{"from", "to", "date"}`, builds the route key (`FROM-TO`)
and runs one DynamoDB Query.

```bash
zip -j api/search.zip api/search.py
aws lambda create-function --function-name skyticket-search --runtime python3.12 \
  --handler search.handler --zip-file fileb://api/search.zip \
  --role arn:aws:iam::000000000000:role/lambda-role
aws lambda wait function-active-v2 --function-name skyticket-search
aws lambda invoke --function-name skyticket-search --cli-binary-format raw-in-base64-out \
  --payload '{"from":"JFK","to":"LHR","date":"2026-11-05"}' response.json
```

## HTTP API (API Gateway)

`GET /search?from=JFK&to=LHR&date=2026-11-05` → Lambda `skyticket-search` → DynamoDB.

```bash
FN_ARN=$(aws lambda get-function --function-name skyticket-search --query Configuration.FunctionArn --output text)
aws apigatewayv2 create-api --name skyticket-api --protocol-type HTTP --target "$FN_ARN"
API_ID=$(aws apigatewayv2 get-apis --query "Items[?Name=='skyticket-api'].ApiId" --output text)
curl "http://$API_ID.execute-api.localhost.floci.io:4566/search?from=JFK&to=LHR&date=2026-11-05"
```

## Website ↔ API

The page reads the API address from `frontend/config.js` (not in Git, because the ID changes on every rebuild):

```bash
API_ID=$(aws apigatewayv2 get-apis --query "Items[?Name=='skyticket-api'].ApiId" --output text)
echo "const API_URL = \"http://$API_ID.execute-api.localhost.floci.io:4566\";" > frontend/config.js
./deploy.sh
```

The Lambda returns `Access-Control-Allow-Origin: *` so the browser lets the page read the answer (CORS).

## Infrastructure as code (Terraform)

The flights table is managed by Terraform in `infra/` (floci endpoint + dummy keys, so it can never touch a real AWS account).

```bash
cd infra
terraform init
terraform apply
aws dynamodb batch-write-item --request-items file://../data/flights.json
```

# ✈️ SkyTicket

A flight-search website built as a DevOps learning project: a serverless app on AWS,
defined entirely in Terraform and run locally on [floci](https://github.com/floci-io/floci), a free AWS emulator.

## Architecture

```
Browser → S3 static website → API Gateway (HTTP API) → Lambda (Python) → DynamoDB
          frontend/            GET /search?from&to&date   api/search.py     skyticket-flights
```

- **DynamoDB**: partition key `route` (`JFK-LHR`), sort key `departure` (`2026-11-05T08:30`), so every search is one Query, not a Scan.
- **Lambda**: builds the route key from the request, normalizes input (`jfk` → `JFK`), returns JSON with a CORS header.
- **Website**: plain HTML + JavaScript (`fetch`). The API address is generated into `frontend/config.js` by Terraform.

## Run it

```bash
floci start
eval "$(floci env)"
./up.sh
```

`up.sh` runs `terraform apply` (all infrastructure), loads `data/flights.json`, and uploads the website.
It's safe to run again at any time, and after a floci restart it rebuilds everything.

## Project layout

| Path | What |
|---|---|
| `infra/main.tf` | All infrastructure (Terraform) |
| `api/search.py` | The search Lambda |
| `frontend/` | The website |
| `data/flights.json` | Seed data |
| `up.sh`, `deploy.sh` | Rebuild everything / upload the website |

## Safety

- Terraform uses floci endpoints and dummy keys, so it can never touch a real AWS account.
- `up.sh` and `deploy.sh` refuse to run unless the AWS CLI points at localhost.
- Generated files (`config.js`, zips) and Terraform state are kept out of Git.