# search.py — SkyTicket's flight search (Lesson 5b: real flights from DynamoDB)
import boto3

# 1. Connect: boto3 is "aws dynamodb …" for Python code
dynamodb = boto3.client("dynamodb")


def handler(event, context):
    origin = event["from"]
    destination = event["to"]
    date = event["date"]

    # 2. Build the partition key: "JFK" + "-" + "LHR" -> "JFK-LHR"
    route = f"{origin}-{destination}"

    # 3. The same Query you ran in Lesson 4, written in Python
    result = dynamodb.query(
        TableName="skyticket-flights",
        KeyConditionExpression="route = :r AND begins_with(departure, :d)",
        ExpressionAttributeValues={":r": {"S": route}, ":d": {"S": date}},
    )

    # 4. Answer: how many flights, and the flights themselves
    return {
        "message": f"Found {result['Count']} flights {origin} -> {destination} on {date}",
        "flights": result["Items"],
    }
