# 🚨 SECURITY ALERT - IMMEDIATE ACTION REQUIRED

## Critical Security Issues Detected

Your repository currently has **EXPOSED SECRETS** that must be addressed immediately!

### ❌ Issues Found:

1. **`.env` files with real secrets may be committed**
   - Location: `webapp/backend/.env`
   - Contains: `JWT_SECRET`, `EMERGENT_LLM_KEY`
   - Risk: Anyone with repository access can see these secrets

2. **Insecure CORS configuration**
   - Current: `CORS_ORIGINS=*` (allows any origin)
   - Risk: Cross-site attacks, unauthorized API access

---

## ⚡ IMMEDIATE ACTIONS (Do This Now!)

### Step 1: Check Git History

```bash
# Check if .env files are committed
git log --all --full-history -- "**/.env"

# If you see results, secrets are ALREADY committed!
```

### Step 2: Remove .env Files from Git

If .env files are committed:

```bash
# Remove from history (NUCLEAR OPTION - rewrites history)
git filter-branch --force --index-filter \
  'git rm --cached --ignore-unmatch **/.env' \
  --prune-empty --tag-name-filter cat -- --all

# Force push (WARNING: coordinate with team)
git push origin --force --all
```

**Alternative (safer for teams):**

```bash
# Add to .gitignore (already done)
# Then remove from tracking
git rm --cached webapp/backend/.env
git rm --cached webapp/frontend/.env
git rm --cached chatbot/.env

# Commit the removal
git commit -m "security: remove .env files from tracking"
git push
```

### Step 3: Rotate ALL Secrets

**All secrets in the committed .env files are now COMPROMISED!**

1. **Generate new JWT_SECRET:**
   ```bash
   # Python
   python -c "import secrets; print(secrets.token_urlsafe(64))"
   
   # Or use online generator (be careful!)
   ```

2. **Regenerate EMERGENT_LLM_KEY:**
   - Log in to Emergent AI dashboard
   - Revoke old key: `sk-emergent-6A9390dC62aD111E56aD111E56`
   - Generate new key

3. **Update MongoDB credentials** (if exposed)

4. **Update all .env files** with new secrets

### Step 4: Use .env.example Templates

```bash
# Backend
cp webapp/backend/.env.example webapp/backend/.env
# Edit and add real secrets

# Frontend
cp webapp/frontend/.env.example webapp/frontend/.env

# Chatbot
cp chatbot/.env.example chatbot/.env

# NEVER commit .env files!
```

### Step 5: Configure GitHub Secrets

For CI/CD, store secrets in GitHub:

1. Go to **Settings → Secrets and variables → Actions**
2. Click **New repository secret**
3. Add each secret:
   - `STAGING_MONGO_URL`
   - `STAGING_DB_NAME`
   - `JWT_SECRET`
   - `EMERGENT_LLM_KEY`
   - etc.

---

## 🔒 Long-Term Security Practices

### 1. Secret Management

**Use Environment-Specific Secrets:**

```bash
# Development (.env - local only)
JWT_SECRET=local-dev-secret-123

# Staging (GitHub Secrets)
JWT_SECRET=<complex-random-staging-secret>

# Production (GitHub Secrets)
JWT_SECRET=<different-complex-random-prod-secret>
```

**Secret Rotation Schedule:**
- JWT secrets: Every 6 months
- API keys: When team member leaves or key exposed
- Database passwords: Quarterly

### 2. CORS Configuration

**Update CORS for each environment:**

```python
# Development
CORS_ORIGINS=http://localhost:3000,http://localhost:5173

# Staging
CORS_ORIGINS=https://staging.yourdomain.com

# Production
CORS_ORIGINS=https://yourdomain.com,https://www.yourdomain.com
```

### 3. Code Review Checklist

