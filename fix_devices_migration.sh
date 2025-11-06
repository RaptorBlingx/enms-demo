#!/bin/bash
################################################################################
# Fix Devices Migration - Copy only active devices from 109 to 113
# This script:
# 1. Exports ONLY active devices from 109 (those with recent activity)
# 2. Clears devices table on 113
# 3. Imports active devices to 113
################################################################################

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo "╔════════════════════════════════════════════════════════════╗"
echo "║     Fix Devices Migration - Active Devices Only            ║"
echo "║     From 109 → 113                                          ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""

# Configuration
SOURCE_SERVER="10.33.10.109"
BACKUP_DIR="/home/ubuntu/enms-demo/backups/devices_fix_$(date +%Y%m%d_%H%M%S)"
mkdir -p $BACKUP_DIR

echo -e "${BLUE}[1/6] Exporting ONLY active devices from source server (109)${NC}"
echo "Getting devices with activity in the last 7 days..."

# Export active devices (devices with recent printer_status records)
ssh ubuntu@$SOURCE_SERVER "docker exec enms_demo_postgres psql -U reg_ml_demo -d reg_ml_demo" << 'EOSQL' > $BACKUP_DIR/active_devices.sql
-- Get list of active device IDs (devices with activity in last 7 days)
CREATE TEMP TABLE active_device_ids AS
SELECT DISTINCT device_id 
FROM printer_status 
WHERE timestamp > NOW() - INTERVAL '7 days';

-- Export only active devices
\o /tmp/active_devices_export.sql

-- Start transaction
BEGIN;

-- Delete existing devices (will be imported fresh)
TRUNCATE TABLE devices CASCADE;

-- Insert active devices
\echo '-- Active Devices Export'
\echo 'BEGIN;'
\echo ''

-- Export devices table
COPY (
  SELECT * FROM devices 
  WHERE device_id IN (SELECT device_id FROM active_device_ids)
  ORDER BY device_id
) TO STDOUT WITH (FORMAT CSV, HEADER true, QUOTE '"');

\echo ''
\echo 'COMMIT;'

ROLLBACK; -- Don't actually delete from source

\o
\q
EOSQL

# Get the actual export
ssh ubuntu@$SOURCE_SERVER "docker exec enms_demo_postgres cat /tmp/active_devices_export.sql" > $BACKUP_DIR/active_devices_data.sql

echo -e "${GREEN}✅ Active devices exported${NC}"
echo ""

# Count how many devices were exported
DEVICE_COUNT=$(grep -c "^[^-]" $BACKUP_DIR/active_devices_data.sql 2>/dev/null || echo "0")
echo -e "${YELLOW}Found $DEVICE_COUNT active devices to migrate${NC}"
echo ""

# Better approach: Export using COPY command directly
echo -e "${BLUE}[2/6] Creating proper SQL export from source (109)${NC}"

ssh ubuntu@$SOURCE_SERVER << 'EOSSH' > $BACKUP_DIR/devices_export.sql
cd /home/ubuntu/enms-demo

# Export active devices with all related data
docker exec enms_demo_postgres psql -U reg_ml_demo -d reg_ml_demo << 'EOSQL'
-- Export devices that have been active in last 7 days
\COPY (
  SELECT d.* 
  FROM devices d
  WHERE EXISTS (
    SELECT 1 FROM printer_status ps 
    WHERE ps.device_id = d.device_id 
    AND ps.timestamp > NOW() - INTERVAL '7 days'
  )
  ORDER BY d.device_id
) TO '/tmp/active_devices.csv' WITH CSV HEADER;
\q
EOSQL

# Output the CSV
docker exec enms_demo_postgres cat /tmp/active_devices.csv
EOSSH

echo -e "${GREEN}✅ Devices exported from 109${NC}"
echo ""

