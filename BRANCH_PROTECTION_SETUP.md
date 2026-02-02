# Branch Protection Setup Guide

This guide shows how to configure branch protection rules for your repository.

## Why Branch Protection?

- Prevent accidental force pushes
- Require code review before merging
- Ensure CI passes before merge
- Maintain code quality standards
- Protect production deployments

---

## Setting Up Branch Protection

### 1. Navigate to Settings

1. Go to your GitHub repository
2. Click **Settings** (top right)
3. Click **Branches** (left sidebar)
4. Click **Add branch protection rule**

---

## Recommended Rules for `main` Branch

### Branch Name Pattern
```
main
```

### Protection Settings

#### ✅ **Require a pull request before merging**
- [x] Require approvals: **1** (increase to 2 for larger teams)
- [x] Dismiss stale pull request approvals when new commits are pushed
- [x] Require review from Code Owners (if using CODEOWNERS file)

#### ✅ **Require status checks to pass before merging**
- [x] Require branches to be up to date before merging
- **Required checks:** (add these after first CI run)
  - `Backend - Lint & Test`
  - `Frontend - Lint & Build`
  - `Flutter - Analyze & Test`

#### ✅ **Require conversation resolution before merging**
- [x] All conversations must be resolved

#### ✅ **Require signed commits** (Optional but recommended)
- [x] Require signed commits

#### ✅ **Require linear history**
- [x] Prevent merge commits (enforces squash/rebase)

#### ✅ **Include administrators**
- [x] Apply rules to administrators (highly recommended)

#### ✅ **Restrict who can push to matching branches**
- Add only admins/release managers
- Most developers should only push via PR

#### ❌ **Allow force pushes** 
- [ ] **NEVER** enable this on main

#### ❌ **Allow deletions**
- [ ] **NEVER** enable this on main

---

## Additional Branch Rules (Optional)

### For `develop` Branch (if using GitFlow)

Same settings as `main`, but you might:
- Reduce required approvals to 1
- Not require signed commits
- Allow more people to push directly

### For `release/*` Branches

```
Branch name pattern: release/*
```

Settings:
- [x] Require pull request before merging (2 approvals)
- [x] Require status checks
- [x] Require review from Code Owners
- [x] Restrict who can push (only release managers)

### For `hotfix/*` Branches

```
Branch name pattern: hotfix/*
```

Settings:
- [x] Require pull request (1 approval minimum)
- [x] Require status checks
- [x] Allow fast-tracked merges (emergency only)

---

## Setting Up GitHub Environments

Environments provide deployment protection and secrets management.

### 1. Create Environments

Go to **Settings → Environments** and create:

1. **staging**
2. **production**

### 2. Configure Staging Environment

**Environment:** `staging`

**Deployment Protection:**
- [ ] Required reviewers: (none needed, auto-deploy)
- [x] Wait timer: 0 minutes
- [x] Deployment branches: `main` only

**Environment Secrets:**
```
STAGING_MONGO_URL
STAGING_DB_NAME
STAGING_BACKEND_URL
JWT_SECRET
EMERGENT_LLM_KEY
```

### 3. Configure Production Environment

**Environment:** `production`

**Deployment Protection:**
- [x] **Required reviewers:** Add admin team/users
- [x] Wait timer: 5 minutes (gives time to cancel)
- [x] Deployment branches: **Selected branches** → Tags matching `v*.*.*`

**Environment Secrets:**
```
PROD_MONGO_URL
PROD_DB_NAME
PROD_BACKEND_URL
JWT_SECRET
EMERGENT_LLM_KEY
CORS_ORIGINS
```

**Environment Variables:**
```
NODE_ENV=production
ENVIRONMENT=production
```

---

## Setting Up Teams (For Organizations)

### 1. Create Teams

Go to **Organization → Teams** and create:

1. **@your-org/admins**
   - Full repository access
   - Can merge to protected branches
   - Can approve production deploys

2. **@your-org/maintainers**
   - Can merge PRs
   - Can review code
   - Can manage issues

3. **@your-org/developers**
   - Can create PRs
   - Can review code
   - **Cannot** push to protected branches

4. **@your-org/backend-team**
   - Code ownership for backend/

5. **@your-org/frontend-team**
   - Code ownership for frontend/

6. **@your-org/devops-team**
   - Code ownership for CI/CD and infrastructure

### 2. Assign Repository Permissions

Go to **Repository → Settings → Manage Access**

| Team | Permission |
|------|-----------|
| admins | Admin |
| maintainers | Maintain |
| developers | Write |
| backend-team | Write |
| frontend-team | Write |
| devops-team | Write |

### 3. Update CODEOWNERS

Edit `/CODEOWNERS` to reference teams:

