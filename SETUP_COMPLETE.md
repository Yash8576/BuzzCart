# Like2Share (BuzzCart) - Dev/Staging/Prod Setup

## ✅ Setup Complete!

Your repository now has a complete dev/staging/prod infrastructure with:

### 🔐 Security (CRITICAL - COMPLETED)
- ✅ `.gitignore` configured to exclude `.env` files
- ✅ `.env.example` templates created for all services
- ✅ `SECURITY.md` with immediate action items
- ✅ Secret scanning workflow added

### 🔄 CI/CD Pipeline
- ✅ **ci.yml**: Runs on all PRs (lint, test, build)
- ✅ **deploy-staging.yml**: Auto-deploys when merged to `main`
- ✅ **deploy-production.yml**: Deploys on version tags (`v*.*.*`) with approval
- ✅ **security.yml**: Weekly vulnerability scans

### 📋 Documentation
- ✅ **DEPLOYMENT.md**: Complete deployment guide
- ✅ **CONTRIBUTING.md**: Developer workflow and standards
- ✅ **BRANCH_PROTECTION_SETUP.md**: Step-by-step GitHub setup
- ✅ **SECURITY.md**: Security best practices and incident response
- ✅ **CODEOWNERS**: Code ownership for teams

---

## 🚨 IMMEDIATE ACTIONS REQUIRED

### 1. Secure Your Secrets (DO THIS NOW!)

```bash
# Check if .env files are committed to git
git log --all --full-history -- "**/.env"

# If yes, follow steps in SECURITY.md to:
# 1. Remove from history
# 2. Rotate ALL secrets
# 3. Update .env files with new values
```

**Read:** [SECURITY.md](SECURITY.md) for detailed instructions.

### 2. Setup GitHub Branch Protection

Follow the guide: [BRANCH_PROTECTION_SETUP.md](BRANCH_PROTECTION_SETUP.md)

Quick steps:
1. Go to **Settings → Branches**
2. Add rule for `main` branch:
   - ✅ Require pull request (1 approval)
   - ✅ Require status checks (CI jobs)
   - ✅ Prevent force pushes
   - ✅ Apply to administrators

### 3. Configure GitHub Environments

**Staging Environment:**
```
Name: staging
Protection: None (auto-deploy)
Secrets:
  - STAGING_MONGO_URL
  - STAGING_DB_NAME
  - STAGING_BACKEND_URL
  - JWT_SECRET
  - EMERGENT_LLM_KEY
```

**Production Environment:**
```
Name: production
Protection: Required reviewers (add admins)
Deployment branches: Tags matching v*.*.*
Secrets:
  - PROD_MONGO_URL
  - PROD_DB_NAME
  - PROD_BACKEND_URL
  - JWT_SECRET (different from staging!)
  - EMERGENT_LLM_KEY
  - CORS_ORIGINS=https://yourdomain.com
```

### 4. Create Teams (If Organization)

1. Create teams:
   - `@your-org/admins`
   - `@your-org/backend-team`
   - `@your-org/frontend-team`
   - `@your-org/devops-team`

2. Update `CODEOWNERS` file with your team names

3. Assign repository permissions

---

## 🔄 Development Workflow (Trunk-Based)

### Daily Development

```bash
# 1. Create feature branch from main
git checkout main
git pull origin main
git checkout -b feature/my-feature

# 2. Make changes
# ... code changes ...

# 3. Commit with conventional commits
git add .
git commit -m "feat: add video upload feature"

# 4. Push and create PR
git push origin feature/my-feature

# 5. CI runs automatically:
#    - Backend: lint, test
#    - Frontend: lint, build
#    - Flutter: analyze, test

# 6. Get PR reviewed and approved

# 7. Squash merge to main
#    → Staging deploys automatically!
```

### Deploying to Production

```bash
# 1. Ensure staging is stable

# 2. Create version tag
git checkout main
git pull origin main
git tag -a v1.0.0 -m "Release v1.0.0: Initial production release"
git push origin v1.0.0

# 3. GitHub Actions workflow starts
#    → Pauses for approval
#    → Admins approve
#    → Deploys to production
#    → Creates GitHub Release
```

---

## 📊 CI/CD Pipeline Flow

```
Developer
   │
   ├─ Create feature branch
   ├─ Make changes
   ├─ Push to GitHub
   │
   ▼
Pull Request Created
   │
   ├─ CI Workflow runs
   │  ├─ Backend lint & test
   │  ├─ Frontend lint & build
   │  └─ Flutter analyze & test
   │
   ├─ Code review (1+ approval)
   │
   ▼
Merge to main (squash)
   │
   ├─ Staging Deployment (auto)
   │  ├─ Deploy backend
   │  ├─ Deploy frontend
   │  └─ Run migrations
   │
   ▼
Create version tag (vX.Y.Z)
   │
   ├─ Production Deployment
   │  ├─ Wait for approval ⏸
   │  ├─ Deploy backend
   │  ├─ Deploy frontend
   │  └─ Create GitHub Release
   │
   ▼
Production Live! 🎉
```

