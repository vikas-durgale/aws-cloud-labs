# IAM-02: Least-privilege roles for EC2 and Lambda

Two execution roles built in Terraform, each granted only the exact actions on the exact resource ARNs its workload needs, then verified with the IAM policy simulator, IAM Access Analyzer and a real Lambda invoke.

## What this lab builds

| Workload | Trust (who can assume) | Permissions (what it can do) |
|---|---|---|
| EC2 (role + instance profile) | `ec2.amazonaws.com` → `sts:AssumeRole` | `s3:GetObject` on `<bucket>/config/*` only; `logs:CreateLogStream` + `logs:PutLogEvents` on its own log group `:*` |
| Lambda (execution role) | `lambda.amazonaws.com` → `sts:AssumeRole` | `dynamodb:PutItem` on one table ARN only; `logs:CreateLogStream` + `logs:PutLogEvents` on `/aws/lambda/<function>:*` |

Supporting resources:

- **S3 lab bucket:** Block Public Access (all 4), SSE-S3, two test objects: `config/app.json` (EC2 may read) and `secret/cred.txt` (EC2 may not).
- **DynamoDB table:** on-demand (`PAY_PER_REQUEST`), hash key `pk` (S).
- **Lambda function:** Python 3.12; writes one item per invoke (`pk = invoke#<request id>`, `created_at`, `source`, `message`). Table name passed via `TABLE_NAME` environment variable.
- **CloudWatch log groups:** one for EC2, one for Lambda, both 7-day retention, **created by Terraform before the workloads exist.**

No AWS managed policies are attached. `AWSLambdaBasicExecutionRole` is deliberately not used: it grants `logs:CreateLogGroup`, `logs:CreateLogStream` and `logs:PutLogEvents` on `Resource: "*"`, i.e. any log group in the account.

## Files

| File | Purpose |
|---|---|
| `versions.tf` | Terraform >= 1.10, AWS provider ~> 6.72, archive provider ~> 2.8, partial S3 backend with native locking, default tags |
| `variables.tf`, `dev.tfvars` | Region, project, environment (validated), lab |
| `locals.tf` | Single source for names: `name_prefix`, `bucket_name`, `function_name`, `dynamodb_table_name`, tags |
| `s3.tf` | Lab bucket, public access block, encryption, test objects |
| `dynamodb.tf` | Lab table |
| `logs.tf` | EC2 and Lambda log groups |
| `data.tf` | Caller identity, all trust and permissions policy documents, Lambda zip (`archive_file`) |
| `iam_ec2.tf` | EC2 role, customer-managed policy, attachment, instance profile |
| `iam_lambda.tf` | Lambda role, customer-managed policy, attachment |
| `lambda.tf`, `src/handler.py` | Function and handler |
| `outputs.tf` | Role ARNs, instance profile, bucket, log group, function, table name and ARN |

## Usage

```bash
# backend.hcl (gitignored) holds the state bucket name; see terraform/04-remote-state
terraform init -backend-config=backend.hcl
terraform plan -var-file=dev.tfvars -out=tfplan   # expect 16 to add from empty state
terraform apply tfplan
```

State key: `labs/iam/02-least-privilege-roles/terraform.tfstate`. Region: `ap-southeast-1`.

## Verification

### Lambda (real invoke)

```bash
aws lambda invoke --function-name "$(terraform output -raw function_name)" \
  --cli-binary-format raw-in-base64-out --payload '{"message":"test-1"}' out.json
aws dynamodb get-item --table-name "$(terraform output -raw dynamodb_table_name)" \
  --key '{"pk":{"S":"invoke#<request-id>"}}'          # run with the admin profile
aws logs describe-log-streams --log-group-name "/aws/lambda/$(terraform output -raw function_name)"
```

Result: invoke returned 200 on the first try; the item was present with all four attributes; one log stream existed. That proves the function writes logs without `logs:CreateLogGroup`.

The item is read back with the admin profile, not the Lambda role. The role's trust policy only allows `lambda.amazonaws.com`, so it can't be assumed from the CLI. Verifying with a principal outside the system under test is the point anyway.

### Policy simulator (`aws iam simulate-principal-policy`)

