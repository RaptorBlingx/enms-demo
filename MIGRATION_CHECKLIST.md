# ✅ ENMS-Demo Migration Execution Checklist

**Migration:** 10.33.10.109 → 10.33.10.113  
**Date:** _______________  
**Executed by:** _______________  
**Start time:** _______________  

---

## 📋 PRE-MIGRATION PHASE

### Source Server Validation (10.33.10.109)

- [ ] SSH access confirmed: `ssh ubuntu@10.33.10.109`
- [ ] Run validation script: `./validate_before_migration.sh`
- [ ] Review validation report (all checks should pass)
- [ ] Docker containers all running (6+)
- [ ] Data generator service active
- [ ] Database accessible
- [ ] API responding
- [ ] Grafana dashboards loading
- [ ] Recent data present (last 5 minutes)
- [ ] Disk space adequate (>10GB free)
- [ ] Backup validation report saved

**Record Current State:**
- Container count: _______
- Device count: _______
- Print jobs count: _______
- Latest data timestamp: _______________
- Database size: _______
- Total disk usage: _______

**Issues Found:** ☐ None  ☐ Minor  ☐ Major

**Notes:**
```




```

---

## 🚀 DEPLOYMENT PHASE

### Target Server Setup (10.33.10.113)

- [ ] SSH access confirmed: `ssh ubuntu@10.33.10.113`
- [ ] Server has internet connectivity
- [ ] Sufficient disk space (>30GB free)
- [ ] Sufficient RAM (>8GB)
- [ ] Ports available (8090, 3002, 1882, 5434, 1884, 5000)

### Transfer Deployment Script

- [ ] Copy script to new server:
  ```bash
  scp ubuntu@10.33.10.109:/home/ubuntu/enms-demo/deploy_to_new_server.sh /tmp/
  chmod +x /tmp/deploy_to_new_server.sh
  ```

### Run Deployment

- [ ] Start deployment: `/tmp/deploy_to_new_server.sh`
- [ ] Monitor script output for errors
- [ ] Script completed successfully
- [ ] Note completion time: _______________

**Deployment Output:**
- Containers running: _______
- Database restored: ☐ Yes  ☐ No
- Device count matches: ☐ Yes  ☐ No
- Services started: ☐ Yes  ☐ No

**Issues During Deployment:** ☐ None  ☐ Minor  ☐ Major

**Notes:**
```




```

---

## 🔍 INITIAL VERIFICATION (Within 30 minutes)

### Docker Services

- [ ] Check container status: `docker compose ps`
- [ ] All 6+ containers running
- [ ] No containers in restart loop
- [ ] PostgreSQL health: `docker inspect enms_demo_postgres | grep Health`
- [ ] Node-RED health: `docker inspect enms_demo_nodered | grep Health`

### Database Verification

- [ ] Database accessible
- [ ] Device count matches source: _______
- [ ] Print jobs count matches: _______
- [ ] Recent data being generated
- [ ] No import errors in logs

**SQL Verification:**
```bash
docker exec enms_demo_postgres psql -U reg_ml_demo -d reg_ml_demo -c "
SELECT 
  'devices' as table_name, COUNT(*) FROM devices
  UNION ALL SELECT 'print_jobs', COUNT(*) FROM print_jobs
  UNION ALL SELECT 'printer_status', COUNT(*) FROM printer_status;
"
```

Results:
- devices: _______
- print_jobs: _______
- printer_status: _______

### API Endpoints

- [ ] Web interface (8090): http://10.33.10.113:8090
  - Status code: _______
  - Load time: _______
- [ ] API summary: http://10.33.10.113:8090/api/dpp_summary
  - Response: ☐ Success  ☐ Failed
  - Device count: _______
- [ ] API devices: http://10.33.10.113:5000/api/devices
  - Response: ☐ Success  ☐ Failed

### Grafana

- [ ] Grafana accessible: http://10.33.10.113:3002
- [ ] Health endpoint: `curl http://localhost:3002/api/health`
  - Database: ☐ ok  ☐ failed
- [ ] Login successful (admin credentials from .env)
- [ ] All dashboards visible (5 dashboards expected)
- [ ] Sample dashboard loads data

### Node-RED

- [ ] Node-RED accessible: http://10.33.10.113:1882
- [ ] Flows loaded successfully
- [ ] No error nodes visible
- [ ] MQTT connection active (check debug)

### Data Generation

- [ ] Data generator service running
  ```bash
  sudo systemctl status demo-data-generator.service
  ```
- [ ] Recent log entries showing updates
- [ ] New printer status records being created
- [ ] MQTT messages flowing

### System Resources

- [ ] CPU usage reasonable (<50% idle)
- [ ] Memory usage reasonable (>2GB free)
- [ ] Disk space adequate (>20GB free)
- [ ] No port conflicts

**Issues Found:** ☐ None  ☐ Minor  ☐ Major

