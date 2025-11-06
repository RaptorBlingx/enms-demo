# ENMS-Demo Migration Quick Reference

## 🚀 Zero-Touch Migration Summary

**Migration Path:** 10.33.10.109 → 10.33.10.113  
**Strategy:** Parallel deployment with zero downtime  
**Duration:** 1-2 hours setup + 7 days monitoring  

---

## 📋 Quick Start Guide

### On SOURCE Server (10.33.10.109)

```bash
# 1. Run pre-migration validation
cd /home/ubuntu/enms-demo
./validate_before_migration.sh

# 2. Review the report
# Fix any issues before proceeding

# 3. Keep server running (do NOT stop services)
```

### On TARGET Server (10.33.10.113)

```bash
# 1. SSH to new server
ssh ubuntu@10.33.10.113

# 2. Run the zero-touch deployment script
# This will:
#   - Install all prerequisites
#   - Clone the project
#   - Transfer configuration and data
#   - Start all services
#   - Run health checks

# Copy the deployment script first:
scp ubuntu@10.33.10.109:/home/ubuntu/enms-demo/deploy_to_new_server.sh /tmp/

# Or download directly if in git:
# wget https://gitlab.com/raptorblingx/enms-demo/-/raw/main/deploy_to_new_server.sh

# 3. Run deployment
chmod +x /tmp/deploy_to_new_server.sh
/tmp/deploy_to_new_server.sh

# The script will guide you through the process
# Estimated time: 30-60 minutes
```

---

## ✅ What the Script Does Automatically

1. ✅ Installs Docker and dependencies
2. ✅ Clones project from source server
3. ✅ Transfers `.env` configuration
4. ✅ Migrates database (all historical data)
5. ✅ Transfers ML models and assets
6. ✅ Starts all Docker services
7. ✅ Configures systemd services
8. ✅ Runs comprehensive health checks
9. ✅ Provides access URLs and next steps

---

## 🎯 Post-Deployment Checklist

After the script completes:

```bash
# On new server (10.33.10.113)
cd /home/ubuntu/enms-demo

# 1. Verify all containers running
docker compose ps

# 2. Test the web interface
# Open in browser: http://10.33.10.113:8090

# 3. Test Grafana dashboards
# Open in browser: http://10.33.10.113:3002

# 4. Check data generation
sudo journalctl -u demo-data-generator.service -f

# 5. Compare with source server
# Devices count should match
curl http://10.33.10.109:8090/api/dpp_summary | jq '.devices | length'
curl http://10.33.10.113:8090/api/dpp_summary | jq '.devices | length'

# 6. Monitor logs for 1 hour
docker compose logs -f
```

---

## 🌐 DNS Cutover (After Testing)

Only proceed after 24-48 hours of successful operation:

```bash
# 1. Update DNS record
# lauds-demo.intel50001.com A record: 10.33.10.113

# 2. Verify DNS propagation
dig lauds-demo.intel50001.com
nslookup lauds-demo.intel50001.com

# 3. Test from external network
curl https://lauds-demo.intel50001.com

# 4. Monitor both servers
# Keep 10.33.10.109 running for quick rollback
```

---

## 🔄 Quick Rollback (If Needed)

```bash
# Emergency rollback steps:

# 1. Update DNS back to old server
# lauds-demo.intel50001.com A record: 10.33.10.109

# 2. Verify old server is still running
ssh ubuntu@10.33.10.109
docker compose ps

# 3. Test old server
curl http://10.33.10.109:8090/api/dpp_summary

# 4. Announce rollback completed
# 5. Investigate issues on new server
```

---

## 📊 Expected Results

### Validation Script Output
```
OVERALL HEALTH: 7/7 checks passed
✅ System is healthy and ready for migration!
```

### Deployment Script Output
```
✅ DEPLOYMENT COMPLETED SUCCESSFULLY!

📍 Access Points:
   Web Interface: http://10.33.10.113:8090
   Grafana:       http://10.33.10.113:3002
   Node-RED:      http://10.33.10.113:1882

📊 System Status:
   Docker Containers: 6 running
   Database: 33 devices, XXX print jobs
   Data Generator: active
```

---

## 🛠️ Troubleshooting

### Issue: Docker not installed
```bash
# Solution: Script will install automatically
# Or manually:
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
sudo usermod -aG docker ubuntu
newgrp docker
```

### Issue: Database import fails
```bash
# Check database logs
docker compose logs postgres

# Retry import manually
cd /home/ubuntu/enms-demo
docker cp backups/migration_*/db_backup.sql enms_demo_postgres:/tmp/
docker exec enms_demo_postgres psql -U reg_ml_demo -d reg_ml_demo -f /tmp/db_backup.sql
```

