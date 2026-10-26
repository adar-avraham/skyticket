# search.py — SkyTicket's flight search (Lesson 6a: called through API Gateway)
import boto3

dynamodb = boto3.client("dynamodb")


def handler(event, context):
    # NEW: API Gateway puts the URL's ?from=…&to=…&date=… in here
    params = event["queryStringParameters"]
    origin = params["from"]
    destination = params["to"]
    date = params["date"]

    route = f"{origin}-{destination}"
    result = dynamodb.query(
        TableName="skyticket-flights",
        KeyConditionExpression="route = :r AND begins_with(departure, :d)",
        ExpressionAttributeValues={":r": {"S": route}, ":d": {"S": date}},
    )

    return {
        "message": f"Found {result['Count']} flights {origin} -> {destination} on {date}",
        "flights": result["Items"],
    }