**Notes:**
```




```

---

## 🧪 FUNCTIONAL TESTING (1-2 hours later)

### End-to-End Tests

- [ ] **Test 1: View dashboard**
  - Open http://10.33.10.113:8090
  - Verify printer list displays
  - Check status indicators working
  
- [ ] **Test 2: DPP page**
  - Open http://10.33.10.113:8090/dpp_page.html
  - Verify print jobs listed
  - Check job details display
  
- [ ] **Test 3: Generate PDF**
  - Select a completed print job
  - Click "Generate PDF"
  - Verify PDF downloads
  - Open PDF and verify content
  
- [ ] **Test 4: Grafana dashboards**
  - Open each dashboard:
    - [ ] Fleet Operations
    - [ ] Machine Performance
    - [ ] Sensor Data Explorer
    - [ ] Industrial Hybrid Edge
    - [ ] ESP32 Motion Analysis
  - Verify all panels load
  - Check for "No data" errors
  
- [ ] **Test 5: Node-RED flows**
  - Check MQTT input node (should show "connected")
  - Check database nodes (no errors)
  - Deploy flows (should succeed)
  - Watch debug output (data flowing)
  
- [ ] **Test 6: Analysis page**
  - Open http://10.33.10.113:8090/analysis/analysis_page.html
  - Select a device
  - Verify charts display
  - Check anomaly detection working
  
- [ ] **Test 7: API authentication**
  - Test protected endpoints
  - Verify JWT tokens working

### Data Consistency Tests

- [ ] Compare device list (109 vs 113)
  ```bash
  # On 109
  curl -s http://localhost:8090/api/dpp_summary | jq '.devices | length'
  
  # On 113
  curl -s http://localhost:8090/api/dpp_summary | jq '.devices | length'
  ```
  - Result: ☐ Match  ☐ Mismatch
  
- [ ] Compare latest print job IDs
- [ ] Verify plant growth images loading
- [ ] Check ML predictions generating

### Performance Tests

- [ ] API response time < 500ms
  ```bash
  time curl -s http://localhost:8090/api/dpp_summary > /dev/null
  ```
  - Time: _______
  
- [ ] Dashboard load time < 2s
- [ ] Grafana query time reasonable
- [ ] PDF generation < 5s
- [ ] Database query performance

**Test Results:** ☐ All Passed  ☐ Some Failed

**Failed Tests:**
```




```

---

## 📊 PARALLEL MONITORING (24-48 hours)

### Daily Health Checks

**Day 1 Checks:**
- [ ] Morning check (9 AM)
  - All containers running: ☐ Yes  ☐ No
  - Data generator active: ☐ Yes  ☐ No
  - No errors in logs: ☐ Yes  ☐ No
  - API responding: ☐ Yes  ☐ No
  
- [ ] Afternoon check (3 PM)
  - System stable: ☐ Yes  ☐ No
  - Resource usage normal: ☐ Yes  ☐ No
  - Users report issues: ☐ None  ☐ Some
  
- [ ] Evening check (9 PM)
  - Uptime maintained: ☐ Yes  ☐ No
  - Logs clean: ☐ Yes  ☐ No

**Day 2 Checks:**
- [ ] Morning check
  - 24hr stability confirmed: ☐ Yes  ☐ No
  - Performance baseline: ☐ Normal  ☐ Degraded
  
- [ ] Final pre-cutover check
  - Ready for DNS switch: ☐ Yes  ☐ No
  - Source server still running: ☐ Yes  ☐ No

### Monitoring Commands

```bash
# Run these periodically on 113

# 1. Container status
docker compose ps

# 2. Resource usage
docker stats --no-stream

# 3. Error log check
docker compose logs --since 1h | grep -i error

# 4. Data generation rate
docker exec enms_demo_postgres psql -U reg_ml_demo -d reg_ml_demo -c "
SELECT COUNT(*) FROM printer_status WHERE timestamp > NOW() - INTERVAL '1 hour';
"

# 5. System resources
htop  # or top
df -h
free -h
```

**Issues During Monitoring:**
```




```

---

## 🌐 DNS CUTOVER

### Pre-Cutover Validation

- [ ] New server stable for 24+ hours
- [ ] All functional tests passing
- [ ] Performance acceptable
- [ ] Team approval obtained
- [ ] Rollback plan reviewed
- [ ] Communication sent to users

### DNS Update

- [ ] Lower DNS TTL to 300 seconds (done 24h prior)
- [ ] Update A record for lauds-demo.intel50001.com
  - From: 10.33.10.109
  - To: 10.33.10.113
- [ ] Record update time: _______________

### Cutover Verification

- [ ] Wait 5-15 minutes for propagation
- [ ] Test DNS resolution:
  ```bash
  dig lauds-demo.intel50001.com
  nslookup lauds-demo.intel50001.com
  ```