### Issue: Containers not starting
```bash
# Check logs
docker compose logs

# Check disk space
df -h

# Restart services
cd /home/ubuntu/enms-demo
docker compose down
docker compose up -d
```

### Issue: No data being generated
```bash
# Check data generator service
sudo systemctl status demo-data-generator.service
sudo journalctl -u demo-data-generator.service -n 50

# Restart service
sudo systemctl restart demo-data-generator.service
```

---

## 📞 Key Commands

### Service Management
```bash
# View all services
docker compose ps

# Restart a service
docker compose restart <service_name>

# View logs
docker compose logs -f
docker compose logs <service_name>

# Check systemd service
sudo systemctl status demo-data-generator.service
sudo journalctl -u demo-data-generator.service -f
```

### Database Operations
```bash
# Connect to database
docker exec -it enms_demo_postgres psql -U reg_ml_demo -d reg_ml_demo

# Check record counts
docker exec enms_demo_postgres psql -U reg_ml_demo -d reg_ml_demo -c "
SELECT 
  'devices' as table_name, COUNT(*) FROM devices
  UNION ALL
SELECT 'print_jobs', COUNT(*) FROM print_jobs
  UNION ALL
SELECT 'printer_status', COUNT(*) FROM printer_status;
"

# Backup database
docker exec enms_demo_postgres pg_dump -U reg_ml_demo -d reg_ml_demo > backup.sql
```

### Health Checks
```bash
# Test all endpoints
curl http://localhost:8090/
curl http://localhost:8090/api/dpp_summary
curl http://localhost:3002/api/health
curl http://localhost:1882/

# Check container health
docker inspect enms_demo_postgres | grep -A 5 Health
```

---

## 📁 Important Files

| File | Purpose |
|------|---------|
| `.env` | Environment configuration (credentials) |
| `docker-compose.yml` | Service definitions |
| `node-red/flows.json` | Node-RED automation flows |
| `grafana/dashboards/*.json` | Grafana dashboards |
| `backend/models/` | Trained ML models |
| `MIGRATION_PLAN.md` | Detailed migration guide |

---

## ⏱️ Timeline

| Phase | Duration | Description |
|-------|----------|-------------|
| **Pre-Migration** | 30 min | Run validation script on source |
| **Deployment** | 45-60 min | Run deployment script on target |
| **Testing** | 2-4 hours | Comprehensive functional testing |
| **Monitoring** | 24-48 hours | Parallel operation both servers |
| **Cutover** | 15 min | DNS update to new server |
| **Stability** | 7 days | Monitor with rollback capability |
| **Decommission** | 1 hour | Shutdown source server |

**Total: ~9 days with zero downtime**

---

## 🎯 Success Criteria

- [ ] All 6+ Docker containers running
- [ ] Database record counts match source
- [ ] API responding correctly (< 500ms)
- [ ] Grafana dashboards loading
- [ ] Data generator active
- [ ] ML predictions working
- [ ] PDF generation functional
- [ ] No errors in logs (last 100 lines)
- [ ] External access works
- [ ] Performance comparable to source

---

## 📚 Full Documentation

- **Complete Guide:** `/home/ubuntu/enms-demo/MIGRATION_PLAN.md`
- **Project README:** `/home/ubuntu/enms-demo/README.md`
- **API Documentation:** `/home/ubuntu/enms-demo/DPP_API_Documentation.md`
- **Technical Details:** `/home/ubuntu/enms-demo/ENMS_Technical_Details.md`

---

## 🚨 Emergency Contacts

**Before starting migration:**
1. Ensure you have access to both servers
2. Have backups ready
3. Know who to contact if issues arise
4. Document the maintenance window

---

## 📝 Migration Log Template

```markdown
# Migration Execution Log

**Date:** [FILL]
**Executed by:** [YOUR NAME]
**Start time:** [FILL]
**End time:** [FILL]

## Pre-Migration
- [ ] Validation script run on 109
- [ ] All checks passed
- [ ] Report reviewed

## Deployment
- [ ] Script started on 113
- [ ] All steps completed successfully
- [ ] Health checks passed

## Testing
- [ ] Web interface tested
- [ ] Grafana dashboards verified
- [ ] API endpoints tested
- [ ] Data generation confirmed
- [ ] Database counts verified

## Issues Encountered
[FILL or "None"]

## Resolution
[FILL if issues encountered]

## Status
✅ Success / ⚠️ Partial / ❌ Failed

## Notes
[Additional notes]
```

---

**Last Updated:** November 6, 2025  
**Document Version:** 1.0  
**Status:** Ready for use