echo -e "${BLUE}[3/6] Backing up current devices on 113 (just in case)${NC}"
docker exec enms_demo_postgres psql -U reg_ml_demo -d reg_ml_demo << 'EOSQL' > $BACKUP_DIR/devices_backup_113.sql
\COPY devices TO '/tmp/devices_backup_113.csv' WITH CSV HEADER;
\q
EOSQL
docker exec enms_demo_postgres cat /tmp/devices_backup_113.csv >> $BACKUP_DIR/devices_backup_113.sql
echo -e "${GREEN}✅ Backup created${NC}"
echo ""

echo -e "${BLUE}[4/6] Clearing devices table on 113${NC}"
docker exec enms_demo_postgres psql -U reg_ml_demo -d reg_ml_demo << 'EOSQL'
-- Disable triggers temporarily to avoid foreign key issues
SET session_replication_role = 'replica';

-- Clear devices and related tables
TRUNCATE TABLE devices CASCADE;

-- Re-enable triggers
SET session_replication_role = 'origin';

\echo 'Devices table cleared'
EOSQL

echo -e "${GREEN}✅ Devices table cleared on 113${NC}"
echo ""

echo -e "${BLUE}[5/6] Importing active devices to 113${NC}"

# Copy the CSV to 113's postgres container
docker cp $BACKUP_DIR/devices_export.sql enms_demo_postgres:/tmp/active_devices.csv

# Import the devices
docker exec enms_demo_postgres psql -U reg_ml_demo -d reg_ml_demo << 'EOSQL'
-- Import devices
\COPY devices FROM '/tmp/active_devices.csv' WITH CSV HEADER;

-- Verify import
SELECT COUNT(*) as imported_devices FROM devices;
\q
EOSQL

echo -e "${GREEN}✅ Active devices imported to 113${NC}"
echo ""

echo -e "${BLUE}[6/6] Verification${NC}"
echo ""

echo "Device counts:"
echo "─────────────"

# Count on 109
DEVICES_109=$(ssh ubuntu@$SOURCE_SERVER "docker exec enms_demo_postgres psql -U reg_ml_demo -d reg_ml_demo -t -c \"SELECT COUNT(*) FROM devices WHERE device_id IN (SELECT DISTINCT device_id FROM printer_status WHERE timestamp > NOW() - INTERVAL '7 days');\"" | tr -d ' ')
echo -e "Active devices on 109: ${GREEN}$DEVICES_109${NC}"

# Count on 113
DEVICES_113=$(docker exec enms_demo_postgres psql -U reg_ml_demo -d reg_ml_demo -t -c "SELECT COUNT(*) FROM devices;" | tr -d ' ')
echo -e "Devices on 113:        ${GREEN}$DEVICES_113${NC}"

echo ""

if [ "$DEVICES_109" = "$DEVICES_113" ]; then
    echo -e "${GREEN}✅ SUCCESS! Device counts match${NC}"
else
    echo -e "${YELLOW}⚠️  Device counts differ. This might be expected if some devices became inactive.${NC}"
fi

echo ""
echo "Testing API endpoint..."
RESPONSE=$(curl -s http://localhost:8090/api/dpp_summary | jq -r '.success' 2>/dev/null || echo "false")

if [ "$RESPONSE" = "true" ]; then
    echo -e "${GREEN}✅ API working correctly${NC}"
    echo ""
    echo "Device list from API:"
    curl -s http://localhost:8090/api/dpp_summary | jq -r '.devices[] | "  - \(.friendly_name) (\(.device_model))"' | head -15
else
    echo -e "${RED}❌ API still has errors. Checking logs...${NC}"
    echo ""
    docker logs enms_demo_python_api --tail 20
fi

echo ""
echo "════════════════════════════════════════════════════════════"
echo -e "${GREEN}Device migration fix completed!${NC}"
echo "════════════════════════════════════════════════════════════"
echo ""
echo "Backup location: $BACKUP_DIR"
echo ""
echo "Next steps:"
echo "  1. Test Device Management page: http://10.33.10.113:8090/device_management.html"
echo "  2. Test Interactive Analysis: http://10.33.10.113:8090/analysis/analysis_page.html"
echo "  3. Test DPP page: http://10.33.10.113:8090/dpp_page.html"
echo ""