- [ ] Test from external network
  ```bash
  curl https://lauds-demo.intel50001.com
  ```
- [ ] Verify traffic going to new server
  ```bash
  # On 113
  sudo netstat -an | grep :8090 | wc -l
  ```
- [ ] Monitor logs on new server for errors
- [ ] Check old server for stray traffic
  ```bash
  # On 109
  sudo netstat -an | grep :8090 | wc -l
  ```

**Cutover Status:** ☐ Success  ☐ Issues  ☐ Rolled Back

**Notes:**
```




```

---

## 🔄 POST-CUTOVER MONITORING (7 days)

### First 24 Hours After Cutover

**Hour 1-2:**
- [ ] Heavy monitoring of logs
- [ ] Check for spikes in errors
- [ ] Verify user traffic flowing
- [ ] Response times normal

**Hour 3-6:**
- [ ] System stability confirmed
- [ ] No performance degradation
- [ ] Users reporting success

**Hour 12-24:**
- [ ] Full day of operation completed
- [ ] No critical issues
- [ ] Performance baseline maintained

### Days 2-7

- [ ] **Day 2:** Daily health check ☐
- [ ] **Day 3:** Daily health check ☐
- [ ] **Day 4:** Daily health check ☐
- [ ] **Day 5:** Daily health check ☐
- [ ] **Day 6:** Daily health check ☐
- [ ] **Day 7:** Final validation ☐

### Backup Schedule

- [ ] Automated daily backups configured
- [ ] Backup script tested
- [ ] Cron job active
- [ ] Backup retention policy set (7 days)

```bash
# Verify backup cron
crontab -l | grep backup

# Test manual backup
/home/ubuntu/enms-demo/backup_daily.sh
```

**Post-Cutover Issues:**
```




```

---

## 📦 DECOMMISSION OLD SERVER (After 7 days)

### Final Validation

- [ ] New server stable for 7+ days
- [ ] Zero critical issues reported
- [ ] All stakeholders satisfied
- [ ] No need to access old server

### Decommission Steps

- [ ] Stop data generator on old server (109)
  ```bash
  sudo systemctl stop demo-data-generator.service
  sudo systemctl disable demo-data-generator.service
  ```

- [ ] Create final backup
  ```bash
  cd /home/ubuntu/enms-demo
  docker exec enms_demo_postgres pg_dump -U reg_ml_demo -d reg_ml_demo -F c > \
    backups/final_backup_$(date +%Y%m%d).dump
  ```

- [ ] Archive complete project
  ```bash
  tar czf /tmp/enms-demo-archive-$(date +%Y%m%d).tar.gz \
    /home/ubuntu/enms-demo
  ```

- [ ] Transfer final archive to new server
  ```bash
  scp /tmp/enms-demo-archive-*.tar.gz ubuntu@10.33.10.113:/home/ubuntu/backups/
  ```

- [ ] Stop all Docker services
  ```bash
  docker compose down
  ```

- [ ] Remove Docker volumes (optional)
  ```bash
  docker volume ls | grep demo
  # docker volume rm <volume_name>  # if needed for space
  ```

- [ ] Update documentation
- [ ] Notify team of decommission completion

**Decommission Date:** _______________  
**Completed by:** _______________

---

## 📈 SUCCESS METRICS

### Final Statistics

| Metric | Target | Actual | Status |
|--------|--------|--------|--------|
| Total downtime | 0 minutes | _______ | ☐ Met ☐ Not Met |
| Data loss | 0 records | _______ | ☐ Met ☐ Not Met |
| API response time | <500ms | _______ | ☐ Met ☐ Not Met |
| Deployment time | <2 hours | _______ | ☐ Met ☐ Not Met |
| Critical issues | 0 | _______ | ☐ Met ☐ Not Met |
| User complaints | 0 | _______ | ☐ Met ☐ Not Met |

### Performance Comparison

| Metric | Old Server (109) | New Server (113) | Change |
|--------|------------------|------------------|--------|
| API response | _______ ms | _______ ms | _______ |
| Dashboard load | _______ s | _______ s | _______ |
| Query time | _______ ms | _______ ms | _______ |
| CPU usage | _______ % | _______ % | _______ |
| Memory usage | _______ GB | _______ GB | _______ |

---

## 📝 LESSONS LEARNED

### What Went Well
```




```

### What Could Be Improved
```




```

### Recommendations for Future Migrations
```




```

---

## ✅ FINAL SIGN-OFF

**Migration Status:** ☐ Complete  ☐ Incomplete  ☐ Failed

**Overall Assessment:**
```




```

**Completed by:** _______________  
**Date:** _______________  
**Signature:** _______________

**Approved by:** _______________  
**Date:** _______________  
**Signature:** _______________

---

**Document Version:** 1.0  
**Last Updated:** November 6, 2025  
**Project:** ENMS-Demo Migration
