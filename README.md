# URL Shortener — Self-Hosted CI/CD Platform

A production-style URL shortener built to demonstrate a complete DevOps
workflow: containerized app → automated testing → CI/CD → infrastructure
as code → monitoring → container orchestration. Not just a toy project —
this ships to real AWS infrastructure via Terraform and redeploys
automatically on every push, with zero secrets ever touching disk or
version control.

## Architecture

```
GitHub push
    │
    ▼
GitHub Actions CI
    ├── lint (ruff, auto-fix + commit)
    ├── test (pytest, isolated SQLite)
    └── build & push image to ECR
    │
    ▼
Deploy (AWS SSM, no SSH) ──► pulls secrets at runtime, restarts container
    │
    ▼
┌──────────────────────────────────────────────────┐
│  AWS (Terraform-managed)                         │
│  ┌───────────┐      ┌─────────────┐              │
│  │ EC2 (app) │◄────►│ RDS Postgres│              │
│  │ + Elastic │      └─────────────┘              │
│  │    IP     │      ┌─────────────────┐          │
│  └─────┬─────┘◄────►│ Secrets Manager │          │
│        │            └─────────────────┘          │
│        │            ┌─────────────┐              │
│        └───────────►│ ECR (images)│              │
│                     └─────────────┘              │
└──────────────────────────────────────────────────┘
         ▼
   Prometheus ──► Grafana (dashboards provisioned as code)
```

Custom AMI (Docker + AWS CLI + SSM Agent preinstalled) is built with
**Packer**, so new instances boot ready to run without waiting on
`user_data` to install packages.

An alternative deployment target — **Kubernetes** — lives in `k8s/`,
running the same container image on a local cluster (minikube).

## Tech stack

- **API**: FastAPI + SQLAlchemy + Pydantic
- **Database**: PostgreSQL (local: Docker, production: AWS RDS)
- **Containerization**: Docker (multi-stage build with `uv`), images in AWS ECR
- **CI/CD**: GitHub Actions (lint → test → build/push → deploy via SSM)
- **Infrastructure**: Terraform (VPC, EC2, RDS, ECR, IAM, Secrets Manager, Elastic IP)
- **Image baking**: Packer (custom Ubuntu + Docker AMI)
- **Orchestration (alt.)**: Kubernetes manifests (Deployments, Services, ConfigMap/Secret, probes)
- **Monitoring**: Prometheus + Grafana (dashboards & datasources provisioned as code)

## API endpoints

| Method | Path                   | Description                           |
|--------|------------------------|----------------------------------------|
| POST   | `/shorten`              | Create a shortened link                |
| GET    | `/{short_code}`         | Redirect to the target URL             |
| GET    | `/stats/{short_code}`   | View click statistics                  |
| GET    | `/health`               | Health check (DB connectivity)         |
| GET    | `/metrics`              | Prometheus metrics                     |

## Getting started (local development)

