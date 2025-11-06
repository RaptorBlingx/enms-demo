#!/bin/bash
################################################################################
# ENMS-Demo Zero-Touch Deployment Script
# Purpose: Automated deployment to new server (10.33.10.113)
# Usage: ./deploy_to_new_server.sh
################################################################################

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
SOURCE_SERVER="ubuntu@10.33.10.109"
BACKUP_DATE=$(date +%Y%m%d_%H%M%S)
PROJECT_DIR="/home/ubuntu/enms-demo"

# Helper functions
print_header() {
    echo -e "\n${BLUE}============================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}============================================${NC}\n"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

# Check if running as ubuntu user
if [ "$USER" != "ubuntu" ]; then
    print_error "This script must be run as ubuntu user"
    exit 1
fi

print_header "ENMS-Demo Zero-Touch Deployment"
echo "Target Server: $(hostname)"
echo "Target IP: $(hostname -I | awk '{print $1}')"
echo "Source Server: 10.33.10.109"
echo "Date: $(date)"
echo ""

# Step 1: Prerequisites Check
print_header "[1/9] Checking Prerequisites"

print_info "Checking Docker installation..."
if ! command -v docker &> /dev/null; then
    print_warning "Docker not found. Installing..."
    curl -fsSL https://get.docker.com -o /tmp/get-docker.sh
    sudo sh /tmp/get-docker.sh
    sudo usermod -aG docker ubuntu
    print_success "Docker installed"
    print_warning "Please log out and log back in, then run this script again"
    exit 0
else
    print_success "Docker found: $(docker --version)"
fi

print_info "Checking Docker Compose..."
if ! docker compose version &> /dev/null; then
    print_warning "Docker Compose plugin not found. Installing..."
    sudo apt update -qq
    sudo apt install -y docker-compose-plugin
    print_success "Docker Compose installed"
else
    print_success "Docker Compose found: $(docker compose version)"
fi

print_info "Checking additional utilities..."
MISSING_TOOLS=""
for tool in git python3 pip3 postgresql-client rsync jq; do
    if ! command -v $tool &> /dev/null; then
        MISSING_TOOLS="$MISSING_TOOLS $tool"
    fi
done

if [ -n "$MISSING_TOOLS" ]; then
    print_warning "Installing missing tools:$MISSING_TOOLS"
    sudo apt update -qq
    sudo apt install -y git python3 python3-pip postgresql-client rsync jq curl
fi

print_info "Installing Python dependencies..."
pip3 install --quiet psycopg2-binary requests 2>/dev/null || true

print_success "All prerequisites satisfied"

# Step 2: Project Setup
print_header "[2/9] Setting Up Project Directory"

if [ -d "$PROJECT_DIR/.git" ]; then
    print_info "Git repository found, pulling latest..."
    cd $PROJECT_DIR
    git pull origin main || true
    print_success "Repository updated"
elif [ -d "$PROJECT_DIR" ]; then
    print_warning "Project directory exists but not a git repo"
    read -p "Do you want to backup and re-clone? (y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        mv $PROJECT_DIR ${PROJECT_DIR}_backup_$(date +%Y%m%d)
        print_info "Cloning from GitLab..."
        git clone https://gitlab.com/raptorblingx/enms-demo.git $PROJECT_DIR || {
            print_error "Git clone failed. Using rsync fallback..."
            rsync -avz --progress $SOURCE_SERVER:$PROJECT_DIR/ $PROJECT_DIR/
        }
    fi
else
    print_info "Cloning repository..."
    git clone https://gitlab.com/raptorblingx/enms-demo.git $PROJECT_DIR 2>/dev/null || {
        print_warning "Git clone failed. Using rsync..."
        mkdir -p $PROJECT_DIR
        rsync -avz --progress --exclude 'backups' --exclude '.git' $SOURCE_SERVER:$PROJECT_DIR/ $PROJECT_DIR/
    }
    print_success "Project cloned"
fi

