# NET-01: VPC in Terraform

A three-tier VPC (public, private-app, private-db) across two AZs in `ap-southeast-1`, built with Terraform. It has an Internet Gateway, one NAT gateway, and a route table for each tier.

This is the network foundation for later labs (CMP-01 compute, NET-03 Session Manager and VPC endpoints) and for PRJ-1. TF-05 will refactor this code into a reusable module.

## Architecture

| Tier | ap-southeast-1a | ap-southeast-1b | Summary CIDR | Route to internet |
|---|---|---|---|---|
| VPC | — | — | `10.20.0.0/20` | — |
| Public | `10.20.0.0/24` | `10.20.1.0/24` | `10.20.0.0/23` | `0.0.0.0/0 → IGW` |
| Private-app | `10.20.4.0/24` | `10.20.5.0/24` | `10.20.4.0/23` | `0.0.0.0/0 → NAT (public-a)` |
| Private-db | `10.20.8.0/24` | `10.20.9.0/24` | `10.20.8.0/23` | none (only `local`) |

Free for later: `10.20.2.0–3.255`, `10.20.6.0–7.255` and `10.20.10.0–15.255` (another AZ or another tier).

```
Internet
   │
  IGW
   │
public-a ── NAT GW (EIP)        public-b
   │
   ├── private-app-a  ──┐
   └── private-app-b  ──┴─ 0.0.0.0/0 → NAT (cross-AZ from 1b)

private-db-a / private-db-b ── local route only
```

## Files

| File | Contents |
|---|---|
| `versions.tf` | Terraform >= 1.10, AWS provider ~> 6.72, partial S3 backend, `default_tags` |
| `variables.tf` / `dev.tfvars` | region, project, environment (validated), lab |
| `locals.tf` | name prefix, VPC CIDR, subnet map (CIDR, AZ, `tier`), route table map, common tags |
| `vpc.tf` | VPC (DNS support and hostnames on), Internet Gateway |
| `subnets.tf` | 6 subnets via `for_each`; `map_public_ip_on_launch` derived from `tier == "public"` |
| `nat.tf` | EIP and NAT gateway in public-a, `depends_on` the IGW |
| `routes.tf` | 3 route tables, 2 default routes, 6 explicit associations keyed by `tier` |
| `outputs.tf` | `vpc_id`, `subnet_ids` (map of subnet key to ID) |

## How to run

```bash
cp backend.hcl.example backend.hcl   # set the state bucket name (gitignored)
terraform init -backend-config=backend.hcl
terraform plan -var-file=dev.tfvars -out=tfplan   # expect: 21 to add
terraform apply tfplan
# ... run the verification below ...
terraform destroy -var-file=dev.tfvars           # expect: 21 destroyed
```

State key: `labs/networking/01-vpc/terraform.tfstate`

## Verification

These are **configuration** checks; no instances are launched in this lab. Real traffic through the NAT is tested in CMP-01 and NET-03.

```bash
VPC=$(aws ec2 describe-vpcs --profile <profile> \
  --filters "Name=tag:Name,Values=aws-cloud-labs-net-01-vpc" \
  --query 'Vpcs[0].VpcId' --output text)
```

| Check | Command | Result |
|---|---|---|
| Routes | `aws ec2 describe-route-tables --filters "Name=vpc-id,Values=$VPC"` | public: `0.0.0.0/0 → igw-…` active; private-app: `0.0.0.0/0 → nat-…` active; private-db and main: only `10.20.0.0/20 → local` |
| NAT | `aws ec2 describe-nat-gateways --filter "Name=vpc-id,Values=$VPC"` | `available`, `zonal`, EIP associated, subnet = public-a (`ap-southeast-1a`) |
| Associations | `--query 'RouteTables[].{RT:RouteTableId,Main:Associations[?Main]\|[0].Main,Subnets:Associations[?!Main].SubnetId}'` | main route table: `Main: true`, `Subnets: []`; each custom route table: 2 subnets |
| Public IPs | `aws ec2 describe-subnets --filters "Name=vpc-id,Values=$VPC" --query 'Subnets[].[Tags[?Key==\`Name\`]\|[0].Value,MapPublicIpOnLaunch]'` | `true` only for public-a and public-b |