Requires Docker and [uv](https://docs.astral.sh/uv/).

```bash
git clone https://github.com/Kedarini/Self-hosted-CI-CD-platform.git
cd Self-hosted-CI-CD-platform

# spin up the app + Postgres + Prometheus + Grafana
docker compose up --build
```

- API: `http://localhost:8000` (docs at `/docs`)
- Prometheus: `http://localhost:9090`
- Grafana: `http://localhost:3000` (login: `admin` / `admin`, provisioned dashboard included)

## Running tests

```bash
uv sync
DATABASE_URL="postgresql://placeholder:placeholder@localhost:5432/placeholder" uv run pytest -v
```

Tests run against an in-memory SQLite database, so no live Postgres
connection is required — the `DATABASE_URL` above only satisfies the
app's config on import.

## CI/CD pipeline

Every push to `main` triggers three jobs in sequence:

1. **lint-and-test** — `ruff` checks style, then runs the pytest suite
2. **build-and-push** — builds the Docker image and pushes it to Amazon ECR
3. **deploy** — sends a command to the EC2 instance via **AWS Systems
   Manager** (no SSH, no open port 22): it pulls the latest code, fetches
   the DB password and Grafana password from **Secrets Manager** and the
   RDS endpoint via the AWS API at runtime, logs into ECR, and redeploys
   with `docker compose -f docker-compose.prod.yml up -d`. No secret is
   ever written to disk.

## Infrastructure (Terraform)

The `terraform/` directory provisions everything needed to run this in
AWS, sized to stay within the free tier:

- VPC with two public subnets (across two AZs, required for RDS)
- Internet Gateway + routing
- Security groups (app: port 8000 only; db: Postgres, restricted to the
  app's security group only — no SSH ingress at all)
- EC2 (`t3.micro`) with an Elastic IP, running a custom Packer-built AMI
- RDS Postgres (`db.t3.micro`, 20GB)
- ECR repository (with a lifecycle policy keeping only the 3 latest images)
- IAM role for the EC2 instance (ECR pull, Secrets Manager read, RDS
  describe, SSM — no long-lived credentials on the instance)
- Two secrets in AWS Secrets Manager (DB password, Grafana password)

```bash
cd terraform
terraform init
terraform plan     # review changes before applying
terraform apply
terraform output   # get the EC2 public IP and RDS endpoint
```

The DB/Grafana passwords are set once via `terraform.tfvars` (gitignored)
and stored in Secrets Manager — the running instance and the CI/CD
pipeline both fetch them at runtime via the AWS API, so they never touch
`.env` files or GitHub Secrets.

> **Note:** thanks to the Elastic IP, the app's address never changes
> across `terraform apply` runs, even if the EC2 instance itself is
> replaced (e.g. after an AMI update).

## Custom AMI (Packer)

`packer/ubuntu-docker.pkr.hcl` bakes a Ubuntu 22.04 image with Docker,
the AWS CLI, and the SSM Agent preinstalled, so new EC2 instances are
ready to run immediately rather than installing packages on every boot.

```bash
cd packer
packer build ubuntu-docker.pkr.hcl
```

Terraform's `data "aws_ami" "custom_ubuntu"` automatically picks up the
most recent build.

## Kubernetes (alternative deployment)

The same container image also runs on Kubernetes — a full local stack
(app + Postgres + health probes) via `k8s/`:

```bash
minikube start
kubectl create secret docker-registry ecr-secret \
  --docker-server=<your-ecr-registry> \
  --docker-username=AWS \
  --docker-password=$(aws ecr get-login-password --region eu-central-1)

kubectl apply -f k8s/
kubectl get pods
minikube service url-shortener-service --url
```

Includes: `Deployment` (2 replicas, liveness/readiness probes hitting
`/health`), `Service` (`NodePort` for the app, `ClusterIP` for Postgres),
`ConfigMap` for non-sensitive config, and a `PersistentVolumeClaim` for
Postgres data. `k8s/secret.yaml` is gitignored — create it locally with
your own base64-encoded DB password.

## Monitoring

`prometheus-fastapi-instrumentator` exposes request counts, latencies,
and status codes at `/metrics`. Prometheus scrapes this every 15s;
Grafana visualizes it — both the datasource and the dashboard are
provisioned as code (`grafana/provisioning/`), so they load automatically
on startup, no manual clicking required.

Example queries used in the dashboard:

- Request rate: `rate(http_requests_total[1m])`
- P95 latency: `histogram_quantile(0.95, rate(http_request_duration_seconds_bucket[5m]))`

## Project structure

```
.
├── .github/workflows/ci.yml       # CI/CD pipeline
├── app/
│   ├── main.py                     # FastAPI endpoints
│   ├── models.py                    # SQLAlchemy models
│   ├── schemas.py                    # Pydantic schemas
│   └── database.py                   # DB connection/session
├── tests/test_main.py               # pytest suite
├── terraform/                       # AWS infrastructure as code
│   ├── main.tf
│   ├── variables.tf
│   └── outputs.tf
├── packer/                          # custom AMI build
│   └── ubuntu-docker.pkr.hcl
├── k8s/                             # Kubernetes manifests (alt. deployment)
│   ├── app-deployment.yaml
│   ├── app-service.yaml
│   ├── postgres-deployment.yaml
│   ├── postgres-service.yaml
│   ├── postgres-pvc.yaml
│   ├── configmap.yaml
│   └── secret.yaml                   # gitignored
├── grafana/
│   ├── dashboards/url-shortener.json
│   └── provisioning/
│       ├── dashboards/dashboard.yml
│       └── datasources/prometheus.yml
├── Dockerfile                       # multi-stage build (uv + FastAPI)
├── docker-compose.yml                # local dev (app + db + monitoring)
├── docker-compose.prod.yml           # production (app only, RDS/ECR external)
├── prometheus.yml                    # Prometheus scrape config
└── pyproject.toml / uv.lock
```

## Possible improvements

- [ ] Automate ECR `imagePullSecret` refresh in Kubernetes (token expires after 12h)
- [ ] Add Terraform module for EKS as a managed alternative to minikube
- [ ] Restrict app security group's port 8000 behind a load balancer / CDN
- [ ] Add Horizontal Pod Autoscaler for the K8s deployment
- [ ] Remote Terraform state (S3 + DynamoDB lock) instead of local state