cd $PROJECT_DIR
print_success "Project directory ready: $PROJECT_DIR"

# Step 3: Transfer Configuration
print_header "[3/9] Transferring Configuration"

print_info "Copying .env file from source server..."
if scp -q $SOURCE_SERVER:$PROJECT_DIR/.env $PROJECT_DIR/.env 2>/dev/null; then
    print_success ".env file transferred"
    
    # Verify .env contents
    print_info "Environment variables configured:"
    grep -E "^(POSTGRES_|MQTT_|NODE_RED_)" .env | sed 's/=.*/=***/' || true
else
    print_error "Failed to transfer .env file"
    print_warning "Please manually copy .env from source server"
    exit 1
fi

print_info "Transferring Node-RED flows..."
scp -q $SOURCE_SERVER:$PROJECT_DIR/node-red/flows.json $PROJECT_DIR/node-red/flows.json 2>/dev/null && \
    print_success "Node-RED flows transferred" || \
    print_warning "Node-RED flows transfer skipped"

print_info "Transferring Grafana dashboards..."
rsync -az $SOURCE_SERVER:$PROJECT_DIR/grafana/dashboards/ $PROJECT_DIR/grafana/dashboards/ 2>/dev/null && \
    print_success "Grafana dashboards transferred" || \
    print_warning "Grafana dashboards transfer skipped"

# Step 4: Data Migration
print_header "[4/9] Migrating Data from Source Server"

mkdir -p backups/migration_$BACKUP_DATE

print_info "Creating database backup on source server..."
ssh $SOURCE_SERVER "docker exec enms_demo_postgres pg_dump -U reg_ml_demo -d reg_ml_demo" > backups/migration_$BACKUP_DATE/db_backup.sql 2>/dev/null && {
    print_success "Database backup created: $(du -h backups/migration_$BACKUP_DATE/db_backup.sql | cut -f1)"
} || {
    print_error "Database backup failed"
    print_warning "Attempting alternative backup method..."
    ssh $SOURCE_SERVER "cd $PROJECT_DIR && docker exec enms_demo_postgres pg_dump -U reg_ml_demo -d reg_ml_demo -F c -f /tmp/db_backup.dump"
    scp $SOURCE_SERVER:/tmp/db_backup.dump backups/migration_$BACKUP_DATE/db_backup.dump
    print_success "Alternative backup method succeeded"
}

print_info "Transferring ML models..."
rsync -az $SOURCE_SERVER:$PROJECT_DIR/backend/models/ $PROJECT_DIR/backend/models/ 2>/dev/null && \
    print_success "ML models transferred" || \
    print_warning "ML models transfer skipped (will train new if needed)"

print_info "Transferring artistic resources..."
rsync -az $SOURCE_SERVER:$PROJECT_DIR/artistic-resources/ $PROJECT_DIR/artistic-resources/ 2>/dev/null && \
    print_success "Artistic resources transferred" || \
    print_warning "Artistic resources transfer skipped"

# Step 5: Start Services
print_header "[5/9] Starting Docker Services"

print_info "Building and starting containers..."
docker compose down 2>/dev/null || true
docker compose up -d --build

print_info "Waiting for services to be ready..."
sleep 10

# Wait for PostgreSQL to be ready
print_info "Waiting for PostgreSQL to be healthy..."
TIMEOUT=60
ELAPSED=0
while [ $ELAPSED -lt $TIMEOUT ]; do
    if docker exec enms_demo_postgres pg_isready -U reg_ml_demo -d reg_ml_demo &>/dev/null; then
        print_success "PostgreSQL is ready"
        break
    fi
    sleep 2
    ELAPSED=$((ELAPSED + 2))
    echo -n "."
done
echo ""

if [ $ELAPSED -ge $TIMEOUT ]; then
    print_error "PostgreSQL failed to start within $TIMEOUT seconds"
    docker compose logs postgres
    exit 1
fi

# Wait for other services
sleep 20

