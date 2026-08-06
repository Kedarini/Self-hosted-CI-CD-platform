# URL Shortener - Self-Hosted CI/CD Platform

A production-style URL shortener built to demonstrate a complete DevOps
workflow: containerized app → automated testing → CI/CD → infrastructure
as code → monitoring. Not just a toy project this ships to real AWS
infrastructure via Terraform and redeploys automatically on every push.

## Architecture

GitHub push     
        │       
        ▼       
GitHub Actions CI       
├── lint (ruff, auto-fix + commit)      
├── test (pytest, isolated SQLite)      
└── build (Docker image)        
        │       
        ▼       
Deploy (SSH to EC2) ──► docker compose up --build       
        │       
        ▼       
┌─────────────────────────────────────┐     
│ AWS (Terraform-managed)             │     
│ ┌───────────┐      ┌─────────────┐  │     
│ │ EC2 (app) │◄────►│ RDS Postgres│  │         
│ │ + Elastic │      └─────────────┘  │     
│ │ IP        │                       │     
│ └─────┬─────┘                       │     
└───────┼─────────────────────────────┘     
        ▼       
Prometheus ──► Grafana      
        
## Tech stack

- **API**: FastAPI + SQLAlchemy + Pydantic
- **Database**: PostgreSQL (local: Docker, production: AWS RDS)
- **Containerization**: Docker (multi-stage build with `uv`)
- **CI/CD**: GitHub Actions (lint → test → build → deploy)
- **Infrastructure**: Terraform (VPC, EC2, RDS, security groups, Elastic IP)
- **Monitoring**: Prometheus + Grafana

## API endpoints

| Method | Path                   | Description                           |     
|--------|------------------------|---------------------------------------|     
| POST   | `/shorten`             | Create a shortened link               |     
| GET    | `/{short_code}`        | Redirect to the target URL            |     
| GET    | `/stats/{short_code}`  | View click statistics                 |     
| GET    | `/health`              | Health check (DB connectivity)        |     
| GET    | `/metrics`             | Prometheus metrics                    |     

## Getting started (local development)

Requires Docker and [uv](https://docs.astral.sh/uv/).

```bash
# clone and enter the repo
git clone https://github.com/Kedarini/Self-hosted-CI-CD-platform.git
cd Self-hosted-CI-CD-platform

# spin up the app + Postgres + Prometheus + Grafana
docker compose up --build
```

- API: `http://localhost:8000` (docs at `/docs`)
- Prometheus: `http://localhost:9090`
- Grafana: `http://localhost:3000` (login: `admin` / `admin`)

## Running tests

```bash
uv sync
DATABASE_URL="postgresql://placeholder:placeholder@localhost:5432/placeholder" uv run pytest -v
```

Tests run against an in-memory SQLite database, so no live Postgres
connection is required the `DATABASE_URL` above is only needed to
satisfy the app's config on import.

## CI/CD pipeline

Every push to `main` triggers three jobs in sequence:

1. **lint-and-test** - `ruff` auto-fixes style issues and commits them
   back (`[skip ci]` to avoid a loop), then runs the pytest suite
2. **build-image** - builds the Docker image to catch build failures early
3. **deploy** - SSHes into the EC2 instance, pulls the latest code, and
   redeploys with `docker compose -f docker-compose.prod.yml up --build -d`

## Infrastructure (Terraform)

The `terraform/` directory provisions everything needed to run this in
AWS, sized to stay within the free tier:

- VPC with two public subnets (across two AZs, required for RDS)
- Internet Gateway + routing
- Security groups (app: SSH + port 8000; db: Postgres, restricted to the
  app's security group only)
- EC2 (`t3.micro`) with an Elastic IP and a `user_data` script that
  installs Docker, clones the repo, and starts the app automatically
- RDS Postgres (`db.t3.micro`, 20GB)

```bash
cd terraform
terraform init
terraform plan     # review changes before applying
terraform apply
terraform output   # get the EC2 public IP and RDS endpoint
```

Secrets (DB password) are kept out of version control via
`terraform.tfvars` (gitignored) and GitHub Secrets (`EC2_HOST`,
`EC2_SSH_KEY`) for the deploy step.

> **Note:** destroying and recreating the EC2 instance changes nothing
> thanks to the Elastic IP, but if you tear down the whole stack with
> `terraform destroy`, you'll need to update the `EC2_HOST` secret on
> GitHub if you provision a fresh Elastic IP.

## Monitoring

`prometheus-fastapi-instrumentator` exposes request counts, latencies,
and status codes at `/metrics`. Prometheus scrapes this every 15s;
Grafana visualizes it. Example queries used in the dashboard:

- Request rate: `rate(http_requests_total[1m])`
- P95 latency: `histogram_quantile(0.95, rate(http_request_duration_seconds_bucket[5m]))`

## Project structure
.       
├── .github/workflows/ci.yml # CI/CD pipeline       
├── app/        
│ ├── main.py # FastAPI endpoints       
│ ├── models.py # SQLAlchemy models     
│ ├── schemas.py # Pydantic schemas     
│ └── database.py # DB connection/session       
├── grafana     
│ ├── dashboards/url-shortner.json      
│ └── provisioning      
│   ├── dashboards/dashboard.yml        
│   └── datasources/prometheus.yml      
├── tests/test_main.py # pytest suite       
├── terraform/ # AWS infrastructure as code     
│ ├── main.tf       
│ ├── variables.tf      
│ └── outputs.tf        
├── packer/ # (WIP) custom AMI build        
│ └── ubuntu-docker.pkr.hcl     
├── Dockerfile # multi-stage build (uv + FastAPI)       
├── docker-compose.yml # local dev (app + db + monitoring)      
├── docker-compose.prod.yml # production (app only, RDS external)       
├── prometheus.yml # Prometheus scrape config       
└── pyproject.toml / uv.lock        

## Possible improvements

- [ ] Replace SSH-based deploy with AWS Systems Manager Session Manager
- [x] Migrate `@app.on_event("startup")` to FastAPI's `lifespan` handler
- [x] Move secrets to AWS Secrets Manager instead of `user_data`/`.env`
- [ ] Add Kubernetes manifests as an alternative deployment target
- [x] Custom Grafana dashboard provisioned as code
- [x] Pre-built AMI via Packer (in progress, see `packer/`) to speed up
      instance startup instead of installing Docker via `user_data`