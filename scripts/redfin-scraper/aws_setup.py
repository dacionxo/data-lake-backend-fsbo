"""
Automated AWS Lambda + API Gateway Setup for IP Rotation
Run this once to deploy your proxy infrastructure.

Prerequisites:
- AWS CLI installed: https://aws.amazon.com/cli/
- AWS credentials configured: `aws configure`
- Install boto3: `pip install boto3`
"""
import boto3
import json
import zipfile
import io
import time

# AWS Configuration
AWS_REGION = 'us-east-1'  # Change to your preferred region
LAMBDA_FUNCTION_NAME = 'WebScraperProxy'
API_GATEWAY_NAME = 'WebScraperAPI'

def create_lambda_function():
    """Creates the Lambda function with the proxy code."""
    lambda_client = boto3.client('lambda', region_name=AWS_REGION)
    iam_client = boto3.client('iam')
    
    # Create IAM role for Lambda
    trust_policy = {
        "Version": "2012-10-17",
        "Statement": [{
            "Effect": "Allow",
            "Principal": {"Service": "lambda.amazonaws.com"},
            "Action": "sts:AssumeRole"
        }]
    }
    
    try:
        role = iam_client.create_role(
            RoleName=f'{LAMBDA_FUNCTION_NAME}Role',
            AssumeRolePolicyDocument=json.dumps(trust_policy)
        )
        role_arn = role['Role']['Arn']
        
        # Attach basic execution policy
        iam_client.attach_role_policy(
            RoleName=f'{LAMBDA_FUNCTION_NAME}Role',
            PolicyArn='arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole'
        )
        
        print(f"✓ Created IAM role: {role_arn}")
        time.sleep(10)  # Wait for IAM propagation
        
    except iam_client.exceptions.EntityAlreadyExistsException:
        role_arn = iam_client.get_role(RoleName=f'{LAMBDA_FUNCTION_NAME}Role')['Role']['Arn']
        print(f"✓ Using existing IAM role: {role_arn}")
    
    # Create Lambda deployment package
    lambda_code = '''
import json
import urllib.request
import urllib.parse

def lambda_handler(event, context):
    try:
        query_params = event.get('queryStringParameters', {})
        target_url = query_params.get('url')
        
        if not target_url:
            return {'statusCode': 400, 'body': json.dumps({'error': 'Missing url parameter'})}
        
        target_url = urllib.parse.unquote(target_url)
        
        headers = {
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
            'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
            'Accept-Language': 'en-US,en;q=0.9'
        }
        
        req = urllib.request.Request(target_url, headers=headers)
        with urllib.request.urlopen(req, timeout=30) as response:
            html_content = response.read().decode('utf-8', errors='ignore')
            return {
                'statusCode': 200,
                'headers': {'Content-Type': 'text/html', 'Access-Control-Allow-Origin': '*'},
                'body': html_content
            }
    except Exception as e:
        return {'statusCode': 500, 'body': json.dumps({'error': str(e)})}
'''
    
    # Create ZIP file in memory
    zip_buffer = io.BytesIO()
    with zipfile.ZipFile(zip_buffer, 'w', zipfile.ZIP_DEFLATED) as zip_file:
        zip_file.writestr('lambda_function.py', lambda_code)
    zip_buffer.seek(0)
    
    # Create or update Lambda function
    try:
        response = lambda_client.create_function(
            FunctionName=LAMBDA_FUNCTION_NAME,
            Runtime='python3.11',
            Role=role_arn,
            Handler='lambda_function.lambda_handler',
            Code={'ZipFile': zip_buffer.read()},
            Timeout=30,
            MemorySize=256
        )
        print(f"✓ Created Lambda function: {response['FunctionArn']}")
    except lambda_client.exceptions.ResourceConflictException:
        zip_buffer.seek(0)
        lambda_client.update_function_code(
            FunctionName=LAMBDA_FUNCTION_NAME,
            ZipFile=zip_buffer.read()
        )
        print(f"✓ Updated existing Lambda function")
    
    return lambda_client.get_function(FunctionName=LAMBDA_FUNCTION_NAME)['Configuration']['FunctionArn']


def create_api_gateway(lambda_arn):
    """Creates API Gateway endpoint."""
    apigw_client = boto3.client('apigatewayv2', region_name=AWS_REGION)
    lambda_client = boto3.client('lambda', region_name=AWS_REGION)
    
    # Create HTTP API
    try:
        api = apigw_client.create_api(
            Name=API_GATEWAY_NAME,
            ProtocolType='HTTP',
            Target=lambda_arn
        )
        api_id = api['ApiId']
        api_endpoint = api['ApiEndpoint']
        print(f"✓ Created API Gateway: {api_endpoint}")
        
        # Grant API Gateway permission to invoke Lambda
        lambda_client.add_permission(
            FunctionName=LAMBDA_FUNCTION_NAME,
            StatementId='apigateway-invoke',
            Action='lambda:InvokeFunction',
            Principal='apigateway.amazonaws.com',
            SourceArn=f'arn:aws:execute-api:{AWS_REGION}:{boto3.client("sts").get_caller_identity()["Account"]}:{api_id}/*'
        )
        
        return api_endpoint
        
    except Exception as e:
        print(f"Error creating API Gateway: {e}")
        return None


def main():
    print("=" * 70)
    print("  AWS IP-Rotating Proxy Setup")
    print("=" * 70)
    
    print("\n[1/2] Creating Lambda function...")
    lambda_arn = create_lambda_function()
    
    print("\n[2/2] Creating API Gateway...")
    api_endpoint = create_api_gateway(lambda_arn)
    
    if api_endpoint:
        print("\n" + "=" * 70)
        print("  ✓ SETUP COMPLETE!")
        print("=" * 70)
        print(f"\nYour Proxy Endpoint: {api_endpoint}")
        print(f"\nUsage: {api_endpoint}?url=https://example.com")
        print("\nSave this endpoint - you'll use it in Enrichment.py")
        print("=" * 70)
    else:
        print("\n✗ Setup failed. Check AWS credentials and permissions.")


if __name__ == "__main__":
    main()