| Role | Action | Resource | Expected | Result |
|---|---|---|---|---|
| EC2 | `s3:GetObject` | `config/app.json` | allowed | allowed |
| EC2 | `s3:GetObject` | `secret/cred.txt` | implicitDeny | implicitDeny |
| EC2 | `s3:PutObject`, `s3:ListBucket` | bucket / objects | implicitDeny | implicitDeny |
| EC2 | `logs:CreateLogStream`, `logs:PutLogEvents` | own log group | allowed | allowed |
| EC2 | logs actions | another log group | implicitDeny | implicitDeny |
| Lambda | `dynamodb:PutItem` | lab table | allowed | allowed |
| Lambda | `dynamodb:PutItem` | other table, **same account** | implicitDeny | implicitDeny |
| Lambda | `dynamodb:GetItem` | lab table | implicitDeny | implicitDeny |
| Lambda | logs actions | EC2 log group `:*` | implicitDeny | implicitDeny |

### Access Analyzer (`aws accessanalyzer validate-policy`)

`findings: []` for all four documents (EC2 and Lambda, trust and permissions).

## Lessons learned

**ARNs**
- `arn:...:table/<name>/*` does **not** match the table. It matches sub-resources (indexes, streams). `PutItem` acts on the table ARN itself, so `/*` would have caused an implicit deny on every write. It was caught in code review before apply.
- CloudWatch Logs ARNs use `:`, not `/`. Terraform's `aws_cloudwatch_log_group.arn` has no `:*` suffix, so the policy appends `:*` itself. `describe-log-groups` returns two fields: `arn` (legacy, ends in `:*`, used for authorization) and `logGroupArn` (no suffix).
- Typos in action names (`logs:CreateLogStrem`) are not rejected by IAM. The policy silently never grants them. `validate-policy` catches this, which is why it runs on every policy.

**Trust vs. permissions**
- Creating a role grants nothing. The trust policy decides *who can assume* the role; attached policies decide *what it can do*.
- The Lambda *service* assumes the execution role on the function's behalf; the function doesn't assume it.
- `aws:SourceArn` / `aws:SourceAccount` in a Lambda execution role's trust policy are not supported. Reports show the condition appears to work for invoke but breaks other operations (e.g. changing VPC security groups). A happy-path invoke test would have given a false positive. To bind permissions to one function, use `lambda:SourceFunctionArn` in an identity policy or SCP instead.

**Terraform**
- `depends_on` points at the **policy attachment**, not the role. The role edge already exists through `role = aws_iam_role.lambda.arn`. The attachment edge means permissions exist before the function does, and on destroy the function is deleted before its permissions are detached.
- IAM is eventually consistent: even with correct ordering, an invoke in the first seconds after apply can fail. Here it succeeded first time.
- Pre-creating `/aws/lambda/<function>` gives Terraform control of retention. If Lambda auto-creates the group, retention is "Never expire", and the next apply fails with `ResourceAlreadyExistsException` until the group is imported or deleted.
- Without `source_code_hash`, Terraform doesn't redeploy the function when only `handler.py` changes.
- The zip is built inside the module and gitignored. A path like `~/...` would break CI and leak a local path into state.
- DynamoDB tables only declare `attribute` blocks for key and index attributes; extra ones fail at apply.
- Single source of truth: `local.function_name` builds both the function name and the log group name.

**Testing**
- One variable per test. A "wrong table" test with a foreign account ID passes for two reasons at once; using your own account isolates the table name.
- The simulator evaluates identity policies only, unless resource policies are passed with `--resource-policy`.

## Production changes

- Use one execution role per function. Restrict `iam:PassRole` so only the deployment pipeline can pass powerful roles to functions.
- Use KMS customer-managed keys for the table, logs and bucket (SEC-01).
- Enable DynamoDB point-in-time recovery and deletion protection on tables holding real data.
- Run `validate-policy` and checkov in CI on every PR (CICD-03).
- Set longer log retention to match the organization's policy; 7 days is a lab value.

## Cost and teardown

Cost is negligible while running (on-demand DynamoDB, a handful of Lambda invokes, small S3 objects and logs).

```bash
terraform destroy -var-file=dev.tfvars
```

The bucket uses `force_destroy` so test objects don't block deletion. The shared state bucket is not part of this lab and is kept.
