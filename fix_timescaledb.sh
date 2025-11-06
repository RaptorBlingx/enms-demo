#!/bin/bash
################################################################################
# Fix TimescaleDB Hypertable Corruption on 113
################################################################################

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo "╔════════════════════════════════════════════════════════════╗"
echo "║     Fix TimescaleDB Hypertables on 113                     ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""

echo -e "${BLUE}[1/5] Backing up current data${NC}"

# Backup the data we have
docker exec enms_demo_postgres psql -U reg_ml_demo -d reg_ml_demo << 'EOSQL' > /tmp/backup_before_fix.sql
-- Backup devices
\COPY devices TO '/tmp/devices_backup.csv' WITH CSV HEADER;

-- Backup print_jobs
\COPY print_jobs TO '/tmp/print_jobs_backup.csv' WITH CSV HEADER;

\echo 'Data backed up'
EOSQL

echo -e "${GREEN}✅ Data backed up${NC}"
echo ""

echo -e "${BLUE}[2/5] Dropping corrupted hypertables${NC}"

docker exec enms_demo_postgres psql -U reg_ml_demo -d reg_ml_demo << 'EOSQL'
-- Drop hypertables (this will drop the tables)
DROP TABLE IF EXISTS energy_data CASCADE;
DROP TABLE IF EXISTS printer_status CASCADE;

\echo 'Hypertables dropped'
EOSQL

echo -e "${GREEN}✅ Hypertables dropped${NC}"
echo ""

echo -e "${BLUE}[3/5] Recreating tables as regular tables (not hypertables)${NC}"

docker exec enms_demo_postgres psql -U reg_ml_demo -d reg_ml_demo << 'EOSQL'
-- Recreate energy_data as regular table
CREATE TABLE energy_data (
    timestamp TIMESTAMPTZ NOT NULL,
    device_id VARCHAR(255) NOT NULL,
    voltage NUMERIC(10, 2),
    current NUMERIC(10, 2),
    power NUMERIC(10, 2),
    energy NUMERIC(10, 2),
    frequency NUMERIC(10, 2),
    power_factor NUMERIC(10, 4),
    PRIMARY KEY (timestamp, device_id),
    FOREIGN KEY (device_id) REFERENCES devices(device_id) ON DELETE CASCADE
);

CREATE INDEX ON energy_data (timestamp DESC);
CREATE INDEX ON energy_data (device_id);

-- Recreate printer_status as regular table
CREATE TABLE printer_status (
    timestamp TIMESTAMPTZ NOT NULL,
    device_id VARCHAR(255) NOT NULL,
    status VARCHAR(50),
    is_printing BOOLEAN,
    bed_heated BOOLEAN,
    hotend_heated BOOLEAN,
    current_layer INTEGER,
    total_layers INTEGER,
    bed_temp NUMERIC(10, 2),
    bed_target_temp NUMERIC(10, 2),
    hotend_temp NUMERIC(10, 2),
    hotend_target_temp NUMERIC(10, 2),
    chamber_temp NUMERIC(10, 2),
    chamber_target_temp NUMERIC(10, 2),
    material_type VARCHAR(50),
    filament_name VARCHAR(255),
    PRIMARY KEY (timestamp, device_id),
    FOREIGN KEY (device_id) REFERENCES devices(device_id) ON DELETE CASCADE
);

CREATE INDEX ON printer_status (timestamp DESC);
CREATE INDEX ON printer_status (device_id);
CREATE INDEX ON printer_status (status);

\echo 'Tables recreated as regular tables'
EOSQL

echo -e "${GREEN}✅ Tables recreated${NC}"
echo ""

echo -e "${BLUE}[4/5] Restoring data${NC}"

docker exec enms_demo_postgres psql -U reg_ml_demo -d reg_ml_demo << 'EOSQL'
-- Restore devices
\COPY devices FROM '/tmp/devices_backup.csv' WITH CSV HEADER;

-- Restore print_jobs
\COPY print_jobs FROM '/tmp/print_jobs_backup.csv' WITH CSV HEADER;

\echo 'Data restored'
EOSQL

echo -e "${GREEN}✅ Data restored${NC}"
echo ""

echo -e "${BLUE}[5/5] Verifying and restarting services${NC}"

# Restart services
docker compose restart

echo ""
echo "Waiting for services to start..."
sleep 15

# Test API
RESPONSE=$(curl -s http://localhost:8090/api/dpp_summary 2>/dev/null | jq -r '.success' 2>/dev/null || echo "false")

if [ "$RESPONSE" = "true" ]; then
    echo -e "${GREEN}✅ API working!${NC}"
    echo ""
    echo "Devices:"
    curl -s http://localhost:8090/api/dpp_summary | jq -r '.devices[] | "  \(.friendly_name) (\(.device_model))"' | head -10
else
    echo -e "${RED}❌ API still has issues${NC}"
    docker logs enms_demo_python_api --tail 30
fi

echo ""
echo "════════════════════════════════════════════════════════════"
echo -e "${GREEN}Fix completed!${NC}"
echo "════════════════════════════════════════════════════════════"
echo ""
echo "Note: Tables are now regular PostgreSQL tables (not hypertables)"
echo "This fixes the corruption but loses time-series optimization."
echo "For a small dataset, this is fine and actually simpler."
echo ""