print_info "Checking service status..."
docker compose ps

# Step 6: Restore Database
print_header "[6/9] Restoring Database"

print_info "Importing database backup..."
if [ -f "backups/migration_$BACKUP_DATE/db_backup.sql" ]; then
    docker cp backups/migration_$BACKUP_DATE/db_backup.sql enms_demo_postgres:/tmp/db_backup.sql
    docker exec enms_demo_postgres psql -U reg_ml_demo -d reg_ml_demo -f /tmp/db_backup.sql &>/dev/null && {
        print_success "Database restored successfully"
    } || {
        print_warning "Database restore had errors, but may have completed. Checking..."
    }
elif [ -f "backups/migration_$BACKUP_DATE/db_backup.dump" ]; then
    docker cp backups/migration_$BACKUP_DATE/db_backup.dump enms_demo_postgres:/tmp/db_backup.dump
    docker exec enms_demo_postgres pg_restore -U reg_ml_demo -d reg_ml_demo -c /tmp/db_backup.dump &>/dev/null && {
        print_success "Database restored successfully (custom format)"
    } || {
        print_warning "Database restore had errors, but may have completed. Checking..."
    }
else
    print_error "No backup file found!"
    exit 1
fi

# Verify data
print_info "Verifying database content..."
DEVICE_COUNT=$(docker exec enms_demo_postgres psql -U reg_ml_demo -d reg_ml_demo -t -c "SELECT COUNT(*) FROM devices;" 2>/dev/null | tr -d ' ')
JOB_COUNT=$(docker exec enms_demo_postgres psql -U reg_ml_demo -d reg_ml_demo -t -c "SELECT COUNT(*) FROM print_jobs;" 2>/dev/null | tr -d ' ')

if [ -n "$DEVICE_COUNT" ] && [ "$DEVICE_COUNT" -gt 0 ]; then
    print_success "Database verification: $DEVICE_COUNT devices, $JOB_COUNT print jobs"
else
    print_error "Database verification failed - no data found"
    exit 1
fi

# Step 7: Setup Systemd Services
print_header "[7/9] Configuring System Services"

print_info "Creating systemd service for data generator..."
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

sleep 5

if sudo systemctl is-active --quiet demo-data-generator.service; then
    print_success "Data generator service started"
else
    print_warning "Data generator service failed to start"
    sudo journalctl -u demo-data-generator.service -n 20
fi

# Optional: Setup maintenance service
print_info "Setting up maintenance service (optional)..."
if [ -f "enms-demo-maintenance.service" ]; then
    sudo cp enms-demo-maintenance.service /etc/systemd/system/
    sudo systemctl daemon-reload
    sudo systemctl enable enms-demo-maintenance.service
    sudo systemctl start enms-demo-maintenance.service
    print_success "Maintenance service configured"
else
    print_warning "Maintenance service file not found, skipping"
fi

# Step 8: Health Checks
print_header "[8/9] Running Health Checks"

sleep 10  # Give services time to fully start

print_info "Testing Docker containers..."
CONTAINER_COUNT=$(docker ps --filter "name=enms_demo" --format "{{.Names}}" | wc -l)
if [ "$CONTAINER_COUNT" -ge 6 ]; then
    print_success "$CONTAINER_COUNT containers running"
    docker ps --filter "name=enms_demo" --format "table {{.Names}}\t{{.Status}}"
else
    print_warning "Only $CONTAINER_COUNT containers running (expected 6+)"
    docker compose ps
fi

print_info "Testing Web Server..."
if curl -s -f http://localhost:8090/ > /dev/null; then
    print_success "Web server responding"
else
    print_error "Web server not responding"
fi

print_info "Testing API..."
if curl -s http://localhost:8090/api/dpp_summary | jq -e '.success' > /dev/null 2>&1; then
    print_success "API responding correctly"
else
    print_warning "API may not be responding correctly"
fi

