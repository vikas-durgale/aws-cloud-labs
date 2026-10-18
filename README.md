# AWS Cloud Labs

Hands-on AWS labs built with Terraform, Git and GitHub Actions, working
towards production-style cloud infrastructure. Each lab produces real,
deployable code and is torn down after use to control cost.

- **Region:** ap-southeast-1 (Singapore)
- **IaC:** Terraform, with remote state in S3 and locking (from TF-04)
- **CI/CD:** GitHub Actions with OIDC, no long-lived AWS keys
- **Access:** IAM Identity Center (SSO) only; no IAM users or access keys

Portfolio projects are kept in separate repositories (links added as they ship).

## Repository structure
aws-cloud-labs/
├── setup/ # Account baseline and local toolchain
├── terraform/ # Terraform fundamentals (planned)
├── networking/ # VPC, routing, troubleshooting labs (planned)
├── iam-security/ # IAM policy evaluation, KMS, Secrets Manager (planned)
├── compute/ # EC2, ALB, ASG, RDS (planned)
├── serverless/ # Lambda, API Gateway, DynamoDB (planned)
└── operations/ # CloudWatch, Linux troubleshooting (planned)


## Lab index

| Unit   | Topic                                                    | Folder   | Status |
|--------|----------------------------------------------------------|----------|--------|
| SET-01 | Account hardening: root MFA, Identity Center, Budgets    | `setup/` | Done   |
| SET-02 | Local toolchain: AWS CLI SSO profile, Terraform, SSH     | —        | Done   |
| GIT-01 | Branch → commit → PR workflow                            | —        | Done   |

## Cost safety

- AWS Budgets alerts (50/80/100% actual, 100% forecast) were set before any lab.
- Every lab ends with `terraform destroy` unless stated otherwise.
- NAT gateways, ALBs and RDS bill hourly even when idle.