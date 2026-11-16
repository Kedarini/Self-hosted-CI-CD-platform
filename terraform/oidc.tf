# ==============================================================================
# AUTHENTICATION IN FLOCI (LOCAL MODE)
# ==============================================================================
# This project is adapted to run against Floci (local AWS emulator) only.
# In local emulation we do not use GitHub Actions OIDC federation with real AWS.
# Instead, Terraform, AWS CLI, and CI jobs authenticate with test credentials and
# a local endpoint (http://localhost:4566), e.g.:
#   AWS_ACCESS_KEY_ID=test
#   AWS_SECRET_ACCESS_KEY=test
#   AWS_DEFAULT_REGION=us-east-1
#   AWS_ENDPOINT_URL=http://localhost:4566
#
# The original GitHub OIDC -> AWS role flow is intentionally not provisioned here
# because "only Floci" means no dependency on real AWS IAM OIDC providers or
# GitHub-issued federation into a real cloud account.
# ==============================================================================