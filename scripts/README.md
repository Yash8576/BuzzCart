# Like2Share - Docker Management Scripts

This folder contains scripts to easily manage Docker services for the Like2Share application.

## Available Scripts

### Windows Scripts (.bat)

#### 1. start-all-services.bat
**Purpose:** Start all Docker services (PostgreSQL, Redis, MinIO, Backend)

**Usage:**
```batch
cd scripts
start-all-services.bat
```

**What it does:**
- Stops any existing containers
- Starts PostgreSQL, Redis, MinIO, and Backend services
- Shows service status and connection URLs

**When to use:** Daily development startup

---

#### 2. rebuild-and-start.bat
**Purpose:** Rebuild backend Docker image and start all services

**Usage:**
```batch
cd scripts
rebuild-and-start.bat
```

**What it does:**
- Stops and removes existing containers
- Rebuilds the backend Docker image from source
- Starts all services with the new build
- Shows build logs and service status

**When to use:** After making changes to backend code

---

#### 3. stop-all-services.bat
**Purpose:** Stop all running Docker services

**Usage:**
```batch
cd scripts
stop-all-services.bat
```

**What it does:**
- Gracefully stops all running containers
- Preserves data volumes

**When to use:** End of work session or before system restart

---

### Unix Scripts (.sh)

#### start-all-services.sh
Same functionality as Windows version for Linux/Mac users

**Usage:**
```bash
cd scripts
chmod +x start-all-services.sh
./start-all-services.sh
```

---

## Service Details

After running `start-all-services.bat` or `rebuild-and-start.bat`, the following services will be available:

| Service    | URL/Port            | Credentials                                    |
|------------|---------------------|------------------------------------------------|
| PostgreSQL | `localhost:5433`    | User: `like2share_user`<br>Password: `like2share_dev_password`<br>Database: `like2share_db` |
| Redis      | `localhost:6379`    | No authentication                              |
| MinIO      | `localhost:9000`    | Access: `minioadmin`<br>Secret: `minioadmin123`|
| MinIO UI   | `localhost:9001`    | Same credentials as MinIO                      |
| Backend    | `localhost:8080`    | REST API                                       |

---

## Common Workflows

### Starting Development Environment
```batch
# First time or after code changes
rebuild-and-start.bat

# Subsequent startups
start-all-services.bat
```

### Connecting to Database with pgAdmin
1. Run `start-all-services.bat`
2. Open pgAdmin 4
3. Create new server connection:
   - Host: `localhost`
   - Port: `5433`
   - Database: `like2share_db`
   - Username: `like2share_user`
   - Password: `like2share_dev_password`

### Viewing Logs
```batch
# View all service logs
docker compose -f docker/docker-compose.yml logs -f

# View specific service logs
docker compose -f docker/docker-compose.yml logs -f backend
docker compose -f docker/docker-compose.yml logs -f postgres
```

### Troubleshooting

**Issue:** Services fail to start
```batch
# Check what's running
docker compose -f docker/docker-compose.yml ps

# Check logs for errors
docker compose -f docker/docker-compose.yml logs

# Clean restart
docker compose -f docker/docker-compose.yml down
docker compose -f docker/docker-compose.yml up -d --build
```

**Issue:** Port already in use
```batch
# Check what's using ports 5433, 6379, 8080, 9000
netstat -ano | findstr ":5433"
netstat -ano | findstr ":8080"

# Kill process if needed
taskkill /PID <process_id> /F
```

**Issue:** Database data reset needed
```batch
# WARNING: This deletes all data
docker compose -f docker/docker-compose.yml down -v
rebuild-and-start.bat
```

---

## Notes

- All scripts should be run from the `scripts` directory
- Scripts use relative paths, so they work from any project location
- Data persists across container restarts in Docker volumes
- Use `rebuild-and-start.bat` after pulling code updates
- Frontend should connect to `http://localhost:8080/api`

---

## Quick Reference

```batch
# Start services
scripts\start-all-services.bat

# Rebuild backend
scripts\rebuild-and-start.bat

# Stop services
scripts\stop-all-services.bat

# View logs
docker compose -f docker/docker-compose.yml logs -f

# Restart specific service
docker compose -f docker/docker-compose.yml restart backend

# Clean everything (WARNING: deletes data)
docker compose -f docker/docker-compose.yml down -v
```