```
# Global
* @your-org/maintainers

# Backend
/webapp/backend/ @your-org/backend-team
/chatbot/ @your-org/backend-team

# Frontend
/webapp/frontend/ @your-org/frontend-team
/frontend/ @your-org/frontend-team

# Infrastructure
/.github/ @your-org/devops-team @your-org/admins
/k8s/ @your-org/devops-team @your-org/admins
```

---

## Verifying Protection Rules

### Test 1: Direct Push (Should Fail)

```bash
git checkout main
echo "test" >> README.md
git commit -am "test: direct push"
git push origin main

# Expected: ERROR - protected branch
```

### Test 2: PR Without Approval (Should Block)

```bash
git checkout -b test-branch
echo "test" >> README.md
git commit -am "test: pr without approval"
git push origin test-branch

# Create PR, try to merge without approval
# Expected: BLOCKED - requires review
```

### Test 3: PR With Failed CI (Should Block)

```bash
# Break linting intentionally
echo "bad syntax" >> webapp/backend/server.py
git commit -am "test: bad code"
git push origin test-branch

# Create PR
# Expected: BLOCKED - CI failed
```

### Test 4: Valid PR (Should Succeed)

```bash
git checkout -b feature/valid-change
echo "# New section" >> README.md
git commit -am "docs: add new section"
git push origin feature/valid-change

# Create PR → CI passes → Get approval → Merge
# Expected: SUCCESS
```

---

## Emergency Procedures

### Bypassing Protection (Use Sparingly!)

**When:** Production is down, immediate fix needed

**How:**
1. Admin temporarily disables branch protection
2. Push hotfix directly
3. **Immediately** re-enable protection
4. Create post-mortem PR to document changes

**Better Alternative:**
```bash
# Create hotfix branch
git checkout -b hotfix/critical-fix

# Make fix
git commit -am "hotfix: critical production bug"
git push origin hotfix/critical-fix

# Fast-track PR (get quick approval from available admin)
# Still maintains audit trail
```

---

## Monitoring & Alerts

### Set Up Notifications

1. **Watch Repository**
   - Go to repository page
   - Click **Watch** → **All Activity**

2. **Slack/Discord Integration**
   ```yaml
   # Add to .github/workflows/notify.yml
   - name: Notify on PR
     uses: 8398a7/action-slack@v3
     with:
       status: ${{ job.status }}
       webhook_url: ${{ secrets.SLACK_WEBHOOK }}
   ```

3. **Email Notifications**
   - GitHub Settings → Notifications
   - Enable email for: Reviews, Mentions, PRs

---

## Troubleshooting

### "Required status check is expected but not present"

**Cause:** Status check name doesn't match workflow job name

**Fix:** 
1. Go to **Settings → Branches → Edit rule**
2. Remove the missing check
3. Re-add it after checking exact job name in `.github/workflows/`

### "Review required, but none submitted"

**Cause:** No one has reviewed the PR

**Fix:**
1. Request review from team member
2. Wait for approval
3. Or increase your team size so reviews are always available

### "Branch is out of date"

**Cause:** `main` has new commits since branch was created

**Fix:**
```bash
git checkout main
git pull origin main
git checkout your-branch
git merge main  # or git rebase main
git push origin your-branch
```

---

## Best Practices

1. **Start Strict:** Easier to relax rules later than tighten them
2. **Review Regularly:** Audit protection rules quarterly
3. **Document Exceptions:** If you bypass rules, document why
4. **Train Team:** Ensure everyone understands the workflow
5. **Automate Everything:** Use CI/CD to enforce standards

---

## Additional Resources

- [GitHub Branch Protection Docs](https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-protected-branches)
- [CODEOWNERS Syntax](https://docs.github.com/en/repositories/managing-your-repositorys-settings-and-features/customizing-your-repository/about-code-owners)
- [GitHub Environments](https://docs.github.com/en/actions/deployment/targeting-different-environments/using-environments-for-deployment)
- [Required Status Checks](https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-protected-branches/about-protected-branches#require-status-checks-before-merging)

---

## Checklist

Use this checklist when setting up a new repository:

- [ ] Create `main` branch protection rule
- [ ] Require 1+ PR approvals
- [ ] Require status checks to pass
- [ ] Prevent force pushes
- [ ] Prevent deletions
- [ ] Create `staging` environment
- [ ] Create `production` environment (with approvers)
- [ ] Add environment secrets
- [ ] Create teams (admins, maintainers, developers)
- [ ] Configure CODEOWNERS file
- [ ] Test branch protection (try direct push)
- [ ] Document emergency procedures
- [ ] Train team on workflow

---

**Questions?** Open an issue or contact DevOps team.
