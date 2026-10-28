# search.py — SkyTicket's flight search (Lesson 7b: deployed by Terraform)
import json
import boto3

dynamodb = boto3.client("dynamodb")


def handler(event, context):
    params = event["queryStringParameters"]
    origin = params["from"].upper()
    destination = params["to"].upper()
    date = params["date"]

    route = f"{origin}-{destination}"
    result = dynamodb.query(
        TableName="skyticket-flights",
        KeyConditionExpression="route = :r AND begins_with(departure, :d)",
        ExpressionAttributeValues={":r": {"S": route}, ":d": {"S": date}},
    )

    count = result["Count"]
    word = "flight" if count == 1 else "flights"

    # A full web answer, with a header that lets websites read it (CORS)
    return {
        "statusCode": 200,
        "headers": {
            "Content-Type": "application/json",
            "Access-Control-Allow-Origin": "*",
        },
        "body": json.dumps({
            "message": f"Found {count} {word} {origin} -> {destination} on {date}",
            "flights": result["Items"],
        }),
    }
