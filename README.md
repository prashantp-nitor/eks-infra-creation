# DaaS EKS Infrastructure

Production-grade **Amazon EKS** cluster infrastructure using **Terraform** and **GitHub Actions CI/CD**. Supports three fully isolated environments (dev / staging / prod) backed by reusable modules, keyless AWS authentication via OIDC, and an automated promote-on-green pipeline.

---

## Overview

This project provisions and manages a complete EKS platform from networking to add-ons, following AWS Well-Architected principles:

- **Infrastructure as Code** — all resources defined in versioned Terraform modules
- **Immutable environments** — dev, staging, and prod are separate VPCs and clusters
- **Keyless CI/CD** — GitHub Actions authenticates via OIDC token exchange; no long-lived AWS keys
- **Security by default** — KMS-encrypted secrets, IMDSv2 enforced, private node subnets, IRSA for add-ons
- **Promote-on-green pipeline** — merging to `main` deploys dev → staging → prod (prod requires manual approval)

---

## Architecture

```text
┌──────────────────────────────────────────────────────────────────┐
│                          AWS Account                              │
│                                                                   │
│  ┌─────────────────────────────────────────────────────────────┐  │
│  │                   VPC  (one per environment)                 │  │
│  │                                                             │  │
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐         │  │
│  │  │  Public AZ1 │  │  Public AZ2 │  │  Public AZ3 │  prod   │  │
│  │  │  (NAT GW)   │  │  (NAT GW)   │  │  (NAT GW)   │  only   │  │
│  │  └─────────────┘  └─────────────┘  └─────────────┘         │  │
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐         │  │
│  │  │ Private AZ1 │  │ Private AZ2 │  │ Private AZ3 │         │  │
│  │  │  (Nodes)    │  │  (Nodes)    │  │  (Nodes)    │         │  │
│  │  └─────────────┘  └─────────────┘  └─────────────┘         │  │
│  │                                                             │  │
│  │  ┌───────────────────────────────────────────────────────┐  │  │
│  │  │                    EKS Cluster                        │  │  │
│  │  │                                                       │  │  │
│  │  │  ┌────────────┐  ┌─────────────┐  ┌──────────────┐   │  │  │
│  │  │  │  system    │  │ application │  │     spot     │   │  │  │
│  │  │  │ ON_DEMAND  │  │  ON_DEMAND  │  │     SPOT     │   │  │  │
│  │  │  │ m5.large   │  │ m5.xlarge   │  │ m5.xlarge+   │   │  │  │
│  │  │  │ min: 2     │  │ min: 3      │  │ min: 0       │   │  │  │
│  │  │  └────────────┘  └─────────────┘  └──────────────┘   │  │  │
│  │  │                                                       │  │  │
│  │  │  Add-ons:  vpc-cni  ·  coredns  ·  kube-proxy        │  │  │
│  │  │            aws-ebs-csi-driver  ·  pod-identity        │  │  │
│  │  └───────────────────────────────────────────────────────┘  │  │
│  └─────────────────────────────────────────────────────────────┘  │
│                                                                   │
│  S3 Bucket (Terraform state)  ·  DynamoDB (state lock)  ·  KMS   │
└──────────────────────────────────────────────────────────────────┘
```

---

## Repository Structure

```text
eks-infra-creation/
├── .github/
│   └── workflows/
│       ├── terraform-plan.yml      # PR: fmt + validate + plan + PR comment
│       ├── terraform-apply.yml     # Push to main: dev → staging → prod
│       └── terraform-destroy.yml  # Manual only — requires typing "destroy"
│
├── terraform/
│   ├── modules/
│   │   ├── vpc/                   # VPC, subnets, NAT GWs, flow logs
│   │   ├── eks/                   # EKS cluster, KMS, OIDC, CloudWatch
│   │   ├── node-group/            # Managed node groups, launch templates, IAM
│   │   └── addons/                # EKS managed add-ons + IRSA roles
│   │
│   └── environments/
│       ├── dev/                   # 2 AZ, 1 NAT GW, spot nodes, 7-day logs
│       ├── staging/               # 2 AZ, 1 NAT GW, mixed nodes, 30-day logs
│       └── prod/                  # 3 AZ, 3 NAT GWs, 3 node groups, 90-day logs
│
├── scripts/
│   ├── bootstrap.sh               # Create S3 + DynamoDB for Terraform state
│   ├── setup-github-oidc.sh       # Create OIDC IAM roles (keyless GitHub auth)
│   └── update-kubeconfig.sh       # Update ~/.kube/config after apply
│
├── .gitignore
└── README.md
```

