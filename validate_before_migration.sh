#!/bin/bash
################################################################################
# Pre-Migration Validation Script for Source Server (10.33.10.109)
# Run this BEFORE migration to document current state
################################################################################

set -e

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

REPORT_FILE="pre_migration_report_$(date +%Y%m%d_%H%M%S).txt"

echo "╔════════════════════════════════════════════════════════════╗"
echo "║  ENMS-Demo Pre-Migration Validation Report                ║"
echo "║  Server: 10.33.10.109                                      ║"
echo "║  Date: $(date)                                 ║"
echo "╚════════════════════════════════════════════════════════════╝"

{
echo "="
echo "PRE-MIGRATION VALIDATION REPORT"
echo "Generated: $(date)"
echo "Server: $(hostname)"
echo "IP: $(hostname -I)"
echo "="
echo ""

echo "1. SYSTEM INFORMATION"
echo "---------------------"
echo "OS: $(lsb_release -d | cut -f2)"
echo "Kernel: $(uname -r)"
echo "Uptime: $(uptime -p)"
echo "Disk Usage:"
df -h | grep -E "Filesystem|/$|/var"
echo ""

echo "2. DOCKER STATUS"
echo "----------------"
echo "Docker Version: $(docker --version)"
echo "Docker Compose Version: $(docker compose version)"
echo ""
echo "Running Containers:"
docker ps --filter "name=enms_demo" --format "table {{.Names}}\t{{.Status}}\t{{.Size}}"
echo ""
echo "Container Health:"
for container in $(docker ps --filter "name=enms_demo" --format "{{.Names}}"); do
    health=$(docker inspect --format='{{.State.Health.Status}}' $container 2>/dev/null || echo "no healthcheck")
    echo "  $container: $health"
done
echo ""

echo "3. DOCKER VOLUMES"
echo "-----------------"
docker volume ls | grep demo
echo ""
echo "Volume Sizes:"
for vol in $(docker volume ls -q | grep demo); do
    size=$(docker run --rm -v $vol:/data alpine du -sh /data 2>/dev/null | cut -f1 || echo "N/A")
    echo "  $vol: $size"
done
echo ""

echo "4. SYSTEMD SERVICES"
echo "-------------------"
systemctl list-units --type=service --all | grep -i enms || echo "No ENMS systemd services found"
echo ""
echo "Data Generator Service:"
systemctl status demo-data-generator.service --no-pager || echo "Service not found"
echo ""

echo "5. DATABASE STATUS"
echo "------------------"
echo "PostgreSQL Connection: $(docker exec enms_demo_postgres pg_isready -U reg_ml_demo || echo 'FAILED')"
echo ""
echo "Database Size:"
docker exec enms_demo_postgres psql -U reg_ml_demo -d reg_ml_demo -c "\l+ reg_ml_demo" | grep reg_ml_demo
echo ""
echo "Table Sizes:"
docker exec enms_demo_postgres psql -U reg_ml_demo -d reg_ml_demo -c "\dt+"
echo ""
echo "Record Counts:"
echo "  Devices: $(docker exec enms_demo_postgres psql -U reg_ml_demo -d reg_ml_demo -t -c 'SELECT COUNT(*) FROM devices;' | tr -d ' ')"
echo "  Print Jobs: $(docker exec enms_demo_postgres psql -U reg_ml_demo -d reg_ml_demo -t -c 'SELECT COUNT(*) FROM print_jobs;' | tr -d ' ')"
echo "  Printer Status: $(docker exec enms_demo_postgres psql -U reg_ml_demo -d reg_ml_demo -t -c 'SELECT COUNT(*) FROM printer_status;' | tr -d ' ')"
echo "  Energy Data: $(docker exec enms_demo_postgres psql -U reg_ml_demo -d reg_ml_demo -t -c 'SELECT COUNT(*) FROM energy_data;' | tr -d ' ')"
echo "  Sensor Data: $(docker exec enms_demo_postgres psql -U reg_ml_demo -d reg_ml_demo -t -c 'SELECT COUNT(*) FROM sensor_data;' | tr -d ' ')"
echo "  ML Predictions: $(docker exec enms_demo_postgres psql -U reg_ml_demo -d reg_ml_demo -t -c 'SELECT COUNT(*) FROM ml_predictions;' | tr -d ' ')"
echo ""
echo "Latest Data Timestamp:"
docker exec enms_demo_postgres psql -U reg_ml_demo -d reg_ml_demo -c "SELECT MAX(timestamp) as latest_data FROM printer_status;"
echo ""

echo "6. API HEALTH CHECKS"
echo "--------------------"
echo "Web Server (port 8090):"
curl -s -o /dev/null -w "  Status: %{http_code}, Time: %{time_total}s\n" http://localhost:8090/ || echo "  FAILED"
echo ""
echo "API Summary Endpoint:"
curl -s http://localhost:8090/api/dpp_summary | jq -r '"  Success: \(.success), Devices: \(.devices | length)"' 2>/dev/null || echo "  FAILED"
echo ""
echo "Grafana (port 3002):"
curl -s http://localhost:3002/api/health | jq -r '"  Database: \(.database), Version: \(.version)"' 2>/dev/null || echo "  FAILED"
echo ""
echo "Node-RED (port 1882):"
curl -s -o /dev/null -w "  Status: %{http_code}\n" http://localhost:1882/ || echo "  FAILED"
echo ""

echo "7. NETWORK & PORTS"
echo "------------------"
echo "Listening Ports:"
sudo netstat -tulpn | grep -E "8090|3002|1882|5434|1884|5000" | awk '{print "  " $4 " -> " $7}'
echo ""

echo "8. PROJECT FILES"
echo "----------------"
echo "Project Directory: /home/ubuntu/enms-demo"
echo "Directory Size: $(du -sh /home/ubuntu/enms-demo | cut -f1)"
echo ""
echo "Key Files:"
ls -lh /home/ubuntu/enms-demo/.env 2>/dev/null || echo "  .env: NOT FOUND"
ls -lh /home/ubuntu/enms-demo/docker-compose.yml
ls -lh /home/ubuntu/enms-demo/node-red/flows.json
echo ""
echo "Backend Models:"
ls -lh /home/ubuntu/enms-demo/backend/models/ | tail -n +2
echo ""
echo "Grafana Dashboards:"
ls -1 /home/ubuntu/enms-demo/grafana/dashboards/ | wc -l | awk '{print "  Count: " $1}'
echo ""

echo "9. RESOURCE USAGE"
echo "-----------------"
echo "Memory:"
free -h
echo ""
echo "CPU Load:"
uptime
echo ""
echo "Docker Stats (snapshot):"
docker stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}" $(docker ps --filter "name=enms_demo" --format "{{.Names}}")
echo ""

