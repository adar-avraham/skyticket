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
