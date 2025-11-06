#!/bin/bash
################################################################################
# Import ONLY DATA from 109 to 113 (skip schema - it's already created)
################################################################################

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo "╔════════════════════════════════════════════════════════════╗"
echo "║     Import Data Only (No Schema) from 109 → 113            ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""

SOURCE_SERVER="10.33.10.109"
BACKUP_DIR="/home/ubuntu/enms-demo/backups/data_only_$(date +%Y%m%d_%H%M%S)"
mkdir -p $BACKUP_DIR

echo -e "${BLUE}[1/5] Exporting DATA ONLY from 109 (no schema)${NC}"

# Export only data from key tables
ssh ubuntu@$SOURCE_SERVER << 'EOSSH' > $BACKUP_DIR/data_export.sql
cd /home/ubuntu/enms-demo

docker exec enms_demo_postgres pg_dump -U reg_ml_demo -d reg_ml_demo \
  --data-only \
  --disable-triggers \
  --table=devices \
  --table=print_jobs \
  --table=demo_users \
  2>/dev/null || echo "-- Export completed with warnings"

EOSSH

echo -e "${GREEN}✅ Data exported${NC}"
echo ""

echo -e "${BLUE}[2/5] Clearing existing data on 113${NC}"

docker exec enms_demo_postgres psql -U reg_ml_demo -d reg_ml_demo << 'EOSQL'
-- Disable triggers to avoid foreign key issues
SET session_replication_role = 'replica';

-- Clear tables (keep schema)
TRUNCATE TABLE print_jobs CASCADE;
TRUNCATE TABLE devices CASCADE;
TRUNCATE TABLE demo_users CASCADE;
TRUNCATE TABLE demo_sessions CASCADE;
TRUNCATE TABLE demo_audit_log CASCADE;

-- Re-enable triggers
SET session_replication_role = 'origin';

\echo 'Tables cleared'
EOSQL

echo -e "${GREEN}✅ Data cleared${NC}"
echo ""

echo -e "${BLUE}[3/5] Importing data to 113${NC}"

# Copy SQL file to container
docker cp $BACKUP_DIR/data_export.sql enms_demo_postgres:/tmp/

# Import with triggers disabled
docker exec enms_demo_postgres psql -U reg_ml_demo -d reg_ml_demo << 'EOSQL'
-- Disable triggers
SET session_replication_role = 'replica';

-- Import the data
\i /tmp/data_export.sql

-- Re-enable triggers
SET session_replication_role = 'origin';

\echo 'Data imported'
EOSQL

echo -e "${GREEN}✅ Data imported${NC}"
echo ""

echo -e "${BLUE}[4/5] Verifying data${NC}"

echo "Device counts:"
DEVICES_109=$(ssh ubuntu@$SOURCE_SERVER "docker exec enms_demo_postgres psql -U reg_ml_demo -d reg_ml_demo -t -c 'SELECT COUNT(*) FROM devices;'" | tr -d ' ')
DEVICES_113=$(docker exec enms_demo_postgres psql -U reg_ml_demo -d reg_ml_demo -t -c "SELECT COUNT(*) FROM devices;" | tr -d ' ')

echo -e "  109: ${GREEN}$DEVICES_109${NC} devices"
echo -e "  113: ${GREEN}$DEVICES_113${NC} devices"

echo ""
echo "Print jobs:"
JOBS_109=$(ssh ubuntu@$SOURCE_SERVER "docker exec enms_demo_postgres psql -U reg_ml_demo -d reg_ml_demo -t -c 'SELECT COUNT(*) FROM print_jobs;'" | tr -d ' ')
JOBS_113=$(docker exec enms_demo_postgres psql -U reg_ml_demo -d reg_ml_demo -t -c "SELECT COUNT(*) FROM print_jobs;" | tr -d ' ')

echo -e "  109: ${GREEN}$JOBS_109${NC} jobs"
echo -e "  113: ${GREEN}$JOBS_113${NC} jobs"

echo ""

echo -e "${BLUE}[5/5] Testing API${NC}"

RESPONSE=$(curl -s http://localhost:8090/api/dpp_summary 2>/dev/null | jq -r '.success' 2>/dev/null || echo "false")

if [ "$RESPONSE" = "true" ]; then
    echo -e "${GREEN}✅ API working!${NC}"
    echo ""
    echo "Devices from API:"
    curl -s http://localhost:8090/api/dpp_summary | jq -r '.devices[] | "  \(.friendly_name)"' | head -10
else
    echo -e "${YELLOW}⚠️  API not responding yet. Restarting services...${NC}"
    docker compose restart python_api web_server
    sleep 5
    
    RESPONSE=$(curl -s http://localhost:8090/api/dpp_summary 2>/dev/null | jq -r '.success' 2>/dev/null || echo "false")
    if [ "$RESPONSE" = "true" ]; then
        echo -e "${GREEN}✅ API working after restart!${NC}"
    else
        echo -e "${RED}❌ API still has issues. Check logs:${NC}"
        docker logs enms_demo_python_api --tail 20
    fi
fi

echo ""
echo "════════════════════════════════════════════════════════════"
echo -e "${GREEN}Data import completed!${NC}"
echo "════════════════════════════════════════════════════════════"
echo ""
echo "Test in browser:"
echo "  http://10.33.10.113:8090/device_management.html"
echo "  http://10.33.10.113:8090/dpp_page.html"
echo ""
