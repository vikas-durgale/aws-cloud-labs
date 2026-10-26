# TF-02 · Variables, locals, outputs and tfvars

Deploys one S3 bucket with nothing hardcoded: every name and tag comes from input variables, combined in locals, and the useful values are returned as outputs.

## What it builds

| Resource | Purpose |
|---|---|
| `aws_s3_bucket.s3_lab` | Lab bucket, name built from variables plus the account ID |
| `aws_s3_bucket_versioning.versioining_lab` | Versioning, switched on or off by a boolean variable |
| `data.aws_caller_identity.current` | Looks up the account ID so the bucket name is globally unique |

`plan` shows **2 to add**: in AWS provider v4+, versioning is a separate Terraform resource, so Terraform tracks two objects in state even though AWS sees one bucket with a setting.

## Files

| File | Contents |
|---|---|
| `versions.tf` | Terraform and provider version constraints; provider `default_tags` fed from `local.common_tags` (no `profile`, credentials come from `AWS_PROFILE`) |
| `variables.tf` | `project`, `environment` (validated: `dev` or `prod`), `aws_region`, `enable_bucket_versioning`, `lab` |
| `locals.tf` | `name_prefix` (`<project>-<lab>-<environment>-<account-id>`) and `common_tags` |
| `data.tf` | Caller identity lookup |
| `main.tf` | Bucket and versioning resources |
| `outputs.tf` | Bucket name and ARN |
| `dev.tfvars` | Dev values (committed on purpose, see below) |

## How to run

```bash
export AWS_PROFILE=<your-sso-profile>
aws sts get-caller-identity          # confirm the right account first
terraform init
terraform fmt -check && terraform validate
terraform plan  -var-file=dev.tfvars
terraform apply -var-file=dev.tfvars
```

## Experiments

**Variable precedence** (lowest → highest):
`default` → `TF_VAR_*` env vars → `terraform.tfvars` → `*.auto.tfvars` → `-var` / `-var-file`

| Run | Command (environment set to `prod` in one place only) | Result |
|---|---|---|
| 1 | `TF_VAR_environment=prod` + `-var-file=dev.tfvars` | No changes, tfvars beat the env var |
| 2 | `-var-file=dev.tfvars -var="environment=prod"` | Bucket **replaced** (`-/+`), `-var` came last and won |
| 3 | `-var="environment=prod" -var-file=dev.tfvars` | No changes, `-var-file` came last and won |

`-var` and `-var-file` share the same level: **the last one on the command line wins**.

**Validation:** `-var="environment=staging"` fails in `plan` with the custom message, before any call to AWS.

## Lessons learned

- `terraform validate` checks configuration, not values: it does not read tfvars. A region typo (`ap-southeas-1`) passed `validate` and only failed in `plan`.
- Variable `validation` blocks run during `plan`, before AWS is contacted, with a clear custom error. They do not fire at `validate`.
- Changing a value that feeds a resource name forces **destroy and recreate**. Read the plan for `-/+` before `apply`; protect data stores with `prevent_destroy`.
- Versioning off = `Suspended`, not `Disabled`. An S3 bucket that has been versioned can never return to unversioned.
- One source of truth for tags: provider `default_tags` from a local, only resource-specific tags (like `Name`) on the resource. `tags_all` shows the merged result.
- Secrets never go in tfvars. They come from Secrets Manager, CI secrets or `TF_VAR_*`. Marking a variable `sensitive` only hides it from CLI output; the value is still stored in plan and state files.

## Why `dev.tfvars` is committed

It holds environment configuration, not secrets, and reviewers and CI need it to reproduce the plan. The root `.gitignore` still ignores `*.tfvars` and re-includes only `dev.tfvars` (`!dev.tfvars`), so other tfvars files stay protected.

## Known gaps

- `aws_region` has no validation block yet.
- Resource name typo `versioining_lab` is kept deliberately; it gets renamed with a `moved` block in TF-03.

## Teardown

```bash
terraform destroy -var-file=dev.tfvars
```
The bucket is empty and costs effectively nothing; it is kept for TF-03.
