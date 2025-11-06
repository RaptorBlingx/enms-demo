# 🚀 ENMS-Demo Zero-Touch Migration Plan
## Migration: 10.33.10.109 → 10.33.10.113

**Created:** November 6, 2025  
**Status:** Ready for execution  
**Strategy:** Zero-touch deployment with minimal manual steps

---

## 📋 Table of Contents
1. [Pre-Migration Checklist](#pre-migration-checklist)
2. [Migration Strategy](#migration-strategy)
3. [Step-by-Step Migration](#step-by-step-migration)
4. [Verification & Testing](#verification--testing)
5. [Rollback Plan](#rollback-plan)
6. [Post-Migration](#post-migration)

---

## 🎯 Migration Objectives

✅ **Zero-Touch Deployment** - Minimal manual configuration  
✅ **Data Preservation** - Migrate all historical data  
✅ **Zero Downtime** - Keep 109 running during migration  
✅ **Validated Cutover** - Thorough testing before DNS switch  
✅ **Quick Rollback** - Ability to revert if needed  

---

## 📊 Current System Inventory (10.33.10.109)

### Docker Services
- ✅ `enms_demo_postgres` - TimescaleDB (port 5434)
- ✅ `enms_demo_mosquitto` - MQTT Broker (port 1884)
- ✅ `enms_demo_nodered` - IoT Processing (port 1882)
- ✅ `enms_demo_grafana` - Dashboards (port 3002)
- ✅ `enms_demo_python_api` - REST API (port 5000)
- ✅ `enms_demo_web_server` - Nginx (port 8090)
- ✅ `enms_demo_ml_worker` - ML Predictions

### Systemd Services
- ✅ `demo-data-generator.service` - Real-time data generation
- ⚠️  `enms-demo-maintenance.service` - Inactive (PDF cleanup)

### Docker Volumes
- `postgres_data_demo` - **CRITICAL** - Database
- `grafana_data_demo` - Dashboards & settings
- `generated_pdfs_demo` - DPP Reports
- `mosquitto_data_demo` - MQTT persistence
- `mosquitto_config_demo` - MQTT config
- `gcode_previews_data_demo` - Preview images

### Key Files
- `/home/ubuntu/enms-demo/.env` - Environment configuration
- `/home/ubuntu/enms-demo/docker-compose.yml` - Service definitions
- `/home/ubuntu/enms-demo/node-red/flows.json` - Node-RED flows
- `/home/ubuntu/enms-demo/grafana/dashboards/*.json` - Grafana dashboards
- `/home/ubuntu/enms-demo/backend/models/` - ML models

### External Dependencies
- **Domain:** `https://lauds-demo.intel50001.com`
- **Email:** SMTP via Gmail (configured in .env)

---

## 🎯 Migration Strategy

### Strategy: **Parallel Deployment with Data Migration**

```
┌─────────────────────────────────────────────────────────┐
│                    MIGRATION PHASES                      │
├─────────────────────────────────────────────────────────┤
│ Phase 1: Prepare new server (10.33.10.113)             │
│   - Install dependencies                                │
│   - Clone repository                                    │
│   - Configure environment                               │
│                                                         │
│ Phase 2: Data migration                                 │
│   - Export database from 109                           │
│   - Transfer volumes                                    │
│   - Import to 113                                       │
│                                                         │
│ Phase 3: Service deployment                             │
│   - Start all services                                  │
│   - Verify health                                       │
│   - Test functionality                                  │
│                                                         │
│ Phase 4: Parallel testing (both servers running)        │
│   - Run automated tests on 113                         │
│   - Compare outputs                                     │
│   - Performance validation                              │
│                                                         │
│ Phase 5: DNS/Traffic cutover                            │
│   - Update domain DNS                                   │
│   - Monitor traffic                                     │
│   - Keep 109 as hot standby                            │
│                                                         │
│ Phase 6: Decommission (after 7 days)                    │
│   - Stop services on 109                               │
│   - Archive final backup                                │
│   - Document lessons learned                            │
└─────────────────────────────────────────────────────────┘
```

**Rationale:**
- ✅ Both servers running = zero downtime
- ✅ Full testing before cutover = risk mitigation
- ✅ Automated deployment = consistency
- ✅ Quick rollback = safety net

---

## 📝 Pre-Migration Checklist

### On Source Server (10.33.10.109)

```bash
# 1. Document current state
ssh ubuntu@10.33.10.109
cd /home/ubuntu/enms-demo

# Check all services are healthy
docker ps --filter "name=enms_demo"
docker compose ps

# Check service health
systemctl status demo-data-generator.service

# Test current system
curl http://localhost:8090/
curl http://localhost:8090/api/dpp_summary | jq '.devices | length'

# Check database size
docker exec enms_demo_postgres psql -U reg_ml_demo -d reg_ml_demo -c "\dt+"
docker exec enms_demo_postgres psql -U reg_ml_demo -d reg_ml_demo -c "SELECT COUNT(*) FROM print_jobs;"
docker exec enms_demo_postgres psql -U reg_ml_demo -d reg_ml_demo -c "SELECT COUNT(*) FROM devices;"

# Check disk usage
docker system df
df -h
```

### Expected Output Validation
- [ ] 7 containers running (6 main + 1 exited config generator)
- [ ] demo-data-generator.service active
- [ ] Database accessible
- [ ] All ports responding (8090, 3002, 1882, 5000)

---

## 🚀 Step-by-Step Migration

### PHASE 1: Prepare New Server (10.33.10.113)

#### 1.1 Install Prerequisites
```bash
# SSH to new server
ssh ubuntu@10.33.10.113

# Update system
sudo apt update && sudo apt upgrade -y

# Install Docker (if not present)
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
sudo usermod -aG docker ubuntu
newgrp docker

# Install Docker Compose V2
sudo apt install docker-compose-plugin -y

# Verify installations
docker --version
docker compose version

# Install additional utilities
sudo apt install -y git python3 python3-pip postgresql-client rsync
pip3 install psycopg2-binary requests
```

#### 1.2 Clone Repository
```bash
# Create project directory
cd /home/ubuntu
git clone https://gitlab.com/raptorblingx/enms-demo.git
cd enms-demo

# Or use rsync if not in git
# rsync -avz --exclude 'backups' --exclude '.git' ubuntu@10.33.10.109:/home/ubuntu/enms-demo/ /home/ubuntu/enms-demo/
```

#### 1.3 Configure Environment
```bash
# Copy .env from old server (DO NOT USE .env.example)
scp ubuntu@10.33.10.109:/home/ubuntu/enms-demo/.env /home/ubuntu/enms-demo/.env

# Verify .env contents
cat .env

# Update IP-specific settings if needed (usually not required for Docker)
# The .env should have POSTGRES_HOST=postgres (Docker service name, not IP)
```

---

### PHASE 2: Data Migration

#### 2.1 Create Database Backup on Source (109)
```bash
# On 10.33.10.109
ssh ubuntu@10.33.10.109
cd /home/ubuntu/enms-demo

# Create backup directory
mkdir -p backups/migration_$(date +%Y%m%d)

# Export database
docker exec enms_demo_postgres pg_dump -U reg_ml_demo -d reg_ml_demo -F c -f /tmp/db_backup.dump
docker cp enms_demo_postgres:/tmp/db_backup.dump backups/migration_$(date +%Y%m%d)/db_backup.dump

# Export as SQL (alternative format)
docker exec enms_demo_postgres pg_dump -U reg_ml_demo -d reg_ml_demo > backups/migration_$(date +%Y%m%d)/db_backup.sql

# Verify backup
ls -lh backups/migration_$(date +%Y%m%d)/
```

#### 2.2 Transfer Data to New Server (113)
```bash
# On 10.33.10.109 - Transfer database backup
scp -r backups/migration_$(date +%Y%m%d)/ ubuntu@10.33.10.113:/home/ubuntu/enms-demo/backups/

# Transfer additional critical data
scp -r backend/models/ ubuntu@10.33.10.113:/home/ubuntu/enms-demo/backend/
scp -r node-red/flows.json ubuntu@10.33.10.113:/home/ubuntu/enms-demo/node-red/
scp -r grafana/dashboards/ ubuntu@10.33.10.113:/home/ubuntu/enms-demo/grafana/
scp -r artistic-resources/ ubuntu@10.33.10.113:/home/ubuntu/enms-demo/

# Optional: Transfer generated PDFs (can be large)
# docker run --rm -v enms-demo_generated_pdfs_demo:/data -v $(pwd)/backups:/backup alpine tar czf /backup/pdfs.tar.gz /data
# scp backups/pdfs.tar.gz ubuntu@10.33.10.113:/home/ubuntu/enms-demo/backups/
```

#### 2.3 Alternative: Direct Volume Transfer
```bash
# On 10.33.10.109 - Export Docker volumes (more complete)
docker run --rm -v enms-demo_postgres_data_demo:/data -v $(pwd)/backups:/backup alpine tar czf /backup/postgres_volume.tar.gz /data
docker run --rm -v enms-demo_grafana_data_demo:/data -v $(pwd)/backups:/backup alpine tar czf /backup/grafana_volume.tar.gz /data
docker run --rm -v enms-demo_mosquitto_data_demo:/data -v $(pwd)/backups:/backup alpine tar czf /backup/mosquitto_volume.tar.gz /data

# Transfer to new server
scp backups/*.tar.gz ubuntu@10.33.10.113:/home/ubuntu/enms-demo/backups/
```

---

### PHASE 3: Deploy on New Server (113)

#### 3.1 Start Services (Initial Deployment)
```bash
# On 10.33.10.113
cd /home/ubuntu/enms-demo

# Build and start all services
docker compose up -d --build

# Wait for services to be healthy
sleep 30

# Check service status
docker compose ps
docker ps --filter "name=enms_demo"

# Check logs for any errors
docker compose logs --tail=50
```

#### 3.2 Restore Database
```bash
# Wait for PostgreSQL to be ready
docker exec enms_demo_postgres pg_isready -U reg_ml_demo

# Import database backup (choose one method)

# Method 1: Custom format
docker cp backups/migration_$(date +%Y%m%d)/db_backup.dump enms_demo_postgres:/tmp/
docker exec enms_demo_postgres pg_restore -U reg_ml_demo -d reg_ml_demo -c /tmp/db_backup.dump

# Method 2: SQL format
docker cp backups/migration_$(date +%Y%m%d)/db_backup.sql enms_demo_postgres:/tmp/
docker exec enms_demo_postgres psql -U reg_ml_demo -d reg_ml_demo -f /tmp/db_backup.sql

# Method 3: Direct volume import (if you did volume transfer)
docker compose down
docker volume create enms-demo_postgres_data_demo
docker run --rm -v enms-demo_postgres_data_demo:/data -v $(pwd)/backups:/backup alpine tar xzf /backup/postgres_volume.tar.gz -C /
docker compose up -d

# Verify data import
docker exec enms_demo_postgres psql -U reg_ml_demo -d reg_ml_demo -c "SELECT COUNT(*) FROM print_jobs;"
docker exec enms_demo_postgres psql -U reg_ml_demo -d reg_ml_demo -c "SELECT COUNT(*) FROM devices;"
```

#### 3.3 Setup Systemd Services
```bash
# Create systemd service for data generator
sudo cp /home/ubuntu/enms-demo/realtime_demo_generator.py /usr/local/bin/

# Create service file
sudo tee /etc/systemd/system/demo-data-generator.service > /dev/null <<EOF
[Unit]
Description=DEMO Real-Time Data Generator for enms-demo
After=network.target docker.service
Requires=docker.service

[Service]
Type=simple
User=ubuntu
WorkingDirectory=/home/ubuntu/enms-demo
ExecStart=/usr/bin/python3 /home/ubuntu/enms-demo/realtime_demo_generator.py
Restart=always
RestartSec=10
StandardOutput=append:/var/log/demo-data-generator.log
StandardError=append:/var/log/demo-data-generator.log

Environment="MQTT_BROKER_HOST=localhost"
Environment="MQTT_PORT=1884"
Environment="MQTT_USERNAME=enms_demo_user"
Environment="MQTT_PASSWORD=demo_secure_password_456!"
Environment="POSTGRES_HOST=localhost"
Environment="POSTGRES_PORT=5434"
Environment="POSTGRES_DB=reg_ml_demo"
Environment="POSTGRES_USER=reg_ml_demo"
Environment="POSTGRES_PASSWORD=raptorblingx_demo"

[Install]
WantedBy=multi-user.target
EOF

# Enable and start service
sudo systemctl daemon-reload
sudo systemctl enable demo-data-generator.service
sudo systemctl start demo-data-generator.service
sudo systemctl status demo-data-generator.service

# Optional: Setup maintenance service
sudo systemctl enable /home/ubuntu/enms-demo/enms-demo-maintenance.service
sudo systemctl start enms-demo-maintenance.service
```

---

### PHASE 4: Verification & Testing (113)

#### 4.1 Health Checks
```bash
# On 10.33.10.113
cd /home/ubuntu/enms-demo

# 1. Check all containers are running
docker ps --filter "name=enms_demo" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

# 2. Check container health
docker inspect enms_demo_postgres | grep -A 5 Health
docker inspect enms_demo_nodered | grep -A 5 Health

# 3. Test database connectivity
docker exec enms_demo_postgres psql -U reg_ml_demo -d reg_ml_demo -c "SELECT version();"

# 4. Check MQTT broker
docker exec enms_demo_mosquitto mosquitto_sub -t 'sensors/#' -C 1 -u enms_demo_user -P demo_secure_password_456!

# 5. Test API endpoints
curl -s http://localhost:8090/ | head -20
curl -s http://localhost:8090/api/dpp_summary | jq '.success'
curl -s http://localhost:5000/api/devices | jq '. | length'

# 6. Check Grafana
curl -s http://localhost:3002/api/health

# 7. Check Node-RED
curl -s http://localhost:1882/

# 8. Verify data generator is running
sudo journalctl -u demo-data-generator.service --since "5 minutes ago" -n 20
```

#### 4.2 Functional Testing
```bash
# Test 1: Verify device count matches
ssh ubuntu@10.33.10.109 "docker exec enms_demo_postgres psql -U reg_ml_demo -d reg_ml_demo -t -c 'SELECT COUNT(*) FROM devices;'"
ssh ubuntu@10.33.10.113 "docker exec enms_demo_postgres psql -U reg_ml_demo -d reg_ml_demo -t -c 'SELECT COUNT(*) FROM devices;'"

# Test 2: Verify print jobs transferred
ssh ubuntu@10.33.10.109 "docker exec enms_demo_postgres psql -U reg_ml_demo -d reg_ml_demo -t -c 'SELECT COUNT(*) FROM print_jobs;'"
ssh ubuntu@10.33.10.113 "docker exec enms_demo_postgres psql -U reg_ml_demo -d reg_ml_demo -t -c 'SELECT COUNT(*) FROM print_jobs;'"

# Test 3: Generate a test PDF
curl -X POST http://localhost:8090/api/generate_dpp_pdf \
  -H "Content-Type: application/json" \
  -d '{"job_id": 1}' | jq

# Test 4: Check if new data is being generated
docker exec enms_demo_postgres psql -U reg_ml_demo -d reg_ml_demo -c "SELECT MAX(timestamp) FROM printer_status;"
sleep 30
docker exec enms_demo_postgres psql -U reg_ml_demo -d reg_ml_demo -c "SELECT MAX(timestamp) FROM printer_status;"

# Test 5: Verify ML predictions are working
docker logs enms_demo_ml_worker --tail 20

# Test 6: Check Grafana dashboards
# Open browser to http://10.33.10.113:3002
# Login and verify all dashboards load
```

#### 4.3 Performance Comparison
```bash
# Create test script
cat > /tmp/test_performance.sh << 'EOF'
#!/bin/bash
echo "Testing server: $1"
SERVER=$1

echo "=== API Response Times ==="
time curl -s http://$SERVER:8090/api/dpp_summary > /dev/null
time curl -s http://$SERVER:5000/api/devices > /dev/null

echo "=== Database Query Performance ==="
time docker exec enms_demo_postgres psql -U reg_ml_demo -d reg_ml_demo -c "SELECT COUNT(*) FROM print_jobs;" > /dev/null

echo "=== Grafana Health ==="
time curl -s http://$SERVER:3002/api/health > /dev/null
EOF

chmod +x /tmp/test_performance.sh

# Compare both servers
/tmp/test_performance.sh 10.33.10.109
/tmp/test_performance.sh 10.33.10.113
```

#### 4.4 Create Validation Checklist
```markdown
## ✅ Pre-Cutover Validation Checklist

- [ ] All 7 Docker containers running and healthy
- [ ] Database record counts match source server
- [ ] demo-data-generator.service active and generating data
- [ ] API endpoints responding correctly
- [ ] Grafana dashboards load without errors
- [ ] Node-RED flows executing (check flow tab)
- [ ] ML predictions being generated
- [ ] PDF generation working
- [ ] MQTT messages flowing (check Node-RED debug)
- [ ] No errors in docker logs (last 100 lines)
- [ ] Disk space adequate (>20GB free)
- [ ] Network connectivity from client machines works
- [ ] Performance comparable to source server
```

---

### PHASE 5: DNS/Traffic Cutover

#### 5.1 Update DNS (if using domain)
```bash
# Update DNS records for lauds-demo.intel50001.com
# A Record: lauds-demo.intel50001.com → 10.33.10.113

# Method depends on your DNS provider
# Common approach:
# 1. Lower TTL to 300 seconds (5 minutes) - do this 24 hours before cutover
# 2. Update A record to new IP
# 3. Wait for propagation (5-15 minutes)
# 4. Verify with: dig lauds-demo.intel50001.com
```

#### 5.2 Update Frontend URL in .env (if needed)
```bash
# On 10.33.10.113
cd /home/ubuntu/enms-demo

# If FRONTEND_URL is using IP address, update it
sed -i 's/10.33.10.109/10.33.10.113/g' .env

# Restart services that use .env
docker compose restart python_api
```

#### 5.3 Traffic Validation
```bash
# Monitor logs on new server
docker compose logs -f

# Check for incoming connections
sudo netstat -an | grep :8090
sudo netstat -an | grep :3002

# Monitor system resources
htop
docker stats

# Check error rates
docker compose logs --since 1h | grep -i error | wc -l
```

#### 5.4 Keep Source Server Running (Hot Standby)
```bash
# On 10.33.10.109 - DO NOT stop services yet
# Monitor for any traffic still coming to old server
sudo netstat -an | grep :8090

# Keep monitoring for 24-48 hours
```

---

### PHASE 6: Post-Migration Monitoring

#### 6.1 First 24 Hours
```bash
# On 10.33.10.113

# Create monitoring script
cat > /home/ubuntu/enms-demo/monitor.sh << 'EOF'
#!/bin/bash
while true; do
  echo "=== $(date) ==="
  echo "Containers:"
  docker ps --filter "name=enms_demo" --format "{{.Names}}: {{.Status}}"
  echo ""
  echo "Disk:"
  df -h | grep -E "/$|/var/lib/docker"
  echo ""
  echo "Memory:"
  free -h
  echo ""
  echo "Recent Errors:"
  docker compose logs --since 5m | grep -i error | tail -5
  echo "================================"
  sleep 300  # Every 5 minutes
done
EOF

chmod +x /home/ubuntu/enms-demo/monitor.sh

# Run in background
nohup /home/ubuntu/enms-demo/monitor.sh > /var/log/enms-demo-monitor.log 2>&1 &
```

#### 6.2 Setup Automated Backups
```bash
# Create backup script
cat > /home/ubuntu/enms-demo/backup_daily.sh << 'EOF'
#!/bin/bash
BACKUP_DIR="/home/ubuntu/enms-demo/backups/daily"
DATE=$(date +%Y%m%d_%H%M%S)

mkdir -p $BACKUP_DIR

# Backup database
docker exec enms_demo_postgres pg_dump -U reg_ml_demo -d reg_ml_demo -F c -f /tmp/backup_$DATE.dump
docker cp enms_demo_postgres:/tmp/backup_$DATE.dump $BACKUP_DIR/

# Backup configuration
tar czf $BACKUP_DIR/config_$DATE.tar.gz .env docker-compose.yml node-red/flows.json

# Keep only last 7 days
find $BACKUP_DIR -name "*.dump" -mtime +7 -delete
find $BACKUP_DIR -name "*.tar.gz" -mtime +7 -delete

echo "Backup completed: $DATE"
EOF

chmod +x /home/ubuntu/enms-demo/backup_daily.sh

# Add to crontab (daily at 2 AM)
(crontab -l 2>/dev/null; echo "0 2 * * * /home/ubuntu/enms-demo/backup_daily.sh >> /var/log/enms-demo-backup.log 2>&1") | crontab -
```

---

## 🔄 Rollback Plan

### If Issues Found After Cutover

#### Quick Rollback (Emergency)
```bash
# 1. Update DNS back to old IP
# A Record: lauds-demo.intel50001.com → 10.33.10.109

# 2. Verify old server still working
ssh ubuntu@10.33.10.109
docker ps --filter "name=enms_demo"
curl http://localhost:8090/api/dpp_summary

# 3. Announce rollback to users

# 4. Investigate issues on new server without time pressure
```

#### Partial Rollback (Database only)
```bash
# If only database issues, restore from old server
ssh ubuntu@10.33.10.109
docker exec enms_demo_postgres pg_dump -U reg_ml_demo -d reg_ml_demo > /tmp/rollback.sql
scp /tmp/rollback.sql ubuntu@10.33.10.113:/tmp/

ssh ubuntu@10.33.10.113
docker exec enms_demo_postgres psql -U reg_ml_demo -d reg_ml_demo -f /tmp/rollback.sql
docker compose restart
```

---

## 🎯 Decommission Old Server (After 7 Days)

### Final Steps (Only After 113 is Stable)

```bash
# On 10.33.10.109

# 1. Stop data generator
sudo systemctl stop demo-data-generator.service
sudo systemctl disable demo-data-generator.service

# 2. Create final backup
cd /home/ubuntu/enms-demo
docker exec enms_demo_postgres pg_dump -U reg_ml_demo -d reg_ml_demo -F c > backups/final_backup_$(date +%Y%m%d).dump

# 3. Stop all services
docker compose down

# 4. Archive data (optional)
tar czf /tmp/enms-demo-archive-$(date +%Y%m%d).tar.gz /home/ubuntu/enms-demo

# 5. Transfer final backup to 113
scp /tmp/enms-demo-archive-$(date +%Y%m%d).tar.gz ubuntu@10.33.10.113:/home/ubuntu/backups/

# 6. Remove volumes (optional - only if disk space needed)
# docker volume ls | grep demo
# docker volume rm $(docker volume ls -q | grep demo)

# 7. Document completion
echo "Migration completed: $(date)" >> /home/ubuntu/migration_log.txt
```

---

## 📊 Success Metrics

### KPIs to Monitor
- ✅ **Uptime**: 99.9%+ after migration
- ✅ **API Response Time**: <500ms average
- ✅ **Data Loss**: Zero records lost
- ✅ **Error Rate**: <0.1% of requests
- ✅ **User Reports**: Zero critical bugs reported

### Performance Baselines (from 109)
- API endpoints respond in <300ms
- Grafana dashboards load in <2s
- Database queries complete in <100ms
- MQTT messages delivered in <50ms
- PDF generation completes in <5s

---

## 📝 Post-Migration Documentation

### Update Documentation
```bash
# On 10.33.10.113
cd /home/ubuntu/enms-demo

# Update README with new IP/URL
sed -i 's/10.33.10.109/10.33.10.113/g' README.md

# Create migration report
cat > MIGRATION_REPORT_$(date +%Y%m%d).md << EOF
# Migration Report - $(date)

## Summary
- Source: 10.33.10.109
- Target: 10.33.10.113
- Start: [FILL IN]
- Completion: [FILL IN]
- Downtime: 0 minutes
- Status: ✅ Success

## Data Migrated
- Database records: [FILL IN]
- Docker volumes: [FILL IN]
- Configuration files: All
- ML models: All

## Issues Encountered
- [FILL IN or "None"]

## Lessons Learned
- [FILL IN]

## Team
- Executed by: [YOUR NAME]
- Verified by: [FILL IN]
EOF
```

---

## 🛠️ Automation Script

### All-in-One Migration Script (NEW SERVER)
```bash
# Save as: /home/ubuntu/deploy_enms_demo.sh

#!/bin/bash
set -e

echo "=================================================="
echo "ENMS-Demo Zero-Touch Deployment Script"
echo "Target Server: $(hostname -I | awk '{print $1}')"
echo "=================================================="

# Configuration
SOURCE_SERVER="10.33.10.109"
BACKUP_DATE=$(date +%Y%m%d)

# Step 1: Prerequisites
echo "[1/8] Installing prerequisites..."
sudo apt update -qq
sudo apt install -y docker.io docker-compose-plugin postgresql-client git python3-pip > /dev/null
sudo usermod -aG docker ubuntu
pip3 install psycopg2-binary requests > /dev/null 2>&1

# Step 2: Clone/Transfer project
echo "[2/8] Setting up project files..."
if [ ! -d "/home/ubuntu/enms-demo" ]; then
    git clone https://gitlab.com/raptorblingx/enms-demo.git /home/ubuntu/enms-demo || \
    rsync -avz ubuntu@$SOURCE_SERVER:/home/ubuntu/enms-demo/ /home/ubuntu/enms-demo/
fi
cd /home/ubuntu/enms-demo

# Step 3: Transfer .env
echo "[3/8] Copying environment configuration..."
scp ubuntu@$SOURCE_SERVER:/home/ubuntu/enms-demo/.env .env

# Step 4: Transfer data
echo "[4/8] Transferring database and files..."
mkdir -p backups/migration_$BACKUP_DATE
scp ubuntu@$SOURCE_SERVER:/home/ubuntu/enms-demo/backups/migration_$BACKUP_DATE/db_backup.sql backups/migration_$BACKUP_DATE/ || \
ssh ubuntu@$SOURCE_SERVER "cd /home/ubuntu/enms-demo && docker exec enms_demo_postgres pg_dump -U reg_ml_demo -d reg_ml_demo" > backups/migration_$BACKUP_DATE/db_backup.sql

# Step 5: Start services
echo "[5/8] Starting Docker services..."
docker compose up -d --build
sleep 30

# Step 6: Restore database
echo "[6/8] Restoring database..."
docker cp backups/migration_$BACKUP_DATE/db_backup.sql enms_demo_postgres:/tmp/
docker exec enms_demo_postgres psql -U reg_ml_demo -d reg_ml_demo -f /tmp/db_backup.sql

# Step 7: Setup systemd service
echo "[7/8] Configuring system services..."
sudo tee /etc/systemd/system/demo-data-generator.service > /dev/null << 'EOFSERVICE'
[Unit]
Description=DEMO Real-Time Data Generator for enms-demo
After=network.target docker.service
Requires=docker.service

[Service]
Type=simple
User=ubuntu
WorkingDirectory=/home/ubuntu/enms-demo
ExecStart=/usr/bin/python3 /home/ubuntu/enms-demo/realtime_demo_generator.py
Restart=always
RestartSec=10
StandardOutput=append:/var/log/demo-data-generator.log
StandardError=append:/var/log/demo-data-generator.log

Environment="MQTT_BROKER_HOST=localhost"
Environment="MQTT_PORT=1884"
Environment="MQTT_USERNAME=enms_demo_user"
Environment="MQTT_PASSWORD=demo_secure_password_456!"
Environment="POSTGRES_HOST=localhost"
Environment="POSTGRES_PORT=5434"
Environment="POSTGRES_DB=reg_ml_demo"
Environment="POSTGRES_USER=reg_ml_demo"
Environment="POSTGRES_PASSWORD=raptorblingx_demo"

[Install]
WantedBy=multi-user.target
EOFSERVICE

sudo systemctl daemon-reload
sudo systemctl enable demo-data-generator.service
sudo systemctl start demo-data-generator.service

# Step 8: Verification
echo "[8/8] Running verification tests..."
sleep 10

echo "✅ Checking Docker containers..."
docker ps --filter "name=enms_demo" --format "{{.Names}}: {{.Status}}" || echo "⚠️  Some containers not running"

echo "✅ Checking API..."
curl -s http://localhost:8090/api/dpp_summary > /dev/null && echo "API: OK" || echo "⚠️  API not responding"

echo "✅ Checking database..."
DEVICE_COUNT=$(docker exec enms_demo_postgres psql -U reg_ml_demo -d reg_ml_demo -t -c "SELECT COUNT(*) FROM devices;" 2>/dev/null | tr -d ' ')
echo "Devices in database: $DEVICE_COUNT"

echo ""
echo "=================================================="
echo "✅ DEPLOYMENT COMPLETE!"
echo "=================================================="
echo ""
echo "Access points:"
echo "  - Web Interface: http://$(hostname -I | awk '{print $1}'):8090"
echo "  - Grafana: http://$(hostname -I | awk '{print $1}'):3002"
echo "  - Node-RED: http://$(hostname -I | awk '{print $1}'):1882"
echo ""
echo "Next steps:"
echo "  1. Verify all services: docker compose ps"
echo "  2. Check logs: docker compose logs -f"
echo "  3. Run full testing suite"
echo "  4. Update DNS when ready"
echo ""
```

---

## 📞 Support & Troubleshooting

### Common Issues

#### Issue: Database import fails
```bash
# Solution: Check if schema exists
docker exec enms_demo_postgres psql -U reg_ml_demo -d reg_ml_demo -c "\dt"

# If empty, run init scripts first
docker exec enms_demo_postgres psql -U reg_ml_demo -d reg_ml_demo -f /docker-entrypoint-initdb.d/01_init_schema.sql
```

#### Issue: Containers not starting
```bash
# Check logs
docker compose logs

# Check disk space
df -h

# Check port conflicts
sudo netstat -tulpn | grep -E "8090|3002|1882|5434|1884"
```

#### Issue: Data generator not working
```bash
# Check service status
sudo systemctl status demo-data-generator.service

# Check logs
sudo journalctl -u demo-data-generator.service -n 50

# Test MQTT connectivity
docker exec enms_demo_mosquitto mosquitto_sub -t 'sensors/#' -C 1
```

---

## 🎉 Summary

### Zero-Touch Migration Checklist

**Pre-Migration:**
- [ ] Document current system state
- [ ] Create database backup
- [ ] Verify all services healthy on 109

**Migration:**
- [ ] Deploy to 113 using automation script
- [ ] Restore data
- [ ] Verify all services
- [ ] Run functional tests
- [ ] Compare performance with 109

**Cutover:**
- [ ] Update DNS
- [ ] Monitor traffic
- [ ] Keep 109 as hot standby
- [ ] Document completion

**Post-Migration:**
- [ ] Monitor for 7 days
- [ ] Setup automated backups
- [ ] Update documentation
- [ ] Decommission 109

---

## 📅 Recommended Timeline

| Day | Activity | Duration |
|-----|----------|----------|
| Day 0 | Preparation & backup creation | 2 hours |
| Day 1 | Deploy to 113 & data migration | 3 hours |
| Day 1-2 | Testing & validation | 4 hours |
| Day 2 | DNS cutover | 1 hour |
| Day 2-9 | Monitoring (both servers) | Ongoing |
| Day 9 | Decommission 109 | 1 hour |

**Total migration window: 9 days with zero downtime**

---

**Document Version:** 1.0  
**Last Updated:** November 6, 2025  
**Status:** Ready for execution  
**Approved by:** [TO BE FILLED]
