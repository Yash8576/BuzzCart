# Like2Share - Quick Start Guide

## 🎯 Your Database is Ready!

I've set up a complete database infrastructure for your Like2Share application. Here's what was created:

## 📦 What Was Created

### Database Schema
- **Users Table**: Authentication and profile management
- **Posts Table**: User content with like/share/view counters
- **Likes Table**: Track post likes with automatic counter updates
- **Shares Table**: Track post shares with engagement metrics
- **Comments Table**: Nested comments with reply support
- **Followers Table**: Social following system

### Configuration Files
✅ Docker Compose for development (`docker/docker-compose.yml`)
✅ Docker Compose for production (`docker/docker-compose.prod.yml`)
✅ Kubernetes manifests (`k8s/postgres/`)
✅ Database migrations (`database/migrations/`)
✅ Setup scripts for Windows and Linux
✅ Environment template (`.env.example` → `.env`)

## 🚀 How to Start the Database

### Option 1: Windows (Easiest)
```bash
# Start Docker Desktop first, then run:
.\scripts\setup-database.bat
```

### Option 2: PowerShell
```powershell
# 1. Start Docker Desktop
# 2. Navigate to your project
cd "c:\Users\dravi\Downloads\Like2Share\docker"

# 3. Start the database
docker-compose up -d postgres

# 4. Check status
docker-compose ps
```

### Option 3: Using the Shell Script
```bash
chmod +x scripts/setup-database.sh
./scripts/setup-database.sh
```

## ⚠️ Important: Start Docker Desktop First!

Before running any commands, make sure Docker Desktop is running:
1. Open Docker Desktop application
2. Wait for it to fully start (whale icon should be steady)
3. Then run the database setup commands

## 📊 Database Connection Info

**Development:**
```
Host: localhost
Port: 5432
Database: like2share_db
Username: like2share_user
Password: like2share_dev_password
```

**Connection String:**
```
postgres://like2share_user:like2share_dev_password@localhost:5432/like2share_db
```

## 🔍 Verify Database is Running

```bash
# Check container status
docker ps

# Access database CLI
docker exec -it like2share_db psql -U like2share_user -d like2share_db

# List all tables
docker exec like2share_db psql -U like2share_user -d like2share_db -c "\dt"
```

## 📝 Next Steps

After the database is running:

1. **Start Backend Service:**
   ```bash
   cd docker
   docker-compose up -d backend
   ```

2. **Start Frontend Service:**
   ```bash
   docker-compose up -d frontend
   ```

3. **View All Services:**
   ```bash
   docker-compose ps
   ```

4. **View Logs:**
   ```bash
   docker-compose logs -f
   ```

## 🗄️ Database Features

### Automatic Features:
- ✅ UUID generation for all IDs
- ✅ Automatic timestamp updates (`updated_at`)
- ✅ Auto-incrementing like/share counters
- ✅ Cascading deletes for referential integrity
- ✅ Indexed columns for fast queries
- ✅ Soft delete support for posts and comments

### Constraints:
- Users must provide email OR mobile number
- One like per user per post
- One follower relationship per pair
- Users cannot follow themselves

## 🛠️ Useful Commands

### Stop All Services:
```bash
cd docker
docker-compose down
```

### Restart Database:
```bash
docker-compose restart postgres
```

### View Database Logs:
```bash
docker-compose logs -f postgres
```

### Backup Database:
```bash
docker exec like2share_db pg_dump -U like2share_user like2share_db > backup_$(date +%Y%m%d).sql
```

### Clean Restart (removes data):
```bash
docker-compose down -v
docker-compose up -d postgres
```

## 📱 API Integration

Your backend should use this connection string from `.env`:
```
DATABASE_URL=postgres://like2share_user:like2share_dev_password@postgres:5432/like2share_db?sslmode=disable
```

## 🔐 Production Deployment

For production (Kubernetes):
1. Update passwords in `k8s/secrets.yaml`
2. Apply manifests:
   ```bash
   kubectl apply -f k8s/namespace.yaml
   kubectl apply -f k8s/secrets.yaml
   kubectl apply -f k8s/configmap.yaml
   kubectl apply -f k8s/postgres/
   ```

## 📚 Documentation

Detailed documentation available in:
- `database/README.md` - Complete database documentation
- `docker/docker-compose.yml` - Development configuration
- `k8s/postgres/` - Kubernetes production setup

## 🐛 Troubleshooting

**Database won't start:**
- Check if Docker Desktop is running
- Verify port 5432 is not in use: `netstat -ano | findstr :5432`
- Check logs: `docker-compose logs postgres`

**Can't connect:**
- Verify container is running: `docker ps`
- Check credentials in `.env` file
- Ensure you're using correct port (5432)

**Need to reset:**
```bash
docker-compose down -v
docker-compose up -d postgres
```

---

## 🎉 You're All Set!

Your Like2Share database is configured with:
- 6 interconnected tables
- Automatic triggers and functions
- Proper indexing for performance
- Both Docker and Kubernetes support
- Development and production configs

**Just start Docker Desktop and run the setup script!**
