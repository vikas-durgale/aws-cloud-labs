# IAM-01 · Policy evaluation: explicit deny, resource policies and KMS

Break-and-fix lab on how AWS decides whether a request is allowed. A dedicated lab role reads an SSE-KMS encrypted S3 object while permissions are moved between the identity policy, the bucket policy and the KMS key policy.

Unit IAM-01 · Built Nov 8–9, 2026 · Region `ap-southeast-1` · Terraform with remote state in S3 (native locking)

## Architecture

```
SSO admin role ──sts:AssumeRole──▶ lab role (aws-cloud-labs-iam-01-reader)
                                        │
                                        │ s3:GetObject
                                        ▼
                                  S3 bucket (SSE-KMS, bucket key on)
                                        │
                                        │ S3 calls kms:Decrypt on the caller's behalf
                                        ▼
                                  KMS key (default key policy → delegates to IAM)
```

| Resource | Purpose |
|---|---|
| `aws_iam_role.lab_reader` | Test principal. Trust: account root + `aws:PrincipalArn` = the SSO admin role (looked up with `aws_iam_session_context`) |
| `aws_iam_role_policy.lab_reader_s3_read` | Identity policy: `kms:Decrypt` on the lab key only, with `kms:ViaService = s3.<region>.amazonaws.com` |
| `aws_kms_key.lab` + `aws_kms_alias.lab` | Customer-managed key, default key policy, 7-day deletion window |
| `aws_s3_bucket.lab` | Lab bucket, SSE-KMS default encryption, bucket key enabled, public access block (all 4 on) |
| `aws_s3_bucket_policy.lab` | Resource policy: `s3:GetObject` for the lab role |
| `aws_s3_object.test_file` | Test object, created only after default encryption is set (`depends_on`) |

## Final permission layout (as committed)

| Permission | Granted in | Why there |
|---|---|---|
| `sts:AssumeRole` | Role trust policy | Account root as principal is broad; the `aws:PrincipalArn` condition narrows it to the SSO admin role |
| `s3:GetObject` | Bucket policy only | Same account: an Allow in either the identity policy or the resource policy is enough |
| `kms:Decrypt` | Identity policy | The default key policy delegates to IAM. A bucket policy cannot grant KMS permissions |

## Experiments

| Step | Change | Result | What the error said |
|---|---|---|---|
| 0 | Role with no policies, `aws s3 ls` | Denied, implicit | `...s3:ListAllMyBuckets because no identity-based policy allows...` |
| 1 | Identity policy: `s3:GetObject` only | Denied, implicit, **by KMS** | Operation `GetObject`, but action `kms:Decrypt` on the key ARN |
| 1 fix | Add `kms:Decrypt` scoped to the key with `kms:ViaService` | Success | n/a |
| 2 | Bucket policy: explicit Deny `s3:GetObject` for the role | Denied, explicit | `...with an explicit deny in a resource-based policy` |
| 3 | S3 Allow moved from identity policy to bucket policy | Success | n/a |

The committed code is the final state (step 3). To reproduce steps 1–2, edit the two `aws_iam_policy_document` blocks in `data.tf` as described above.

## How to run

Prerequisites: the shared state bucket from `terraform/04-remote-state/bootstrap`, an AWS CLI SSO admin profile, AWS Budgets alerts in place.

```bash
cd iam/01-policy-evaluation
terraform init -backend-config=../../terraform/04-remote-state/bootstrap/backend.hcl
terraform plan -var-file=dev.tfvars -out=tfplan
terraform apply tfplan
```

Add a profile to `~/.aws/config` (local only, never committed):

```ini
[profile iam-lab]
role_arn          = arn:aws:iam::<ACCOUNT_ID>:role/aws-cloud-labs-iam-01-reader
source_profile    = <your-sso-profile>
region            = ap-southeast-1
role_session_name = <your-name>-iam-lab
```

Test:

```bash
aws sts get-caller-identity --profile iam-lab
aws s3api head-object --bucket "$(terraform output -raw bucket_name)" --key lab_test.txt   # as admin: expect aws:kms
aws s3api get-object --bucket "$(terraform output -raw bucket_name)" --key lab_test.txt /tmp/lab_test.txt --profile iam-lab
```

Teardown: `terraform destroy -var-file=dev.tfvars`. The KMS key goes into a 7-day pending-deletion window (not billed); the alias is removed immediately. Cost while running: the KMS key, about $1/month prorated. Everything else is effectively free.

## Lessons learned

**Policy evaluation**
- Read the "because..." clause. `no identity-based policy allows` is an implicit deny; `with an explicit deny in a <policy type>` names both the deny type and where to look.
- An explicit Deny in any policy beats an Allow in any other policy.
- A condition that doesn't match means the statement doesn't apply. With no other Allow, the result is an implicit deny (e.g. calling `kms decrypt` directly fails the `kms:ViaService` condition).
- API operation names and IAM action names differ: `ListBuckets` is checked as `s3:ListAllMyBuckets`. Write policies using the action from the error.

**S3 and KMS**
- S3 calls `kms:Decrypt` on the caller's behalf, with the caller's permissions. An "S3 access denied" ticket can be a KMS fix.
- S3 evaluates first. If S3 denies, KMS is never asked, so no KMS change can help.
- Every KMS key needs its key policy to allow the request. The default key policy names the account root, which delegates to IAM. A bucket policy cannot grant KMS permissions.
- Same account: identity policy or bucket policy is enough for S3. Cross-account: the bucket policy and key policy must name the external role, and the role's own account must allow it too. The AWS-managed key `aws/s3` cannot be used cross-account.
- Block Public Access only rejects policies that grant public access. A Deny, or an Allow scoped to one role, is not public.

**Terraform**
- `aws_s3_object` raced the bucket's encryption configuration. Without `depends_on`, the object can be written with the SSE-S3 default and the KMS lesson silently disappears. Verify with `head-object`.
- A policy document that references a not-yet-created resource is read during apply, so the plan shows `policy = (known after apply)`. Building ARNs from known values (partition, account ID, names) makes the policy JSON reviewable in the plan.
- `aws_iam_session_context` turns an SSO session ARN (`assumed-role/...`) into the underlying role ARN, including its `aws-reserved/sso.amazonaws.com/...` path.
- A bucket policy that names a role ARN stores the role's unique ID. Delete and recreate the role and the policy no longer matches it.

**Safety**
- Never write a bucket-policy Deny on `s3:*` with `Principal: "*"`. It locks out admins and Terraform, and only the account root user can remove the policy.

## What I'd change in production

- **Trust policy:** name the trusted role explicitly (or `ArnLike` on `AWSReservedSSO_AdministratorAccess_*`) instead of deriving it from whoever runs `apply`. Run from CI, the current code would trust the CI role instead.
- **Key policy:** write an explicit key policy that separates key administrators from key users, and enable key rotation.
- **Tighter KMS condition:** add `kms:EncryptionContext:aws:s3:arn` so the role can only decrypt objects from this bucket.
- **Bucket policy:** add a TLS-only Deny, as on the state bucket.
- **Audit:** CloudTrail data events for S3 and KMS on sensitive buckets.
- **Naming:** include the environment in the name prefix so dev and prod can share an account without collisions.
