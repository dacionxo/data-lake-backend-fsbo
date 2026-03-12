## AWS FSBO Lambda Setup (StackDealFSBO-Scraper)

This file documents the configuration needed to deploy and run the FSBO scraper on AWS using Lambda, SQS, Supabase, and DataImpulse residential proxies.

---

### 1. AWS Account & Credentials

- **Account ID**: `859217211854`
- **Console password**: (store in password manager; do not commit)

**Programmatic access (CLI):** Use IAM access key and secret; store in `~/.aws/credentials` or env. Do not commit.

Recommended AWS profile name: `StackDealFSBO-Scraper`.

Example `~/.aws/credentials` entry (replace with your values):

```ini
[StackDealFSBO-Scraper]
aws_access_key_id = <YOUR_ACCESS_KEY>
aws_secret_access_key = <YOUR_SECRET_KEY>
region = us-east-1
```

---

### 2. DataImpulse Residential Proxies

- **Login** / **Password**: (store in SSM or env; do not commit)
- **Proxy Host**: `gw.dataimpulse.com`
- **Proxy Port**: `823`
- **Example proxy URI**: `http://<LOGIN>__cr.us:<PASSWORD>@gw.dataimpulse.com:823`

Lambda environment variables used by `lambda_fsbo_worker.py`:

```text
DATAIMPULSE_LOGIN=<your-login>
DATAIMPULSE_PASSWORD=<your-password>
DATAIMPULSE_HOST=gw.dataimpulse.com
DATAIMPULSE_PORT=823
DATAIMPULSE_REGION_TAG=__cr.us
```

---

### 3. Lambda Function: fsbo-listing-worker

**Handler**: `lambda_fsbo_worker.lambda_handler`

**Runtime**: `python3.11`

**Role name**: `fsbo-listing-worker-role`

**Example create-role trust policy file**: `scripts/redfin-scraper/iam_trust_lambda.json`

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
```

**CLI commands (from repo root `D:\Downloads\Data Lake Backend`):**

```powershell
$env:AWS_PROFILE = "StackDealFSBO-Scraper"
$env:AWS_REGION  = "us-east-1"

mkdir dist\fsbo-lambda -Force

copy "scripts\redfin-scraper\lambda_fsbo_worker.py" dist\fsbo-lambda\
copy "scripts\redfin-scraper\FSBO.py"               dist\fsbo-lambda\
copy "scripts\redfin-scraper\supabase_client.py"    dist\fsbo-lambda\

pip install --target dist\fsbo-lambda requests supabase boto3 aiohttp pandas

cd dist\fsbo-lambda
Compress-Archive -Path * -DestinationPath ..\fsbo-lambda.zip -Force
cd ../..

aws iam create-role `
  --role-name fsbo-listing-worker-role `
  --assume-role-policy-document file://scripts/redfin-scraper/iam_trust_lambda.json

aws iam attach-role-policy `
  --role-name fsbo-listing-worker-role `
  --policy-arn arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole

aws lambda create-function `
  --function-name fsbo-listing-worker `
  --runtime python3.11 `
  --role arn:aws:iam::859217211854:role/fsbo-listing-worker-role `
  --handler lambda_fsbo_worker.lambda_handler `
  --timeout 900 `
  --memory-size 1024 `
  --zip-file fileb://dist/fsbo-lambda.zip `
  --environment "Variables={
    DATAIMPULSE_LOGIN=<your-login>,
    DATAIMPULSE_PASSWORD=<your-password>,
    DATAIMPULSE_HOST=gw.dataimpulse.com,
    DATAIMPULSE_PORT=823,
    DATAIMPULSE_REGION_TAG=__cr.us
  }"
```

To update the function after code changes:

```powershell
aws lambda update-function-code `
  --function-name fsbo-listing-worker `
  --zip-file fileb://dist/fsbo-lambda.zip
```

---

### 4. SQS Queue and Enqueue Script

**Queue name** (example): `fsbo-listing-jobs`

After creating the queue in `us-east-1`, you’ll get a URL like:

```text
https://sqs.us-east-1.amazonaws.com/859217211854/fsbo-listing-jobs
```

Wire this queue as an event source for `fsbo-listing-worker` in the Lambda console (batch size 5–10).

Use the enqueue script to push jobs:

```powershell
$env:AWS_PROFILE = "StackDealFSBO-Scraper"

python "scripts\redfin-scraper\FSBO.py" --export-urls

python "scripts\redfin-scraper\enqueue_fsbo_sqs.py" `
  --queue-url "https://sqs.us-east-1.amazonaws.com/859217211854/fsbo-listing-jobs" `
  --urls-file "D:\Downloads\FSBO Documents\fsbo_listing_urls.txt" `
  --max-age-days 1 `
  --region "us-east-1"
```

This will start the bulk scrape via Lambda + DataImpulse proxies.

