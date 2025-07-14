import json
import boto3
import os
import random
from datetime import datetime

dynamodb = boto3.resource('dynamodb')
TABLE_NAME = os.environ['ORDERS_TABLE']
FAILURE_THRESHOLD = float(os.environ.get('FAILURE_THRESHOLD', 0.3))

def lambda_handler(event, context):
    for record in event['Records']:
        try:
            body = json.loads(record['body'])
            order = body['order']
            order_id = order['order_id']

            # Simulate 70% success
            if random.random() > FAILURE_THRESHOLD:
                status = 'FULFILLED'
            else:
                raise Exception("Simulated fulfillment failure")

            # Update order as FULFILLED
            table = dynamodb.Table(TABLE_NAME)
            table.update_item(
                Key={'order_id': order_id},
                UpdateExpression="SET #s = :s, fulfilled_at = :t",
                ExpressionAttributeNames={'#s': 'status'},
                ExpressionAttributeValues={
                    ':s': status,
                    ':t': datetime.utcnow().isoformat()
                }
            )
            print(json.dumps({'order_id': order_id, 'status': status}))

        except Exception as e:
            print(json.dumps({'error': str(e), 'record': record}))
            raise e  # Let it retry via SQS redrive
