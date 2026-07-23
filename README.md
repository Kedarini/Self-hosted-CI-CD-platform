# URL Shortener API project skeleton

Base for a DevOps project: Docker → CI/CD → Terraform/AWS → monitoring.
Logic is left for you to implement files contain TODO comments pointing
out what's needed and roughly how.

## Endpoints to implement

| Method | Path                    | Description                              |
|--------|---------------------------|---------------------------------------------|
| POST   | `/shorten`                 | Create a shortened link                     |
| GET    | `/{short_code}`            | Redirect to the target URL                   |
| GET    | `/stats/{short_code}`      | Stats (click count)                          |
| GET    | `/health`                  | Health check (for load balancer/k8s)         |
| GET    | `/metrics`                 | Prometheus metrics (bonus, add later)        |

## Checklist

- [x] `app/database.py` - Postgres connection via SQLAlchemy
- [ ] `app/models.py` - `URL` model
- [ ] `app/schemas.py` - Pydantic schemas
- [ ] `app/main.py` - endpoints
- [ ] `tests/test_main.py` - pytest tests
- [x] `Dockerfile`
- [x] `docker-compose.yml`
- [ ] `.github/workflows/ci.yml`
- [ ] Terraform: VPC, EC2/ECS, RDS (separate step, once the app works locally)
- [ ] CD: deploy from Actions on merge to `main`
- [ ] Monitoring: Prometheus + Grafana

## Structure

```
url-shortener/
├── app/
│   ├── __init__.py
│   ├── main.py          # FastAPI endpoints
│   ├── models.py         # SQLAlchemy model
│   ├── schemas.py         # Pydantic validation
│   └── database.py        # DB connection
├── tests/
│   └── test_main.py
├── .github/workflows/ci.yml
├── Dockerfile
├── docker-compose.yml
└── requirements.txt
```