---

## 📁 Repository Structure

```
Like2Share/
├── .github/
│   ├── workflows/
│   │   ├── ci.yml                    # PR checks
│   │   ├── deploy-staging.yml        # Staging deployment
│   │   ├── deploy-production.yml     # Production deployment
│   │   └── security.yml              # Security scans
│   └── CODEOWNERS                    # Code ownership
├── webapp/
│   ├── backend/
│   │   ├── .env.example              # Backend env template
│   │   └── ...
│   └── frontend/
│       ├── .env.example              # Frontend env template
│       └── ...
├── frontend/                         # Flutter app
├── chatbot/
│   ├── .env.example                  # Chatbot env template
│   └── ...
├── .gitignore                        # Excludes .env files
├── DEPLOYMENT.md                     # Deployment guide
├── CONTRIBUTING.md                   # Contribution guide
├── BRANCH_PROTECTION_SETUP.md       # Branch protection guide
├── SECURITY.md                       # Security practices
└── README.md                         # Project overview
```

---

## 🔧 Customization Needed

### Update Deployment Workflows

The workflows currently have placeholder deployment commands. Update them based on your hosting:

**For Railway/Render/Fly.io:**
```yaml
- name: Deploy to Railway
  run: railway up
  env:
    RAILWAY_TOKEN: ${{ secrets.RAILWAY_TOKEN }}
```

**For Vercel:**
```yaml
- name: Deploy to Vercel
  uses: amondnet/vercel-action@v25
  with:
    vercel-token: ${{ secrets.VERCEL_TOKEN }}
    vercel-project-id: ${{ secrets.VERCEL_PROJECT_ID }}
```

**For AWS/GCP/Azure:**
```yaml
- name: Deploy to AWS
  run: |
    aws deploy create-deployment \
      --application-name buzzcart \
      --deployment-group production
  env:
    AWS_ACCESS_KEY_ID: ${{ secrets.AWS_ACCESS_KEY_ID }}
    AWS_SECRET_ACCESS_KEY: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
```

### Update CODEOWNERS

Replace placeholders with your actual GitHub usernames/teams:

```bash
# Find and replace
@your-github-username      → @your-actual-username
@your-org/backend-team     → @yourorg/backend
@your-org/admins           → @yourorg/admins
```

### Update Documentation

Replace placeholder URLs in documentation:
- `https://yourdomain.com` → Your actual domain
- `https://staging.yourdomain.com` → Your staging domain
- `https://api.yourdomain.com` → Your API domain

---

## 📚 Documentation Overview

| Document | Purpose | Audience |
|----------|---------|----------|
| [README.md](README.md) | Project overview | Everyone |
| [DEPLOYMENT.md](DEPLOYMENT.md) | Deployment procedures | DevOps, Backend |
| [CONTRIBUTING.md](CONTRIBUTING.md) | Development workflow | Developers |
| [BRANCH_PROTECTION_SETUP.md](BRANCH_PROTECTION_SETUP.md) | GitHub configuration | Admins |
| [SECURITY.md](SECURITY.md) | Security practices | Everyone (CRITICAL) |
| [CODEOWNERS](CODEOWNERS) | Code ownership | All contributors |

---

## ✅ Verification Checklist

After setup, verify:

### GitHub Configuration
- [ ] Branch protection enabled on `main`
- [ ] Staging environment created
- [ ] Production environment created (with approvers)
- [ ] All secrets added to environments
- [ ] Teams created and permissions assigned
- [ ] CODEOWNERS file updated with real teams

### Security
- [ ] `.env` files removed from git history
- [ ] All secrets rotated
- [ ] `.gitignore` preventing `.env` commits
- [ ] Secret scanning enabled
- [ ] Dependabot enabled

### CI/CD
- [ ] CI workflow runs on PRs
- [ ] Staging deploys on merge to `main`
- [ ] Production requires approval
- [ ] Security scans run weekly

### Testing
- [ ] Created test PR and verified CI runs
- [ ] Tested direct push to `main` (should fail)
- [ ] Verified staging deployment
- [ ] Tested production deployment with tag

---

## 🚀 Next Steps

1. **Secure secrets** (see SECURITY.md)
2. **Configure GitHub** (see BRANCH_PROTECTION_SETUP.md)
3. **Update deployment workflows** with your hosting provider
4. **Test the entire flow** with a small feature
5. **Train team** on new workflow (see CONTRIBUTING.md)
6. **Plan first production release**

---

## 💬 Support

- **Documentation:** Start with [DEPLOYMENT.md](DEPLOYMENT.md)
- **Development:** See [CONTRIBUTING.md](CONTRIBUTING.md)
- **Security:** Read [SECURITY.md](SECURITY.md) immediately!
- **Issues:** Open GitHub issue with appropriate label

---

**🎉 You're all set! Now go secure those secrets and start deploying!**
