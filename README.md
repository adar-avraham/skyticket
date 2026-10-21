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
