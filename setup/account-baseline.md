# AWS Account Baseline

Last verified: 2026-10-18

## Region
- Primary: ap-southeast-1 (Singapore)
- IAM Identity Center home region: ap-southeast-1

## Root user
- MFA: enabled (type: google authenticator) on 2026-10-17
- Access keys: none
- Used only for: tasks that require root (e.g. billing access setting)

## Daily access
- Method: IAM Identity Center (SSO), short-lived credentials
- Access portal: https://d-xxxxxxxxxx.awsapps.com/start
- Permission set: AdministratorAccess
- IAM users / long-lived access keys: none (verified 2026-10-17)

## Billing and cost safety
- IAM access to billing: <enabled on 2026-10-18 / already enabled>
- Monthly cost budget: US$10
  - Actual: 50%, 80%, 100%
  - Forecasted: 100%
- Free Tier usage alerts: enabled

## Rules
- Run `terraform destroy` at the end of every lab session unless agreed otherwise
- No secrets, keys or account IDs committed to Git