---

## Technology Stack

| Category | Technology | Version | Purpose |
| -------- | ---------- | ------- | ------- |
| **IaC** | Terraform | >= 1.5 | Infrastructure provisioning |
| **Cloud** | AWS EKS | 1.29 | Managed Kubernetes control plane |
| **Networking** | AWS VPC | — | Isolated multi-AZ network |
| **Compute** | EC2 Managed Node Groups | — | Worker node lifecycle |
| **Storage** | AWS EBS (gp3) | — | Persistent volume backing |
| **Encryption** | AWS KMS | — | Secrets encryption at rest |
| **Identity** | IRSA / EKS Pod Identity | — | Fine-grained IAM for pods |
| **Registry** | Amazon ECR / Docker Hub | — | Container image storage |
| **CI/CD** | GitHub Actions | — | Automated plan and apply |
| **Auth** | GitHub OIDC | — | Keyless AWS authentication |
| **State** | S3 + DynamoDB | — | Remote state + locking |
| **Add-ons** | EKS Managed Add-ons | — | vpc-cni, coredns, ebs-csi, etc. |

---

## Environment Comparison

| Feature | dev | staging | prod |
| ------- | --- | ------- | ---- |
| AZ count | 2 | 2 | 3 |
| NAT Gateways | 1 | 1 | 3 |
| VPC CIDR | 10.2.0.0/16 | 10.1.0.0/16 | 10.0.0.0/16 |
| Node groups | 1 (spot) | 2 | 3 (system + app + spot) |
| Instance type | t3.medium (spot) | m5.large | m5.xlarge |
| VPC flow logs | No | Yes | Yes |
| Log retention | 7 days | 30 days | 90 days |
| Deployment gate | Auto | After dev ✅ | Manual approval 🔒 |

---

## CI/CD Pipeline

### On Pull Request — Plan Only

```text
PR opened / updated
        │
        ▼
 detect-changes
 (which environments changed?)
        │
        ▼
 ┌─────────────────────────────┐
 │  terraform fmt  check       │
 │  terraform validate         │
 │  terraform plan -no-color   │
 └──────────────┬──────────────┘
                │
                ▼
     Post plan output as PR comment
     (truncated to 60 KB)
                │
                ▼
        Fail PR if plan failed
```

### On Push to `main` — Promote on Green

```text
git push origin main
        │
        ▼
┌───────────────────┐
│   Apply  dev      │  ← automatic
│   terraform apply │
└────────┬──────────┘
         │ success
         ▼
┌───────────────────┐
│  Apply  staging   │  ← automatic (after dev passes)
│  terraform apply  │
└────────┬──────────┘
         │ success
         ▼
┌───────────────────────────────┐
│   Apply  prod                 │  ← requires manual approval
│   (GitHub environment gate)   │     in GitHub UI
│   terraform apply             │
└───────────────────────────────┘
```

### Manual Destroy

Triggered via **Actions → Terraform Destroy → Run workflow**. Type `destroy` in the confirmation input — the workflow will not proceed without it.

---

## Prerequisites

