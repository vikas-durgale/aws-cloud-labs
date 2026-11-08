# TF-04 · Remote state in S3 with locking

Moves Terraform state off the laptop into a hardened, central S3 bucket, with native S3 state locking (`use_lockfile`). Two root configs:

| Folder | Purpose | State location |
|---|---|---|
| `bootstrap/` | Creates the shared state bucket | Itself, in S3: `bootstrap/terraform.tfstate` (migrated from local) |
| `app/` | Small consumer config used to test remote state and locking | S3: `labs/04-remote-state/app/terraform.tfstate` |

```
aws-cloud-labs-tfstate-<account_id>-ap-southeast-1/
├── bootstrap/terraform.tfstate
└── labs/04-remote-state/app/terraform.tfstate
```

## What the bootstrap bucket enforces

| Control | How |
|---|---|
| Recover from bad writes or deletes | Versioning `Enabled` |
| Encryption at rest | SSE-S3 (`AES256`). A customer-managed KMS key comes in SEC-01 |
| No public access | Public access block, all four settings `true` |
| Encryption in transit | Bucket policy denies `s3:*` when `aws:SecureTransport = false`, on both the bucket ARN and `/*` |
| Version growth / cost | Lifecycle rule expires noncurrent versions after 90 days |
| Accidental `terraform destroy` | `prevent_destroy = true` on the bucket |

Security settings are hardcoded, not variables. They are rules for this bucket, not options.

## Design decisions

- **Bootstrap state lives in the bucket it creates.** It started on local state and was migrated after the bucket existed. Trade-off accepted: a broken bucket policy could block the config that fixes it, and tearing it down means migrating back to local first. Losing this state is low risk, because its 6 resources can be re-imported.
- **Native S3 locking instead of DynamoDB.** Needs Terraform >= 1.10, and means fewer resources and less IAM. `dynamodb_table` is deprecated; older codebases still use it, and migrations run both settings for a while.
- **Partial backend configuration.** Backend blocks can't use variables or locals. The committed `backend "s3"` block holds `key`, `region`, `use_lockfile` and `encrypt`. The bucket name (which contains the account ID) goes in a gitignored `backend.hcl`. `backend.hcl.example` is committed as a template. CI will pass the bucket name with `-backend-config` from a secret (CICD-03).
- **`app/` reuses `../bootstrap/backend.hcl`** so the bucket name is defined in one place. This only works inside this repo; PRJ-1 and PRJ-2 will need their own.
- **State keys mirror the repo path.** One bucket, one unique key per root config and environment. Two configs sharing a key would overwrite each other's state.
- **`prevent_destroy` on the bucket only.** It is for resources holding data that can't be restored. The policy, public access block and other sub-resources come back with the next apply, and are guarded by account-level public access block, reviewed plans and IAM.

## How to run

Bootstrap, first time in a new account (the bucket doesn't exist yet):

```bash
cd bootstrap
# 1. Comment out the backend "s3" block in versions.tf
terraform init
terraform apply -var-file=dev.tfvars
# 2. Uncomment the backend block, then:
cp backend.hcl.example backend.hcl   # fill in the bucket name from the output
terraform init -backend-config=backend.hcl -migrate-state
terraform plan -var-file=dev.tfvars  # expect: No changes
```

Bootstrap, from a fresh clone (the bucket already exists):

```bash
cd bootstrap
cp backend.hcl.example backend.hcl   # fill in the bucket name
terraform init -backend-config=backend.hcl
```

App:

```bash
cd app
terraform init -backend-config=../bootstrap/backend.hcl
terraform plan -var-file=dev.tfvars
terraform apply -var-file=dev.tfvars
```

## Lock test

1. Terminal A: `terraform apply -var-file=dev.tfvars` with a pending change, left waiting at the prompt.
2. Terminal B: `terraform plan` failed with `Error acquiring the state lock`. The `Lock Info` block shows ID, Path, Operation (`OperationTypeApply`), Who, Version and Created.
3. S3 held `terraform.tfstate.tflock` next to the state key, with the same JSON as `Lock Info`.
4. After A finished, the lock object was gone.

`force-unlock <ID>` is only for a lock whose holder is confirmed dead (crashed run, killed runner). Never use it on a lock that is still active, and never decide based on lock age alone. Run `terraform plan` straight after unlocking, because a crashed apply may have changed some resources.

## Teardown

```bash
cd app && terraform destroy -var-file=dev.tfvars
```

The bootstrap bucket is **kept**; every later lab stores its state there. Cost is cents per month. An empty `app` state key remains, which is expected.

## Lessons learned

- **Remote state isn't just storage.** It means a secure, isolated location for state, protected against concurrent writes.
- **`.terraform/terraform.tfstate` is not state.** It's the backend config cache that `init` writes; it tells Terraform to use S3. After migration, the local `terraform.tfstate` is emptied and `terraform.tfstate.backup` holds the old copy. I deleted both after confirming `plan` showed No changes.
- **`apply tfplan` never prompts.** The saved plan counts as the review. A plain `apply` prompts and holds the lock while it waits. Applying the exact reviewed plan is the CI pattern.
- **When migrating, read the init prompt.** "No state in S3, copy?" is safe. If state already exists at the destination, stop: answering yes overwrites it.
- **`-reconfigure` instead of `-migrate-state`** leaves local state behind. The next plan then wants to recreate everything: resources with unique names fail with "already exists", and others get created a second time.
- **`-lock=false` means the last writer wins.** Lost writes leave resources running and billing that Terraform no longer tracks.
- **Output a specific attribute, not the whole resource.** `value = aws_s3_bucket.x` exports every attribute and triggered a deprecation warning from `acceleration_status`. Use `.bucket` or `.arn`.
- **`validate` doesn't read tfvars.** A bool passed to lifecycle `status` (which needs `"Enabled"`/`"Disabled"`) passed validate and would only fail at plan.
- **Verify `.gitignore` per file.** Before staging I ran `git check-ignore -v` on `backend.hcl` (ignored) and `backend.hcl.example` (not ignored), and `git add -n` to list every file that would be added.