print_info "Testing Grafana..."
if curl -s http://localhost:3002/api/health | jq -e '.database == "ok"' > /dev/null 2>&1; then
    print_success "Grafana healthy"
else
    print_warning "Grafana may not be fully ready"
fi

print_info "Testing Node-RED..."
if curl -s http://localhost:1882/ > /dev/null; then
    print_success "Node-RED responding"
else
    print_warning "Node-RED may not be responding"
fi

print_info "Checking MQTT broker..."
if docker exec enms_demo_mosquitto mosquitto_sub -t 'sensors/#' -C 1 -W 5 -u enms_demo_user -P demo_secure_password_456! &>/dev/null; then
    print_success "MQTT broker working"
else
    print_warning "MQTT broker may not have messages yet (this is normal initially)"
fi

print_info "Checking data generation..."
sleep 5
RECENT_STATUS=$(docker exec enms_demo_postgres psql -U reg_ml_demo -d reg_ml_demo -t -c "SELECT COUNT(*) FROM printer_status WHERE timestamp > NOW() - INTERVAL '1 minute';" 2>/dev/null | tr -d ' ')
if [ -n "$RECENT_STATUS" ] && [ "$RECENT_STATUS" -gt 0 ]; then
    print_success "Data generation active ($RECENT_STATUS records in last minute)"
else
    print_warning "No recent data detected. Data generator may need time to start."
fi

# Step 9: Summary & Next Steps
print_header "[9/9] Deployment Summary"

echo ""
print_success "DEPLOYMENT COMPLETED SUCCESSFULLY!"
echo ""

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  ENMS-Demo is now running on this server!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

SERVER_IP=$(hostname -I | awk '{print $1}')
echo "📍 Access Points:"
echo "   Web Interface: http://$SERVER_IP:8090"
echo "   Grafana:       http://$SERVER_IP:3002"
echo "   Node-RED:      http://$SERVER_IP:1882"
echo "   API:           http://$SERVER_IP:5000"
echo ""

echo "📊 System Status:"
echo "   Docker Containers: $CONTAINER_COUNT running"
echo "   Database: $DEVICE_COUNT devices, $JOB_COUNT print jobs"
echo "   Data Generator: $(sudo systemctl is-active demo-data-generator.service)"
echo ""

echo "📝 Next Steps:"
echo "   1. Review logs: docker compose logs -f"
echo "   2. Test all dashboards in Grafana"
echo "   3. Verify API endpoints: curl http://localhost:8090/api/dpp_summary"
echo "   4. Monitor for 24-48 hours before DNS cutover"
echo "   5. Update DNS: lauds-demo.intel50001.com → $SERVER_IP"
echo ""

echo "🔍 Useful Commands:"
echo "   View logs:        cd $PROJECT_DIR && docker compose logs -f"
echo "   Restart services: cd $PROJECT_DIR && docker compose restart"
echo "   Check status:     docker compose ps"
echo "   Monitor data gen: sudo journalctl -u demo-data-generator.service -f"
echo ""

echo "📚 Documentation:"
echo "   Migration Plan:   $PROJECT_DIR/MIGRATION_PLAN.md"
echo "   README:           $PROJECT_DIR/README.md"
echo "   API Docs:         $PROJECT_DIR/DPP_API_Documentation.md"
echo ""

print_warning "IMPORTANT: Keep source server (10.33.10.109) running for 7 days!"
print_info "This allows for quick rollback if any issues are discovered."
echo ""

# Create completion marker
echo "Deployment completed: $(date)" > $PROJECT_DIR/.deployment_complete
echo "Server: $(hostname)" >> $PROJECT_DIR/.deployment_complete
echo "IP: $SERVER_IP" >> $PROJECT_DIR/.deployment_complete
echo "Devices: $DEVICE_COUNT" >> $PROJECT_DIR/.deployment_complete
echo "Jobs: $JOB_COUNT" >> $PROJECT_DIR/.deployment_complete

print_success "Deployment complete! 🎉"
echo ""