Destroy order (from the destroy log). The NAT gateway was deleted before the IGW was detached:

```
aws_nat_gateway.lab: Destruction complete after 1m21s
aws_internet_gateway.lab: Destroying...
```

## Design decisions

- **`10.20.0.0/20`, not `10.0.0.0/x`.** `10.0.x.x` is the default in tutorials and many corporate networks. A non-default block avoids overlap if this VPC is later peered, attached to a Transit Gateway or connected over VPN. Each future VPC gets its own non-overlapping block.
- **Subnets grouped by tier, not by AZ.** Each tier fits one summary CIDR (e.g. `10.20.0.0/23` = all public), so one security group or NACL rule can cover a whole tier, with room for more AZs.
- **Separate data tier.** The DB subnets have their own route table with no default route, so the database can't reach or be reached from the internet, and the tier can get its own NACLs and RDS subnet group later.
- **One NAT gateway (lab only).** This reduces hourly cost. The trade-off: `private-app-b` routes across AZs to the NAT in 1a, so there's cross-AZ data transfer, and if 1a fails, 1b loses egress.
- **`tier` is the single source of truth.** Route table association and `map_public_ip_on_launch` are both derived from it, so a subnet can't be "public" in one field and "private" in another.
- **Explicit `depends_on` from NAT to IGW.** The NAT only references the EIP and the subnet, so Terraform sees no edge to the IGW. `depends_on` makes create order IGW → NAT and destroy order NAT → IGW. Without it, the IGW detach can fail with `DependencyViolation` while the NAT's EIP is still mapped.

## Cost and teardown

The NAT gateway and its EIP bill **hourly even when idle**, plus NAT data processing. Always run `terraform destroy` at the end of a session. NAT deletion takes about 1.5 minutes. Subnets, route tables, the IGW and the VPC have no hourly cost.

## Lessons learned

- **A subnet is not public because of its name.** It's public only if its route table has a path to an IGW. This made me think about traffic flow and dependencies rather than just Terraform resources.
- **Creating a route table does nothing on its own.** Subnets need an **explicit** association. Without one, a subnet is **implicitly** associated with the main route table, which only has `local`. A subnet created in the console ends up exactly like this.
- **Unmanaged is not drift.** Terraform only detects drift on resources in state. A subnet created in the console is invisible to `plan`. The fix is to add it to the code and `import` it.
- **AWS creates the main route table, default security group and default NACL along with the VPC.** They aren't in Terraform state (21 resources, not 24), and they're deleted with the VPC.
- **NAT placement.** The NAT gateway must be in a public subnet (route to IGW) and have an EIP. In a private subnet it has no way out.
- **AZ names vs AZ IDs.** Names map to different physical zones in each account (here `1a` = `apse1-az2`, `1b` = `apse1-az1`). Use AZ IDs when resources in different accounts must be in the same physical zone (RAM-shared subnets, PrivateLink).
- **DNS settings.** `enable_dns_support` and `enable_dns_hostnames` must both be on for interface endpoint private DNS and Route 53 private hosted zones (needed in NET-03).
- **CLI quirk.** `describe-nat-gateways` takes `--filter`, unlike the other `describe-*` commands, which take `--filters`.

## What I'd change for production

- One NAT gateway per AZ, with each private route table pointing to the NAT in its own AZ.
- An S3 gateway endpoint (free) and, where the traffic justifies the hourly cost, interface endpoints (e.g. ECR), to cut NAT data processing.
- VPC Flow Logs, to see what traffic goes through the NAT before optimizing.
- Custom NACLs per tier. These are stateless, so allow inbound ephemeral ports `1024–65535` for return traffic.
- A reusable VPC module (TF-05).
