# Firebase Data Connect + Direct PostgreSQL Migration Runbook

This runbook migrates BuzzCart backend and local chatbot to Cloud SQL PostgreSQL behind Firebase Data Connect.

## Confirmed target values
- Project ID: buzzcart-daeb6
- Project Number: 1038414138435
- Region: us-east4
- Cloud SQL instance: buzzcart-daeb6-instance
- DB name: buzzcart-daeb6-database
- Instance connection name: buzzcart-daeb6:us-east4:buzzcart-daeb6-instance
- Public IP: 34.86.72.243
- Port: 5432

## Chosen defaults
- App DB user: buzzcart_app
- Chatbot DB user: buzzcart_chatbot_ro
- Connection path: Cloud SQL Auth Proxy
- Downtime window: 15 minutes
- Chatbot access: read-only

## One-time prerequisites
1. Install Cloud SQL Auth Proxy binary and ensure `cloud-sql-proxy` is available in PATH.
2. Install PostgreSQL client tools and ensure `psql` is available in PATH.
3. Ensure your Google account has Cloud SQL Admin rights on project buzzcart-daeb6.

## Step 1: Start Cloud SQL proxy
Open a dedicated terminal and run:

```powershell
./scripts/firebase/start-cloud-sql-proxy.ps1
```

Keep this terminal running until migration and smoke tests are done.

## Step 2: Prepare role SQL passwords
Edit `scripts/firebase/setup_roles.sql` and replace these placeholders:
- REPLACE_APP_PASSWORD
- REPLACE_CHATBOT_PASSWORD

Use strong random passwords.

## Step 3: Apply schema migrations and grants
In a new terminal at repository root, run:

```powershell
./scripts/firebase/migrate-to-cloudsql.ps1 -AdminUser <cloudsql_admin_user>
```

This applies SQL files from `database/migrations` in order, then applies role grants.

## Step 4: Configure backend env
Set backend DATABASE_URL to:

```env
DATABASE_URL=postgres://buzzcart_app:<APP_PASSWORD>@127.0.0.1:5432/buzzcart-daeb6-database?sslmode=disable
```

## Step 5: Configure chatbot env (local)
Set chatbot DATABASE_URL to:

```env
DATABASE_URL=postgresql://buzzcart_chatbot_ro:<CHATBOT_PASSWORD>@127.0.0.1:5432/buzzcart-daeb6-database?sslmode=disable
```

Chatbot remains local and connects through the proxy.

## Step 6: Cutover checklist (15-minute window)
1. Announce maintenance mode.
2. Stop write traffic to old database.
3. Execute final data sync/import.
4. Restart backend with new DATABASE_URL.
5. Restart local chatbot with new DATABASE_URL.
6. Run smoke tests.
7. Exit maintenance mode.

## Step 7: Smoke tests
Backend:
1. Login endpoint works.
2. Product list and product detail endpoints return data.
3. Cart add/update/remove works.
4. Create product review works.

Chatbot:
1. Starts successfully.
2. Can read chat history.
3. No permission errors for read operations.

Database checks:
1. Row counts for key tables are expected.
2. New rows appear from backend writes.
3. Chatbot user cannot write to protected tables.

## Rollback plan
1. Keep old database untouched during initial verification period.
2. If failures appear, switch DATABASE_URL back to old DB for backend and chatbot.
3. Restart services and reopen traffic.

## Notes
- Local storage/media currently has zero files in this workspace, so Firebase Storage migration is not needed right now.
- If media becomes populated later, migrate media separately and update URL generation paths.
