# Deployment Guide

This document describes how to deploy Like2Share (BuzzCart) to different environments.

## Table of Contents
- [Environment Overview](#environment-overview)
- [Prerequisites](#prerequisites)
- [Local Development](#local-development)
- [Staging Deployment](#staging-deployment)
- [Production Deployment](#production-deployment)
- [Rollback Procedures](#rollback-procedures)

---

## Environment Overview

We maintain three environments:

| Environment | Branch/Tag | Auto-Deploy | URL |
|------------|-----------|-------------|-----|
| **Development** | `feature/*` | No | `http://localhost:*` |
| **Staging** | `main` | Yes (on merge) | `https://staging.yourdomain.com` |
| **Production** | `v*.*.*` tags | Yes (with approval) | `https://yourdomain.com` |

---

## Prerequisites

### For All Deployments
- [ ] MongoDB instance (local, Atlas, or self-hosted)
- [ ] Node.js 20+ and Python 3.11+
- [ ] Git repository access
- [ ] Required API keys (Emergent LLM, OpenAI, etc.)

### For Production
- [ ] Domain name configured
- [ ] SSL certificates (via Let's Encrypt or provider)
- [ ] CDN setup (CloudFlare, CloudFront, etc.)
- [ ] Backup strategy in place
- [ ] Monitoring tools configured

---

## Local Development

### 1. Clone and Setup

```bash
git clone https://github.com/your-org/Like2Share.git
cd Like2Share
```

### 2. Backend Setup

```bash
cd webapp/backend

# Copy environment template
cp .env.example .env

# Edit .env with your local values
# MONGO_URL=mongodb://localhost:27017
# DB_NAME=buzz_social_cart_dev
# JWT_SECRET=your-local-secret
# EMERGENT_LLM_KEY=your-key

# Install dependencies
pip install -r requirements.txt

# Run migrations
python migrate.py

# Start server
python server.py
```

Backend runs on: `http://localhost:8000`

### 3. Frontend Setup

```bash
cd webapp/frontend

# Copy environment template
cp .env.example .env

# Edit .env
# VITE_BACKEND_URL=http://localhost:8000

# Install dependencies
npm install

# Start dev server
npm run dev
```

Frontend runs on: `http://localhost:5173`

### 4. Flutter App (Optional)

```bash
cd frontend

# Get dependencies
flutter pub get

# Run on your platform
flutter run -d windows  # or macos, linux, chrome
```

---

## Staging Deployment

### Automated (Recommended)

Staging auto-deploys when PRs are merged to `main`:

```bash
# 1. Create feature branch
git checkout -b feature/your-feature

# 2. Make changes and commit
git add .
git commit -m "feat: your feature"

# 3. Push and create PR
git push origin feature/your-feature

# 4. Get PR approved and merge
# → Staging deploys automatically via GitHub Actions
```

### Manual Deployment

If needed, trigger staging deployment manually:

1. Go to **Actions** tab on GitHub
2. Select **Deploy to Staging** workflow
3. Click **Run workflow**
4. Select `main` branch
5. Click **Run workflow**

### Staging Secrets (Configure in GitHub)

Go to `Settings → Environments → staging` and add:

```
STAGING_MONGO_URL=mongodb+srv://user:pass@cluster.mongodb.net/
STAGING_DB_NAME=buzz_social_cart_staging
STAGING_BACKEND_URL=https://api-staging.yourdomain.com
JWT_SECRET=<generate-secure-random-string>
EMERGENT_LLM_KEY=<your-key>
```

---

## Production Deployment

### Release Process (Tagged Releases)

Production deploys **only** from version tags with approval gates:

```bash
# 1. Ensure main is stable and tested in staging
git checkout main
git pull origin main

# 2. Create and push version tag
git tag -a v1.0.0 -m "Release v1.0.0: Initial production release"
git push origin v1.0.0

# 3. GitHub Actions workflow starts
#    → Requires approval from @admins team
#    → Deploys backend → frontend
#    → Creates GitHub release
```

### Approval Process

1. Tag triggers **Deploy to Production** workflow
2. Workflow pauses at **production** environment gate
3. Designated reviewers get notification
4. Reviewers approve/reject deployment
5. On approval, deployment proceeds automatically

### Production Secrets (Configure in GitHub)

Go to `Settings → Environments → production` and add:

```
PROD_MONGO_URL=mongodb+srv://user:pass@prod-cluster.mongodb.net/
PROD_DB_NAME=buzz_social_cart_prod
PROD_BACKEND_URL=https://api.yourdomain.com
JWT_SECRET=<secure-random-string-different-from-staging>
EMERGENT_LLM_KEY=<your-production-key>
CORS_ORIGINS=https://yourdomain.com
```

**Required Reviewers:** Set to your admin team/users

---

## Rollback Procedures

### Quick Rollback (Re-deploy previous version)

```bash
# 1. Find previous stable tag
git tag -l

# 2. Re-push the tag to trigger deployment
git push origin --delete v1.2.0  # delete failed version
git push origin v1.1.0           # re-trigger previous version
```

### Manual Rollback

If automated rollback fails:

```bash
# 1. SSH to production server
ssh user@production-server

# 2. Navigate to deployment directory
cd /var/www/buzzcart

# 3. Check previous releases
ls -la releases/

# 4. Symlink to previous release
ln -sfn releases/v1.1.0 current

# 5. Restart services
sudo systemctl restart buzzcart-backend
sudo systemctl restart nginx
```

### Database Rollback

⚠️ **Dangerous!** Only if migration failed:

```bash
# Use migration tool to rollback
python migrate.py rollback --version <previous-version>

# Or restore from backup
mongorestore --uri="mongodb+srv://..." --db=buzz_social_cart_prod dump/
```

---

## Health Checks & Monitoring

### Automated Health Checks

After deployment, workflows check:
- Backend API: `GET /api/health`
- Frontend: HTTP 200 on homepage
- Database connectivity

### Manual Verification

```bash
# Backend health
curl https://api.yourdomain.com/api/health

# Frontend
curl -I https://yourdomain.com

# Database connection
mongosh "mongodb+srv://..." --eval "db.runCommand({ ping: 1 })"
```

---

## Troubleshooting

### Deployment Failed

1. Check GitHub Actions logs
2. Review error messages
3. Common issues:
   - Missing environment secrets
   - Database connection failure
   - Build errors (check CI logs)

### Environment Variables Not Working

```bash
# Verify secrets are set in GitHub
Settings → Environments → [env] → Environment secrets

# Check workflow uses correct secret names
cat .github/workflows/deploy-*.yml
```

### Database Connection Issues

```bash
# Test connection locally
mongosh "mongodb+srv://user:pass@cluster.mongodb.net/dbname"

# Check IP whitelist (if using MongoDB Atlas)
# Add GitHub Actions IPs or allow all (0.0.0.0/0) for testing
```

---

## CI/CD Pipeline Details

### Pull Request Flow
1. Developer creates PR from `feature/*` → `main`
2. CI runs:
   - Backend: Lint (flake8, black) + Tests
   - Frontend: Lint (ESLint) + Build
   - Flutter: Analyze + Tests
3. Reviewers approve
4. Squash merge to `main`
5. Staging auto-deploys

### Production Release Flow
1. Create tag: `git tag v1.0.0`
2. Push tag: `git push origin v1.0.0`
3. Workflow starts, pauses for approval
4. Admins approve
5. Deploys backend + frontend
6. Creates GitHub Release
7. Sends notification

---

## Additional Resources

- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [Branch Protection Rules](https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-protected-branches)
- [Environment Secrets](https://docs.github.com/en/actions/deployment/targeting-different-environments/using-environments-for-deployment)
- [MongoDB Atlas](https://www.mongodb.com/atlas)

---

## Support

For deployment issues:
1. Check this guide
2. Review GitHub Actions logs
3. Contact DevOps team: devops@yourdomain.com
4. Emergency: Slack #incidents channel
