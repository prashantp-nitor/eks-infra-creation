# DaaS EKS Infrastructure

Production-grade Amazon EKS cluster infrastructure using **Terraform** and **GitHub Actions CI/CD**. Supports three isolated environments (dev / staging / prod) with shared reusable modules.

---

## Architecture Overview

```text
┌─────────────────────────────────────────────────────────┐
│                        AWS Account                       │
│                                                          │
│  ┌──────────────────────────────────────────────────┐   │
│  │                    VPC (per env)                  │   │
│  │                                                   │   │
│  │  ┌──────────┐  ┌──────────┐  ┌──────────┐        │   │
│  │  │ Public   │  │ Public   │  │ Public   │  AZ x3  │   │
│  │  │ Subnet   │  │ Subnet   │  │ Subnet   │        │   │
│  │  │ (NAT GW) │  │ (NAT GW) │  │ (NAT GW) │        │   │
│  │  └──────────┘  └──────────┘  └──────────┘        │   │
│  │  ┌──────────┐  ┌──────────┐  ┌──────────┐        │   │
│  │  │ Private  │  │ Private  │  │ Private  │        │   │
│  │  │ Subnet   │  │ Subnet   │  │ Subnet   │        │   │
│  │  │ (Nodes)  │  │ (Nodes)  │  │ (Nodes)  │        │   │
│  │  └──────────┘  └──────────┘  └──────────┘        │   │
│  │                                                   │   │
│  │  ┌─────────────────────────────────────────────┐  │   │
│  │  │              EKS Cluster                    │  │   │
│  │  │  ┌──────────┐ ┌───────────┐ ┌───────────┐  │  │   │
│  │  │  │ system   │ │application│ │   spot    │  │  │   │
│  │  │  │ nodes    │ │ nodes     │ │   nodes   │  │  │   │
│  │  │  │(ON_DEMAND│ │(ON_DEMAND)│ │  (SPOT)   │  │  │   │
│  │  │  └──────────┘ └───────────┘ └───────────┘  │  │   │
│  │  │                                             │  │   │
│  │  │  Add-ons: vpc-cni · coredns · kube-proxy   │  │   │
│  │  │           ebs-csi · pod-identity-agent     │  │   │
│  │  └─────────────────────────────────────────────┘  │   │
│  └──────────────────────────────────────────────────┘   │
│                                                          │
│  S3 (Terraform state) + DynamoDB (state lock) + KMS     │
└─────────────────────────────────────────────────────────┘
```

---

## Repository Structure

```text
eks-infra-creation/
├── .github/
│   └── workflows/
│       ├── terraform-plan.yml      # Runs on PRs — fmt, validate, plan + PR comment
│       ├── terraform-apply.yml     # Runs on push to main — dev → staging → prod
│       └── terraform-destroy.yml  # Manual only — requires "destroy" confirmation
│
├── terraform/
│   ├── modules/
│   │   ├── vpc/                   # VPC, subnets, NAT GWs, flow logs
│   │   ├── eks/                   # EKS cluster, KMS, OIDC, CloudWatch logs
│   │   ├── node-group/            # Managed node groups, launch templates, IAM
│   │   └── addons/                # EKS managed add-ons with IRSA roles
│   │
│   └── environments/
│       ├── dev/                   # Single NAT GW, spot nodes, 7-day logs
│       ├── staging/               # Single NAT GW, mixed nodes, 30-day logs
│       └── prod/                  # Multi NAT GW, system+app+spot nodes, 90-day logs
│
├── scripts/
│   ├── bootstrap.sh               # Create S3 bucket + DynamoDB table for state
│   ├── setup-github-oidc.sh       # Create GitHub Actions OIDC roles in AWS
│   └── update-kubeconfig.sh       # Update ~/.kube/config after apply
│
├── .gitignore
└── README.md
```

---

## Environment Comparison

