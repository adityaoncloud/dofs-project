# 📦 Distributed Order Fulfillment System (DOFS)

A fully event-driven, serverless order processing system built with AWS services and Terraform. It uses CI/CD via AWS CodePipeline and CodeBuild for automated infrastructure deployment.

---

## 🔧 Prerequisites

Before you begin, make sure you have the following installed and configured:

- Terraform
- AWS CLI
- Python
- Git 

- AWS IAM permissions to create:
  - Lambda, API Gateway, SQS, DynamoDB, Step Functions
  - IAM Roles and Policies
  - CodePipeline and CodeBuild
- GitHub personal access token (with `repo` and `workflow` scopes)

---

## 📁 Project Structure

```
dofs-project/
├── lambdas/
│   ├── api_handler/
│   ├── validator/
│   ├── order_storage/
│   ├── fulfill_order/
│   └── dlq_handler/
├── terraform/
│   ├── main.tf
│   ├── backend.tf
│   ├── variables.tf
│   ├── outputs.tf
│   ├── cicd/
│   │   ├── codepipeline.tf
│   │   ├── codebuild.tf
│   │   ├── iam_roles.tf
│   ├── modules/
│   │   ├── api_gateway/
│   │   ├── lambdas/
│   │   ├── dynamodb/
│   │   ├── sqs/
│   │   ├── stepfunctions/
│   │   ├── monitoring/
├── buildspec.yml
├── .github/
│   └── workflows/
│       └── ci.yml (optional GitHub Actions)
└── README.md
```

---

## 🚀 Setup Instructions

### 🔐 1. Clone the Repository

```bash
git clone https://github.com//dofs-project.git
cd dofs-project/terraform
```

### ⚙️ 2. Configure Backend (Optional)

Edit `backend.tf` to configure remote S3 state storage:

```hcl
terraform {
  backend "s3" {
    bucket = "your-terraform-state-bucket"
    key    = "dofs/terraform.tfstate"
    region = "ap-south-1"
  }
}
```

Run:

```bash
terraform init
```

### 🔑 3. Add GitHub Token

In `terraform.tfvars` (create if not present):

```hcl
github_token = "ghp_YourGitHubTokenHere"
```

Or pass it directly:

```bash
terraform apply -var="github_token=ghp_YourGitHubTokenHere"
```

### ☁️ 4. Deploy Infrastructure

```bash
terraform apply
```

Terraform provisions:
- API Gateway + Lambda integration
- Step Function with validation & fulfillment
- DynamoDB: `orders`, `failed_orders`
- SQS: `order_queue`, `order_dlq`
- Lambda event source mappings
- CI/CD: CodePipeline + CodeBuild

### ✅ 5. Test the API

Submit an order:

```bash
curl -X POST https://.execute-api..amazonaws.com/orders \
  -H "Content-Type: application/json" \
  -d '{
    "order_id": "order-123",
    "item": "laptop",
    "quantity": 1
}'
```

Check orders table and CloudWatch logs.

### 🧪 Testing the System

| Scenario | What Happens |
|----------|-------------|
| Valid Order | Stored in orders table and fulfilled successfully |
| Fulfillment Fail | Retry 3x → goes to DLQ → failed_orders entry |
| Invalid Payload | validator Lambda fails → Step Function fails early |

To simulate fulfillment failure, change env var `FAILURE_THRESHOLD=0.0` for fulfill_order Lambda.

---

## 🔁 CI/CD Pipeline Explanation

### 🔨 CodePipeline Stages

| Stage | Description |
|-------|-------------|
| Source | Pulls from GitHub (main branch) |
| Build | CodeBuild runs terraform plan & apply |
| Deploy | Applies to DEV environment automatically |

### 🧱 CodeBuild Configuration

CodeBuild uses this `buildspec.yml`:

```yaml
version: 0.2

phases:
  install:
    runtime-versions:
      terraform: 1.5
    commands:
      - echo "Installing dependencies"
  build:
    commands:
      - terraform init
      - terraform validate
      - terraform plan -out=tfplan
      - terraform apply -auto-approve tfplan
```

Artifacts are stored in an S3 bucket (auto-provisioned).

### 🔄 Pipeline Flow

1. **Source Stage**: Monitors GitHub repository for changes on main branch
2. **Build Stage**: CodeBuild executes Terraform commands to validate and deploy infrastructure
3. **Deploy Stage**: Automatically applies changes to the development environment

---

## 🛠️ Troubleshooting

### Common Issues and Solutions

| Problem | Fix |
|---------|-----|
| `terraform apply` fails with SQS permission error | Ensure DLQ Lambda has `sqs:ReceiveMessage` permission |
| CodePipeline not triggered | Check GitHub webhook / token |
| No logs in Lambda | Ensure correct IAM roles + CloudWatch log group exists |
| DLQ handler not triggered | Check EventSourceMapping and maxReceiveCount config |

### Debugging Commands

To view Lambda logs:
```bash
aws logs tail /aws/lambda/ --follow
```

To check pipeline status:
```bash
aws codepipeline get-pipeline-state --name dofs-pipeline
```

To verify DynamoDB tables:
```bash
aws dynamodb list-tables
aws dynamodb scan --table-name orders
```

### Environment Variables

Key environment variables to check:
- `ORDERS_TABLE`: DynamoDB table name for orders
- `FAILED_ORDERS_TABLE`: DynamoDB table name for failed orders
- `ORDER_QUEUE_URL`: SQS queue URL for order processing
- `FAILURE_THRESHOLD`: Threshold for simulating fulfillment failures

### Performance Monitoring

Monitor the system using:
- CloudWatch Metrics for Lambda execution duration and errors
- CloudWatch Logs for detailed execution traces
- X-Ray for distributed tracing (if enabled)
- SQS Dead Letter Queue metrics

---

## 🏗️ Architecture Overview

The system follows an event-driven architecture:

1. **API Gateway** receives order requests
2. **API Handler Lambda** processes incoming requests
3. **Step Functions** orchestrates the order workflow
4. **Validator Lambda** validates order data
5. **Order Storage Lambda** saves valid orders to DynamoDB
6. **Fulfill Order Lambda** processes order fulfillment
7. **SQS** handles message queuing and retry logic
8. **DLQ Handler Lambda** processes failed orders

## 🔒 Security Considerations

- All Lambda functions use least-privilege IAM roles
- API Gateway endpoints can be secured with API keys or AWS Cognito
- DynamoDB tables use encryption at rest
- SQS queues support encryption in transit
- CodePipeline artifacts are stored in encrypted S3   buckets

