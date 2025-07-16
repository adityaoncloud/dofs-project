import json
import random
import boto3
import os

dynamodb = boto3.resource('dynamodb')
table_name = os.environ['ORDERS_TABLE']
table = dynamodb.Table(table_name)

def lambda_handler(event, context):
    try:
        for record in event['Records']:
            # Parse the SQS message body (it's a stringified JSON)
            body = json.loads(record['body'])

            # body already contains the order fields
            order = body

            order_id = order['order_id']
            success = random.random() < 0.7

            status = 'FULFILLED' if success else 'FAILED'

            table.update_item(
                Key={'order_id': order_id},
                UpdateExpression='SET order_status = :s',
                ExpressionAttributeValues={':s': status}
            )

            print(f"Order {order_id} processed with status {status}")

    except Exception as e:
        print(f"Error: {str(e)}")
        raise e  # Let it retry via SQS redrive
