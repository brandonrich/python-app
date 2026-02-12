# GitHub Actions Workflows

This directory contains GitHub Actions workflows for CI/CD automation. These workflows demonstrate the same pipeline stages as the Jenkins implementation, plus additional deployment and rollback capabilities.

## Workflows

### `ci.yml` - Continuous Integration Pipeline

**Triggers:** Push to main/github-actions branches, pull requests to main

**Jobs:**
1. **lint-and-test** - Runs linting (Ruff), security scanning (Bandit), and unit tests (pytest)
2. **build-and-push** - Builds Docker image, pushes to GitHub Container Registry, and scans with Trivy

**Features:**
- Python dependency caching for faster builds
- Docker layer caching for faster image builds
- JUnit test result publishing
- Security vulnerability scanning with results in GitHub Security tab
- Multi-tag strategy (SHA, branch, PR number, latest)

**Registry:** GitHub Container Registry (ghcr.io) with automatic authentication via GITHUB_TOKEN

### `deploy.yml` - Environment Deployment

**Triggers:** Manual (`workflow_dispatch`) with environment and image tag selection

**Jobs:**
1. **deploy** - Deploys specified image tag to chosen environment

**Features:**
- Environment-specific configuration (ports, variables)
- GitHub environment protection rules (staging vs production)
- Manual approval gates for production deployments
- Health check validation
- Deployment URL tracking

**Environments:**
- `staging` - No protection rules, deploys to port 5002
- `production` - Requires approvals, deploys to port 5001

### `rollback.yml` - Deployment Rollback

**Triggers:** Manual (`workflow_dispatch`) with environment and previous image tag selection

**Jobs:**
1. **rollback** - Reverts to specified previous image version

**Features:**
- Image existence verification before rollback
- Current state backup
- Health check after rollback
- Same environment protection rules as deployment

## Authentication

All workflows use GitHub's built-in `GITHUB_TOKEN`, which provides:
- Read access to repository contents
- Write access to GitHub Container Registry (`packages: write` permission)
- Time-limited token that expires when the workflow completes

No manual credential configuration needed. No secrets to rotate.

## Usage

### Running CI

CI runs automatically on push and pull requests. To trigger manually:
1. Go to Actions tab
2. Select "CI Pipeline"
3. Click "Run workflow"

### Deploying to Staging

1. Go to Actions tab
2. Select "Deploy to Environment"
3. Click "Run workflow"
4. Select `staging` environment
5. Enter image tag (e.g., `main-abc1234` or `latest`)
6. Click "Run workflow"

Deployment proceeds immediately (no approval required for staging).

### Deploying to Production

1. Go to Actions tab
2. Select "Deploy to Environment"
3. Click "Run workflow"
4. Select `production` environment
5. Enter image tag (should be a specific SHA tag from staging validation)
6. Click "Run workflow"
7. Wait for required reviewers to approve
8. Deployment proceeds after approval and wait timer

### Rolling Back

1. Go to Actions tab → Environments → [environment] to find previous working version
2. Select "Rollback Deployment"
3. Click "Run workflow"
4. Select environment
5. Enter previous image tag
6. Click "Run workflow"
7. Approve if production (same protection rules as deployment)

## Environment Configuration

Set up environments in repository Settings → Environments:

**Staging:**
- No required reviewers
- No deployment branches restriction
- No wait timer

**Production:**
- Required reviewers: 2 team members
- Deployment branches: `main` only
- Wait timer: 5 minutes

## Image Tags

The CI workflow generates multiple tags for each build:

- `latest` - Always points to most recent main branch build
- `main-abc1234` - Branch name + git SHA (immutable, traceable)
- `pr-42` - Pull request number (for testing PRs before merge)

For production deployments, always use SHA-based tags (e.g., `main-abc1234`), not `latest`. This ensures you can roll back to specific versions and trace deployments to commits.

## Comparison to Jenkins

| Aspect | Jenkins | GitHub Actions |
|--------|---------|----------------|
| **Location** | `Jenkinsfile` in repo root | `.github/workflows/*.yml` |
| **Syntax** | Groovy | YAML |
| **Triggers** | pollSCM (5-min delay) | Native GitHub events (instant) |
| **Infrastructure** | Self-hosted | Cloud-hosted by GitHub |
| **Registry** | Docker Hub (manual credentials) | ghcr.io (automatic auth) |
| **Approvals** | Manual stages in pipeline | Environment protection rules |
| **Secrets** | Jenkins credential store | Repository/organization secrets |

Both achieve the same outcome (tested, deployed artifact), but GitHub Actions provides tighter GitHub integration and eliminates infrastructure management.

## Security Notes

- Never commit secrets to workflow files
- Use repository secrets for third-party credentials
- Use OIDC federation for cloud provider access when possible
- Limit `packages: write` permission to jobs that actually push images
- Review environment protection rules regularly
- Audit deployment history via Environments page

## Extending the Workflows

Common additions:

- **Notifications:** Slack/email on deployment success/failure
- **Performance tests:** Load testing after staging deployment
- **Database migrations:** Run migrations before deploying new code
- **Smoke tests:** Comprehensive post-deployment validation
- **Canary deployments:** Gradual traffic shifting with monitoring
- **Automated rollback:** Monitor metrics and rollback on threshold breach