| Feature | dev | staging | prod |
| ------- | --- | ------- | ---- |
| AZ count | 2 | 2 | 3 |
| NAT Gateways | 1 | 1 | 3 |
| VPC CIDR | 10.2.0.0/16 | 10.1.0.0/16 | 10.0.0.0/16 |
| Node groups | 1 (spot) | 2 | 3 (system + app + spot) |
| Instance type | t3.medium | m5.large | m5.xlarge |
| VPC flow logs | No | Yes | Yes |
| Log retention | 7 days | 30 days | 90 days |
| Deployment gate | Auto | After dev | Manual approval |

---

## Prerequisites

| Tool | Version | Purpose |
| ---- | ------- | ------- |
| [Terraform](https://developer.hashicorp.com/terraform/downloads) | >= 1.5 | Infrastructure provisioning |
| [AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html) | >= 2.x | AWS authentication |
| [kubectl](https://kubernetes.io/docs/tasks/tools/) | >= 1.28 | Cluster interaction |
| [git](https://git-scm.com/) | any | Version control |

---

## Quick Start

### 1. Bootstrap the Terraform backend

Run once per AWS account to create the S3 state bucket and DynamoDB lock table:

```bash
chmod +x scripts/*.sh
./scripts/bootstrap.sh us-east-1 daas
```

The script outputs the bucket name. Update the `bucket` value in each environment's `main.tf`:

```bash
sed -i "s/REPLACE_WITH_YOUR_STATE_BUCKET/<your-bucket-name>/g" \
  terraform/environments/*/main.tf
```

### 2. Set up GitHub Actions OIDC (keyless AWS auth)

```bash
./scripts/setup-github-oidc.sh <github-org> <github-repo>
```

This creates three IAM roles and prints the ARNs. Add them as GitHub repository secrets:

| Secret name | Value |
| ----------- | ----- |
| `AWS_ROLE_ARN_DEV` | `arn:aws:iam::<account>:role/github-actions-eks-dev` |
| `AWS_ROLE_ARN_STAGING` | `arn:aws:iam::<account>:role/github-actions-eks-staging` |
| `AWS_ROLE_ARN_PROD` | `arn:aws:iam::<account>:role/github-actions-eks-prod` |

### 3. Configure GitHub environment protection rules

In your repository → **Settings** → **Environments**, create three environments:
- `dev` — no protection (auto-deploys)
- `staging` — no protection (auto-deploys after dev)
- `prod` — add **Required reviewers** to gate production deploys

### 4. Deploy locally (optional)

```bash
cd terraform/environments/dev
terraform init
terraform plan
terraform apply
```

Update kubeconfig after apply:

```bash
./scripts/update-kubeconfig.sh dev
kubectl get nodes
```

---

## CI/CD Pipeline

### On Pull Request

```
PR opened/updated
       │
       ▼
detect-changes (which environments changed?)
       │
       ▼
terraform fmt check
terraform validate
terraform plan
       │
       ▼
Post plan output as PR comment
```

### On Push to `main`

```
push to main
     │
     ▼
Apply dev  ──── (success) ────►  Apply staging  ──── (manual approval) ────►  Apply prod
```

### Manual Destroy

Triggered via **Actions → Terraform Destroy → Run workflow**. Requires typing `destroy` to confirm.

---

## Module Reference

### `modules/vpc`

Creates a multi-AZ VPC with public and private subnets, NAT gateways, and optional VPC flow logs.

| Variable | Default | Description |
| -------- | ------- | ----------- |
| `cluster_name` | required | Used for resource naming and EKS subnet tags |
| `vpc_cidr` | `10.0.0.0/16` | VPC CIDR block |
| `az_count` | `3` | Number of availability zones (2 or 3) |
| `single_nat_gateway` | `false` | Use one NAT GW (cost savings for non-prod) |
| `enable_flow_logs` | `true` | Enable VPC flow logs to CloudWatch |

**Key outputs:** `vpc_id`, `private_subnet_ids`, `public_subnet_ids`

### `modules/eks`

Creates the EKS control plane with KMS encryption for secrets, OIDC provider for IRSA, and full CloudWatch control plane logging.

| Variable | Default | Description |
| -------- | ------- | ----------- |
| `cluster_version` | `1.29` | Kubernetes version |
| `endpoint_public_access` | `true` | Enable public API endpoint |
| `public_access_cidrs` | `["0.0.0.0/0"]` | Restrict to VPN/office IPs in prod |
| `log_retention_days` | `30` | CloudWatch log group retention |

**Key outputs:** `cluster_name`, `cluster_endpoint`, `oidc_provider_arn`, `kms_key_arn`

### `modules/node-group`

Creates managed node groups with hardened launch templates: IMDSv2 enforced, gp3 EBS with encryption, and detailed monitoring enabled.

| Variable | Description |
| -------- | ----------- |
| `node_groups` | Map of node group configs (see `terraform.tfvars` for schema) |

Node group config schema:
```hcl
node_groups = {
  <name> = {
    instance_types = list(string)   # Multiple types for Spot diversity
    capacity_type  = string         # "ON_DEMAND" or "SPOT"
    desired_size   = number
    min_size       = number
    max_size       = number
    disk_size      = number         # GiB, gp3 volume
    labels         = map(string)    # Kubernetes node labels (optional)
    taints         = list(object)   # Kubernetes taints (optional)
  }
}
```

### `modules/addons`

Installs EKS managed add-ons with IRSA roles:

| Add-on | IRSA role |
| ------ | --------- |
| `vpc-cni` | `AmazonEKS_CNI_Policy` |
| `coredns` | — |
| `kube-proxy` | — |
| `aws-ebs-csi-driver` | `AmazonEBSCSIDriverPolicy` |
| `eks-pod-identity-agent` | — |

---

## Security Highlights

- **No long-lived AWS credentials** — GitHub Actions uses OIDC token exchange
- **KMS encryption** — EKS secrets encrypted at rest with a customer-managed key
- **IMDSv2 enforced** — Prevents SSRF-based credential theft from node metadata API
- **Private node subnets** — Worker nodes have no public IPs; egress via NAT gateway
- **VPC flow logs** — All VPC traffic logged to CloudWatch (prod + staging)
- **Full control plane logging** — All five log types shipped to CloudWatch
- **IRSA** — Add-ons use fine-grained IAM roles bound to Kubernetes service accounts
- **EBS encryption** — All node volumes encrypted by default

---

## Updating EKS Add-on Versions

Find the latest version for your cluster version:

```bash
aws eks describe-addon-versions \
  --kubernetes-version 1.29 \
  --addon-name vpc-cni \
  --query 'addons[0].addonVersions[0].addonVersion' \
  --output text
```

Update the version in the relevant `terraform.tfvars` and open a PR.

---

## Common Operations

### Scale a node group

Edit `desired_size` / `min_size` / `max_size` in the environment's `terraform.tfvars`, then push to trigger a plan + apply.

### Add a new environment

1. Copy `terraform/environments/prod/` to `terraform/environments/<name>/`
2. Update the backend `key`, `environment` default, and `vpc_cidr`
3. Add the environment to the workflow matrix in `.github/workflows/terraform-apply.yml`
4. Create the GitHub environment and add `AWS_ROLE_ARN_<NAME>` as a secret

### Rotating the KMS key

The KMS key has `enable_key_rotation = true`, so AWS rotates the key material automatically each year. No manual action is needed.

---

## Troubleshooting

**`terraform init` fails with 403 on the S3 backend**
Ensure your AWS credentials have `s3:GetObject`, `s3:PutObject`, and `dynamodb:GetItem` / `PutItem` permissions on the state bucket and lock table.

**Nodes not joining the cluster**
Check that the node IAM role ARN is added to the `aws-auth` ConfigMap (EKS does this automatically for managed node groups, but verify with `kubectl describe configmap aws-auth -n kube-system`).

**GitHub Actions OIDC 403**
Verify the trust policy condition uses `StringLike` for the `sub` claim and matches your org/repo exactly.

---

## Contributing

1. Create a feature branch from `main`
2. Make changes to module or environment files
3. Open a PR — the plan workflow will comment the diff automatically
4. Merge after review and plan approval
