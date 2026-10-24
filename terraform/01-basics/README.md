# S3 Bucket — Terraform Lab

## What It Builds
- One AWS S3 bucket with default tags, managed by Terraform.

## Prerequisites
- AWS CLI configured with an IAM Identity Center (SSO) profile.
- Log in to AWS and set the profile in the same PowerShell terminal:

```powershell
aws sso login --profile <profile-name>
$env:AWS_PROFILE = "<profile-name>"
```

## Run

**Before running Terraform:** Change `bucket` in `main.tf` to a globally unique S3 bucket name. S3 bucket names must be unique across AWS accounts within an AWS partition.

Run the following commands in order:

```bash
terraform init
terraform fmt
terraform validate
terraform plan
terraform apply
```

To tear down the lab:

```bash
terraform destroy
```

## Lessons Learned

1. **AWS credential configuration matters.** I encountered a `No valid credential sources` error because Terraform could not obtain valid AWS credentials. Logging in with AWS SSO and setting `AWS_PROFILE` in the same terminal resolved the configuration issue.

2. **A plan shows proposed changes, not the future state.** `terraform plan` compares my configuration with Terraform state and the observed infrastructure to determine the changes required. This is important for identifying unintended changes and detecting infrastructure drift.

3. **Resource replacement can be destructive.** The `-/+` symbol indicates that Terraform will destroy and recreate a resource; `# forces replacement` identifies the attribute requiring replacement. For resources containing data, such as S3 buckets or databases, replacement can cause data loss or service disruption, so I review the plan carefully before applying it.

4. **Terraform state needs protection.** State files map Terraform resources to real infrastructure and may contain sensitive values, so they should not be committed to Git. **Next step:** Configure an S3 remote backend with state locking in TF-04.

5. **The dependency lock file improves reproducibility.** `.terraform.lock.hcl` records selected provider versions and package checksums, helping Terraform verify provider packages. It should be committed to Git, and checksums for additional platforms may need to be added when working across Windows and Linux CI environments.