| Tool | Version | Install |
| ---- | ------- | ------- |
| Terraform | >= 1.5 | [developer.hashicorp.com/terraform/downloads](https://developer.hashicorp.com/terraform/downloads) |
| AWS CLI | >= 2.x | [docs.aws.amazon.com/cli](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html) |
| kubectl | >= 1.28 | [kubernetes.io/docs/tasks/tools](https://kubernetes.io/docs/tasks/tools/) |
| git | any | [git-scm.com](https://git-scm.com/) |

Verify your tools:

```bash
terraform version
aws --version
kubectl version --client
```

---

## Quick Start

### Step 1 — Bootstrap the Terraform backend

Run once per AWS account to create the S3 state bucket and DynamoDB lock table:

```bash
chmod +x scripts/*.sh
./scripts/bootstrap.sh us-east-1 daas
```

Replace the placeholder in every environment's `main.tf` with the printed bucket name:

```bash
# Linux/macOS
sed -i "s/REPLACE_WITH_YOUR_STATE_BUCKET/<your-bucket-name>/g" \
  terraform/environments/*/main.tf

# Windows PowerShell
Get-ChildItem -Path terraform/environments -Recurse -Filter main.tf |
  ForEach-Object { (Get-Content $_.FullName) -replace 'REPLACE_WITH_YOUR_STATE_BUCKET','<your-bucket-name>' | Set-Content $_.FullName }
```

### Step 2 — Set up GitHub Actions OIDC (keyless AWS auth)

```bash
./scripts/setup-github-oidc.sh <github-org> <github-repo>
```

Add the printed IAM role ARNs as GitHub repository secrets:

| Secret name | Value |
| ----------- | ----- |
| `AWS_ROLE_ARN_DEV` | `arn:aws:iam::<account-id>:role/github-actions-eks-dev` |
| `AWS_ROLE_ARN_STAGING` | `arn:aws:iam::<account-id>:role/github-actions-eks-staging` |
| `AWS_ROLE_ARN_PROD` | `arn:aws:iam::<account-id>:role/github-actions-eks-prod` |

### Step 3 — Configure GitHub environment protection rules

In your repository → **Settings → Environments**:

| Environment | Protection |
| ----------- | ---------- |
| `dev` | None — auto-deploys on push to `main` |
| `staging` | None — auto-deploys after `dev` passes |
| `prod` | **Required reviewers** — gates production deploys |

### Step 4 — Deploy manually (optional, to validate locally)

```bash
cd terraform/environments/dev
terraform init
terraform plan
terraform apply
```

Update kubeconfig after the cluster is up:

```bash
./scripts/update-kubeconfig.sh dev
kubectl get nodes
```

---

## Accessing the Cluster

### Update kubeconfig

```bash
# Via the helper script
./scripts/update-kubeconfig.sh <environment>

# Or directly with AWS CLI
aws eks update-kubeconfig \
  --region us-east-1 \
  --name daas-prod-eks \
  --alias eks-prod
```

### Verify cluster access

```bash
kubectl get nodes -o wide
kubectl get pods -A
kubectl cluster-info
```

### Switch between environments

```bash
kubectl config get-contexts
kubectl config use-context eks-prod
kubectl config use-context eks-dev
```

---

## Module Reference

### `modules/vpc`

Multi-AZ VPC with public/private subnets, NAT gateways, and optional VPC flow logs. Subnets are tagged for EKS load balancer discovery.

| Variable | Default | Description |
| -------- | ------- | ----------- |
| `cluster_name` | required | Used for naming and EKS subnet discovery tags |
| `vpc_cidr` | `10.0.0.0/16` | VPC CIDR block |
| `az_count` | `3` | Number of availability zones (2 or 3) |
| `single_nat_gateway` | `false` | Single NAT GW to reduce cost (non-prod only) |
| `enable_flow_logs` | `true` | Ship VPC flow logs to CloudWatch |

**Key outputs:** `vpc_id`, `private_subnet_ids`, `public_subnet_ids`

### `modules/eks`

EKS control plane with KMS-encrypted secrets, OIDC provider for IRSA, and all five control plane log streams shipped to CloudWatch.

| Variable | Default | Description |
| -------- | ------- | ----------- |
| `cluster_version` | `1.29` | Kubernetes version |
| `endpoint_public_access` | `true` | Enable public API server endpoint |
| `public_access_cidrs` | `["0.0.0.0/0"]` | Restrict to VPN/office CIDRs in prod |
| `log_retention_days` | `30` | CloudWatch log group retention |

**Key outputs:** `cluster_name`, `cluster_endpoint`, `oidc_provider_arn`, `kms_key_arn`

### `modules/node-group`

Managed node groups using hardened launch templates. IMDSv2 enforced, gp3 EBS encrypted, and detailed instance monitoring enabled on every node.

Node group config schema:

```hcl
node_groups = {
  <name> = {
    instance_types = list(string)   # Use multiple types for Spot diversity
    capacity_type  = string         # "ON_DEMAND" or "SPOT"
    desired_size   = number
    min_size       = number
    max_size       = number
    disk_size      = number         # GiB — gp3, encrypted
    labels         = map(string)    # optional Kubernetes node labels
    taints         = list(object)   # optional Kubernetes taints
  }
}
```

### `modules/addons`

EKS managed add-ons with per-add-on IRSA roles:

| Add-on | IRSA role |
| ------ | --------- |
| `vpc-cni` | `AmazonEKS_CNI_Policy` |
| `coredns` | — |
| `kube-proxy` | — |
| `aws-ebs-csi-driver` | `AmazonEBSCSIDriverPolicy` |
| `eks-pod-identity-agent` | — |

---

## Security Highlights

### Current Implementation

✅ **No long-lived AWS credentials** — GitHub Actions authenticates via OIDC token exchange
✅ **KMS customer-managed key** — EKS secrets encrypted at rest; key auto-rotates annually
✅ **IMDSv2 enforced** — Prevents SSRF credential theft via node metadata API
✅ **Private node subnets** — Worker nodes have no public IPs; egress via NAT gateway
✅ **VPC flow logs** — All VPC traffic logged to CloudWatch (prod + staging)
✅ **Full control plane logging** — All five log types shipped to CloudWatch
✅ **IRSA per add-on** — Each add-on has a scoped IAM role bound to its service account
✅ **EBS encryption** — All node EBS volumes encrypted at rest

### Recommended Improvements

⚠️ Restrict `public_access_cidrs` to your VPN/office IP ranges in prod
⚠️ Add Kubernetes **Network Policies** to restrict pod-to-pod traffic
⚠️ Deploy **Falco** or **GuardDuty EKS Runtime Monitoring** for threat detection
⚠️ Enable **Amazon Inspector** for continuous ECR image vulnerability scanning
⚠️ Add **Pod Security Admission** to enforce `restricted` standards in prod namespaces
⚠️ Use **AWS Secrets Manager** with External Secrets Operator instead of plain Kubernetes Secrets

---

## Monitoring & Logs

### CloudWatch Container Insights

Enable Container Insights after cluster creation for resource and performance metrics:

```bash
aws eks create-addon \
  --cluster-name daas-prod-eks \
  --addon-name amazon-cloudwatch-observability \
  --region us-east-1
```

### View control plane logs

```bash
# All control plane log groups
aws logs describe-log-groups \
  --log-group-name-prefix "/aws/eks/daas-prod-eks"

# Tail audit logs
aws logs tail /aws/eks/daas-prod-eks/cluster \
  --follow --filter-pattern audit
```

### kubectl observability commands

```bash
# Node resource usage
kubectl top nodes

# Pod resource usage across all namespaces
kubectl top pods -A

# Events sorted by timestamp
kubectl get events -A --sort-by='.lastTimestamp'

# Logs from a deployment
kubectl logs -f deployment/<name> -n <namespace>

# Pod describe (useful for scheduling issues)
kubectl describe pod <pod-name> -n <namespace>
```

---

## Troubleshooting

### Nodes not joining the cluster

```bash
# Check the aws-auth ConfigMap (EKS should auto-populate for managed node groups)
kubectl describe configmap aws-auth -n kube-system

# Check node group status in AWS
aws eks describe-nodegroup \
  --cluster-name daas-prod-eks \
  --nodegroup-name daas-prod-eks-application \
  --region us-east-1 \
  --query nodegroup.status

# View EC2 instance console logs for bootstrap errors
aws ec2 get-console-output --instance-id <id> --output text
```

### Pod stuck in `Pending`

```bash
# Check for scheduling failures (resource pressure, taints)
kubectl describe pod <pod-name> -n <namespace>

# Check node conditions
kubectl get nodes -o wide
kubectl describe node <node-name> | grep -A10 Conditions

# Check if there are any taints blocking scheduling
kubectl get nodes -o json | \
  jq '.items[].spec.taints // empty'
```

### Pod stuck in `ImagePullBackOff`

```bash
# Check event details
kubectl describe pod <pod-name> -n <namespace>

# Verify image exists and is accessible
aws ecr describe-images \
  --repository-name <repo> \
  --region us-east-1

# Check imagePullSecrets if using a private registry
kubectl get secret <pull-secret> -o yaml
```

### `terraform init` fails with S3 403

Ensure your AWS credentials include these permissions on the state bucket:

```
s3:GetObject, s3:PutObject, s3:ListBucket, s3:DeleteObject
dynamodb:GetItem, dynamodb:PutItem, dynamodb:DeleteItem
```

### GitHub Actions OIDC 403 / credential error

1. Verify the role trust policy uses `StringLike` (not `StringEquals`) for the `sub` claim
2. Confirm the `sub` value matches `repo:<org>/<repo>:*`
3. Check `id-token: write` is in the workflow `permissions` block

```bash
# Test the OIDC role assumption locally
aws sts assume-role-with-web-identity \
  --role-arn arn:aws:iam::<account>:role/github-actions-eks-prod \
  --role-session-name test \
  --web-identity-token file://token.txt
```

### Add-on stuck in `DEGRADED`

```bash
# Check add-on status
aws eks describe-addon \
  --cluster-name daas-prod-eks \
  --addon-name vpc-cni \
  --region us-east-1 \
  --query addon.status

# Force update the add-on
aws eks update-addon \
  --cluster-name daas-prod-eks \
  --addon-name vpc-cni \
  --resolve-conflicts OVERWRITE \
  --region us-east-1
```

---

## Common Operations

### Scale a node group

Edit `desired_size` / `min_size` / `max_size` in the environment's `terraform.tfvars`, open a PR, and merge after the plan looks correct.

```bash
# Verify the current state
kubectl get nodes -l role=application
aws eks describe-nodegroup \
  --cluster-name daas-prod-eks \
  --nodegroup-name daas-prod-eks-application \
  --query 'nodegroup.scalingConfig'
```

### Upgrade Kubernetes version

1. Check AWS release calendar for EKS version support dates
2. Update `cluster_version` in `terraform.tfvars` for the target environment
3. Validate with `terraform plan` on a PR (no nodes are touched at plan time)
4. Apply — EKS performs a rolling control plane upgrade, then node groups are updated in place

### Update an add-on version

Find the latest version for your cluster version:

```bash
aws eks describe-addon-versions \
  --kubernetes-version 1.29 \
  --addon-name vpc-cni \
  --query 'addons[0].addonVersions[0].addonVersion' \
  --output text
```

Update the version in the relevant `terraform.tfvars` under `addon_versions`, then push a PR.

### Add a new environment

1. Copy `terraform/environments/prod/` to `terraform/environments/<name>/`
2. Update the `backend` key, `environment` default, and `vpc_cidr`
3. Add the environment to the `apply` workflow in [terraform-apply.yml](.github/workflows/terraform-apply.yml)
4. Create the GitHub environment under **Settings → Environments**
5. Run `./scripts/setup-github-oidc.sh` and add the new `AWS_ROLE_ARN_<NAME>` secret

### Drain a node for maintenance

```bash
# Cordon (stop scheduling) then drain (evict pods gracefully)
kubectl cordon <node-name>
kubectl drain <node-name> --ignore-daemonsets --delete-emptydir-data

# After maintenance, restore scheduling
kubectl uncordon <node-name>
```

---

## Production Best Practices

### Cluster configuration

```yaml
- 3 availability zones for true HA (prod default)
- Separate system node group with CriticalAddonsOnly taint
- Cluster Autoscaler or Karpenter for dynamic node provisioning
- Enable EKS control plane logging for all five log types
- Restrict public API endpoint to known CIDR ranges
```

### Node group configuration

```yaml
- IMDSv2 enforced on all launch templates (already enabled)
- gp3 volumes with encryption at rest (already enabled)
- Spot diversity: 3-4 instance families to reduce interruption risk
- Keep system nodes ON_DEMAND; use Spot for stateless application workloads
- SSM agent enabled for shell-less node access (AmazonSSMManagedInstanceCore attached)
```

### Storage

```yaml
- Use EBS gp3 volumes (lower cost, better IOPS than gp2)
- Set EBS volume reclaim policy to Retain for stateful workloads
- Use EFS (via aws-efs-csi-driver) for ReadWriteMany access patterns
- Tag PVs with environment and application for cost attribution
```

### Networking

```yaml
- EKS nodes in private subnets (no public IPs)
- Network Policies to restrict east-west traffic between namespaces
- AWS Load Balancer Controller for NLB/ALB ingress (deploy separately via Helm)
- VPC flow logs enabled in staging and prod for forensics
```

### Security

```yaml
- Rotate KMS key material via enable_key_rotation = true (already set)
- Enable Amazon GuardDuty EKS Runtime Monitoring
- Use AWS Secrets Manager + External Secrets Operator for application secrets
- Apply Pod Security Admission: enforce restricted in prod namespaces
- Enable AWS Config rules for EKS compliance drift detection
```

### Cost optimisation

```yaml
- Spot instances for stateless, interruption-tolerant workloads
- Single NAT gateway in dev and staging (already configured)
- Enable resource requests and limits on all pods to avoid over-provisioning
- Use Cluster Autoscaler min=0 on spot groups to scale to zero overnight in dev
```

---

## FAQ

**Q: How do I access a node without SSH?**
A: Nodes have SSM agent installed (`AmazonSSMManagedInstanceCore` policy attached). Use `aws ssm start-session --target <instance-id>` — no key pairs or open ports required.

**Q: How do I create an IAM role for my application pods?**
A: Create an IAM role with an OIDC trust policy condition pointing to the cluster's OIDC issuer and your pod's service account. Use the `oidc_provider_arn` output from the EKS module as the trusted federated principal.

**Q: Can I use multiple AWS accounts (dev in account A, prod in account B)?**
A: Yes. Create separate `AWS_ROLE_ARN_*` secrets pointing to roles in each account. Run `./scripts/bootstrap.sh` and `./scripts/setup-github-oidc.sh` once per account.

**Q: The cluster upgrade failed halfway through — what do I do?**
A: EKS control plane upgrades are managed by AWS and are atomic. Node group upgrades can be retried. Run `terraform plan` to see the current state diff, then `terraform apply` to resume. Check the EKS console for the upgrade error reason first.

**Q: How do I restrict who can deploy to prod?**
A: Add required reviewers to the `prod` GitHub environment (Settings → Environments → prod → Required reviewers). The apply workflow will pause and wait for approval before running `terraform apply` against prod.

**Q: Can I use Karpenter instead of managed node groups?**
A: Yes. Replace the `node-group` module with a Karpenter `NodePool` and `NodeClass` configuration. Remove the `aws_eks_node_group` resources and deploy Karpenter via Helm as an additional add-on. The VPC and EKS modules remain unchanged.

**Q: Why are the node group `desired_size` changes ignored after initial creation?**
A: `lifecycle { ignore_changes = [scaling_config[0].desired_size] }` is intentionally set so Cluster Autoscaler can manage the desired count without Terraform reverting it on every apply.

---

## Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/your-feature`)
3. Make changes to module or environment files
4. Open a PR — the plan workflow runs automatically and posts the diff as a comment
5. Get the plan reviewed, then merge
6. The apply workflow promotes through dev → staging → prod

---

## Additional Resources

- [Amazon EKS Best Practices Guide](https://aws.github.io/aws-eks-best-practices/)
- [Terraform AWS EKS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/eks_cluster)
- [GitHub Actions OIDC with AWS](https://docs.github.com/en/actions/security-for-github-actions/security-hardening-your-deployments/configuring-openid-connect-in-amazon-web-services)
- [EKS Managed Add-ons versions](https://docs.aws.amazon.com/eks/latest/userguide/eks-add-ons.html)
- [IRSA (IAM Roles for Service Accounts)](https://docs.aws.amazon.com/eks/latest/userguide/iam-roles-for-service-accounts.html)
- [Cluster Autoscaler on EKS](https://github.com/kubernetes/autoscaler/blob/master/cluster-autoscaler/cloudprovider/aws/README.md)

---

**Last updated:** May 2026
**Maintainer:** Prashant Powar
**Version:** 1.0.0
