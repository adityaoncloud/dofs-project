import json
import boto3
import os
import uuid

stepfunctions = boto3.client('stepfunctions')
STATE_MACHINE_ARN = os.environ['STATE_MACHINE_ARN']

def lambda_handler(event, context):
    try:
        body = json.loads(event['body'])
        order_id = str(uuid.uuid4())
        body['order_id'] = order_id

        response = stepfunctions.start_execution(
            stateMachineArn=STATE_MACHINE_ARN,
            input=json.dumps(body)
        )

        return {
            'statusCode': 200,
            'body': json.dumps({
                'message': 'Order received',
                'order_id': order_id,
                'executionArn': response['executionArn']
            })
        }

    except Exception as e:
        return {
            'statusCode': 500,
            'body': json.dumps({'error': str(e)})
        }