echo "10. RECENT LOGS (Last 10 lines per service)"
echo "--------------------------------------------"
for service in postgres mosquitto nodered grafana python_api ml_worker web_server; do
    echo ""
    echo "=== enms_demo_$service ==="
    docker logs --tail 10 enms_demo_$service 2>/dev/null || echo "  No logs or container not found"
done
echo ""

echo "11. BACKUP RECOMMENDATION"
echo "-------------------------"
echo "Recommended backup size estimate:"
echo "  Database: ~$(docker exec enms_demo_postgres psql -U reg_ml_demo -d reg_ml_demo -t -c "SELECT pg_size_pretty(pg_database_size('reg_ml_demo'));" | tr -d ' ')"
echo "  Total Docker volumes: ~$(docker system df -v | grep 'Local Volumes' | awk '{print $4}')"
echo "  Project files: $(du -sh /home/ubuntu/enms-demo | cut -f1)"
echo ""

echo "12. VALIDATION CHECKLIST"
echo "------------------------"
CHECKS=0
PASSED=0

# Check 1: All containers running
CONTAINER_COUNT=$(docker ps --filter "name=enms_demo" --format "{{.Names}}" | wc -l)
CHECKS=$((CHECKS + 1))
if [ "$CONTAINER_COUNT" -ge 6 ]; then
    echo "  ✅ All Docker containers running ($CONTAINER_COUNT/6+)"
    PASSED=$((PASSED + 1))
else
    echo "  ❌ Missing Docker containers ($CONTAINER_COUNT/6)"
fi

# Check 2: Database accessible
CHECKS=$((CHECKS + 1))
if docker exec enms_demo_postgres pg_isready -U reg_ml_demo &>/dev/null; then
    echo "  ✅ Database accessible"
    PASSED=$((PASSED + 1))
else
    echo "  ❌ Database not accessible"
fi

# Check 3: Data generator service
CHECKS=$((CHECKS + 1))
if systemctl is-active --quiet demo-data-generator.service; then
    echo "  ✅ Data generator service active"
    PASSED=$((PASSED + 1))
else
    echo "  ❌ Data generator service not active"
fi

# Check 4: Web server responding
CHECKS=$((CHECKS + 1))
if curl -s -f http://localhost:8090/ &>/dev/null; then
    echo "  ✅ Web server responding"
    PASSED=$((PASSED + 1))
else
    echo "  ❌ Web server not responding"
fi

# Check 5: API responding
CHECKS=$((CHECKS + 1))
if curl -s http://localhost:8090/api/dpp_summary | jq -e '.success' &>/dev/null; then
    echo "  ✅ API responding correctly"
    PASSED=$((PASSED + 1))
else
    echo "  ❌ API not responding correctly"
fi

# Check 6: Grafana healthy
CHECKS=$((CHECKS + 1))
if curl -s http://localhost:3002/api/health | jq -e '.database == "ok"' &>/dev/null; then
    echo "  ✅ Grafana healthy"
    PASSED=$((PASSED + 1))
else
    echo "  ❌ Grafana not healthy"
fi

# Check 7: Recent data exists
RECENT_DATA=$(docker exec enms_demo_postgres psql -U reg_ml_demo -d reg_ml_demo -t -c "SELECT COUNT(*) FROM printer_status WHERE timestamp > NOW() - INTERVAL '5 minutes';" 2>/dev/null | tr -d ' ')
CHECKS=$((CHECKS + 1))
if [ -n "$RECENT_DATA" ] && [ "$RECENT_DATA" -gt 0 ]; then
    echo "  ✅ Recent data being generated ($RECENT_DATA records in last 5 min)"
    PASSED=$((PASSED + 1))
else
    echo "  ❌ No recent data detected"
fi

echo ""
echo "OVERALL HEALTH: $PASSED/$CHECKS checks passed"
if [ "$PASSED" -eq "$CHECKS" ]; then
    echo "✅ System is healthy and ready for migration!"
elif [ "$PASSED" -ge $((CHECKS * 3 / 4)) ]; then
    echo "⚠️  System is mostly healthy but has some issues"
else
    echo "❌ System has significant issues - resolve before migration"
fi
echo ""

echo "="
echo "END OF REPORT"
echo "Report saved to: $REPORT_FILE"
echo "="

} | tee "$REPORT_FILE"

echo ""
echo -e "${GREEN}✅ Pre-migration validation complete!${NC}"
echo -e "${BLUE}📄 Report saved to: $REPORT_FILE${NC}"
echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo "  1. Review this report for any issues"
echo "  2. Fix any failed checks"
echo "  3. Transfer this report to the new server"
echo "  4. Run the deployment script on new server"
echo ""
