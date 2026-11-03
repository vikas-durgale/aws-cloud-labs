# TF-03 · Terraform state: inspect, rename, drift, import

Hands-on lab covering what Terraform state holds and how to change the link between code and real infrastructure safely.

> **Code location:** the exercises ran against the existing state in [`../02-variables`](../02-variables/) (the TF-02 bucket was kept for this). This folder holds documentation only. Both buckets were destroyed at the end of the lab.

## What I did

| # | Exercise | Command / mechanism | Result |
|---|----------|---------------------|--------|
| 0 | Baseline check after a week idle | `terraform plan -var-file=dev.tfvars` | `No changes` — config, state and AWS agree |
| 1 | Inspect state | `terraform state list`, `terraform state show`, read `terraform.tfstate` | Found `serial`, `lineage`, `terraform_version` |
| 2 | Rename a resource the naive way | Renamed `versioining_lab` → `versioning_lab` in code only | `Plan: 1 to add, 0 to change, 1 to destroy` — **not applied** |
| 2b | Rename safely | `moved` block (`from` / `to`) | `Plan: 0 to add, 0 to change, 0 to destroy` + "has moved to"; applied, `serial` +1 |
| 3 | Drift | In console: added tag `ChangedBy`, edited `Environment` tag | Normal plan: `1 to change`, both tags reverted under `tags_all` |
| 3a | Inspect drift without acting | `terraform plan -refresh-only` | Reports changes made outside Terraform; touches neither AWS nor config |
| 3b | Revert drift | `terraform apply` → re-plan | `No changes` |
| 4 | Adopt a console-created bucket | `import` block, bucket name from `local.import_bucket_name` (account ID via `aws_caller_identity`) | `Plan: 1 to import, 0 to add, 1 to change, 0 to destroy` (change = `default_tags`); applied, re-plan `No changes` |
| 5 | Teardown | Removed `import` block, `terraform destroy` | `3 to destroy`; both buckets confirmed gone in console |

## Key concepts

- **State is the map** between resource addresses in code and real objects in AWS. Change the address without telling state, and Terraform sees a deletion plus a creation.
- **`serial`** increments on *every* state write (apply, import, `state mv`, refresh-only apply) — not only infrastructure changes. Backends use it to stop an older state overwriting a newer one.
- **`lineage`** identifies a state's history; `terraform state push` refuses a state with a different lineage (e.g. dev state over prod).
- **Secrets in state:** `sensitive = true` only hides values in CLI output — the plaintext is still in state. State must be encrypted and access-restricted (TF-04); for RDS, `manage_master_user_password = true` keeps the password out of state entirely.
- **`moved` vs `terraform state mv`:** `moved` is code — reviewed in a PR, previewed in a plan, applied by CI, kept in Git history. `state mv` changes state immediately with no preview or review trail. Refactors should be code, not commands. One `moved` block can move a whole module (`module.vpc` → `module.network`).
- **Removing blocks after use:** keep `moved` until every state that uses the code has applied it (longer for shared modules). Remove `import` after a successful import — while the resource is in state it is a no-op, but once the object is destroyed the next plan fails trying to import something that no longer exists.
- **Drift:** `tags_all` is the merge of provider `default_tags` and resource `tags`; Terraform owns the whole set, so tags added in the console are removed too. `apply -refresh-only` records drift in state but does not adopt it — the next normal plan still wants to revert until the code changes.
- **Import = adopt, including lifecycle.** Once imported, `terraform destroy` deletes a resource someone else created. Agree ownership before importing.

## Lessons learned

- **Read the diff, not just the `Plan:` line.** `1 to change` counts resources, not attributes — two tag edits on one bucket still show as `1`.
- **Drift decision logic** (I inverted this in the quiz first):
  - Change **not** wanted → the existing plan is already correct; apply it to revert.
  - Change **is** wanted → add it to code via PR (adopt); the plan then shows no changes.
  - Before either: talk to whoever made it — it may be an incident fix. An unexplained prod ingress rule may be a **security event**, not just drift.
- **Bulk import rule:** before any apply, each imported chunk's plan must show `0 to add, 0 to change, 0 to destroy, N to import`. Match code to reality first; make real changes in a separate PR. Use `-generate-config-out` for speed but review the output; add `prevent_destroy` on stateful resources; freeze console changes during migration.
- **Define a name once.** The import `id` and the resource's `bucket` both read `local.import_bucket_name` — if they ever diverge, the import becomes a `must be replaced`.
- Run `terraform fmt` and `terraform validate` before asking anyone to review.

## Teardown

Both buckets were destroyed on 2026-11-03 (`3 to destroy`) and confirmed absent in the S3 console. No resources from this lab are running.