Before approving PRs, verify:
- [ ] No hardcoded secrets (API keys, passwords)
- [ ] No `.env` files added
- [ ] No console.log with sensitive data
- [ ] CORS properly configured
- [ ] Input validation on all endpoints
- [ ] SQL/NoSQL injection prevention

### 4. Pre-Commit Hooks

Install `git-secrets` to prevent accidental commits:

```bash
# Install git-secrets
# macOS
brew install git-secrets

# Windows (using Git Bash)
# Download from: https://github.com/awslabs/git-secrets

# Setup in repository
cd /path/to/Like2Share
git secrets --install
git secrets --register-aws
git secrets --add 'sk-[a-zA-Z0-9]+'  # Catch API keys
git secrets --add 'JWT_SECRET='
git secrets --add 'EMERGENT_LLM_KEY='
```

### 5. Security Scanning

Add GitHub security features:

**Enable Dependabot:**
1. Settings → Security → Code security and analysis
2. Enable Dependabot alerts
3. Enable Dependabot security updates

**Enable Secret Scanning:**
1. Settings → Security → Code security and analysis
2. Enable Secret scanning (requires public repo or GitHub Advanced Security)

**Add Secret Scanning to CI:**

```yaml
# .github/workflows/security.yml
name: Security Scan

on: [push, pull_request]

jobs:
  secret-scan:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      
      - name: Gitleaks scan
        uses: gitleaks/gitleaks-action@v2
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
```

### 6. Access Control

**Principle of Least Privilege:**

| Role | Access Level | Can View Secrets |
|------|-------------|------------------|
| Developer | Write (via PRs) | No |
| Maintainer | Maintain | GitHub Secrets only |
| Admin | Admin | Yes (all secrets) |

**Repository Settings:**
- Limit who can access GitHub Secrets
- Require 2FA for all team members
- Audit access logs quarterly

---

## 📋 Security Checklist

### Initial Setup (One-Time)
- [ ] Remove .env files from git history
- [ ] Rotate all exposed secrets
- [ ] Setup .gitignore properly (✅ DONE)
- [ ] Create .env.example templates (✅ DONE)
- [ ] Configure GitHub Secrets
- [ ] Enable Dependabot
- [ ] Enable Secret Scanning
- [ ] Install pre-commit hooks
- [ ] Document security procedures

### Regular Maintenance
- [ ] Monthly: Review access logs
- [ ] Quarterly: Rotate database credentials
- [ ] Semi-annually: Rotate JWT secrets
- [ ] Annually: Full security audit
- [ ] On team changes: Review access rights

### Before Every Deploy
- [ ] Verify environment variables are set
- [ ] Check CORS configuration
- [ ] Review recent commits for secrets
- [ ] Test authentication flows
- [ ] Verify database connection strings

---

## 🚨 Incident Response

### If Secrets Are Leaked:

1. **Immediately rotate** all exposed secrets
2. **Notify team** via Slack/email
3. **Check access logs** for unauthorized use
4. **Update documentation** with new secrets
5. **Post-mortem** to prevent recurrence

### If Unauthorized Access Detected:

1. **Lock down** affected systems
2. **Reset passwords** for all users
3. **Review logs** for data exfiltration
4. **Notify stakeholders** if user data affected
5. **Implement monitoring** to detect future attempts

---

## 📚 Additional Resources

- [OWASP Top 10](https://owasp.org/www-project-top-ten/)
- [GitHub Secret Scanning](https://docs.github.com/en/code-security/secret-scanning)
- [JWT Best Practices](https://tools.ietf.org/html/rfc8725)
- [MongoDB Security Checklist](https://docs.mongodb.com/manual/administration/security-checklist/)

---

## 💬 Questions?

**Security concerns:** security@yourdomain.com  
**Emergency:** Slack #security-incidents channel

---

## ⚠️ Remember

> **"The only truly secure system is one that is powered off, cast in a block of concrete and sealed in a lead-lined room with armed guards."** - Gene Spafford

While we can't achieve perfect security, following these practices gets us close!
