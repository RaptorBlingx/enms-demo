#!/usr/bin/env python3
"""
Automated cleanup and PDF generation service
Runs periodically to:
1. Clean up old print jobs (keep only last 144)
2. Generate PDFs for new jobs that don't have them yet
"""
import psycopg2
import requests
import time
import os
import sys

DB_CONFIG = {
    'host': os.environ.get('POSTGRES_HOST', 'localhost'),
    'port': int(os.environ.get('POSTGRES_PORT', '5434')),
    'database': os.environ.get('POSTGRES_DB', 'reg_ml_demo'),
    'user': os.environ.get('POSTGRES_USER', 'reg_ml_demo'),
    'password': os.environ.get('POSTGRES_PASSWORD', 'raptorblingx_demo')
}

PDF_SERVICE_URL = 'http://localhost:8090/api/generate_dpp_pdf'
MAX_JOBS_TO_KEEP = 144
CHECK_INTERVAL = 300  # 5 minutes

def cleanup_old_jobs():
    """Delete old print jobs keeping only the most recent ones"""
    try:
        conn = psycopg2.connect(**DB_CONFIG)
        cur = conn.cursor()
        
        cur.execute("SELECT COUNT(*) FROM print_jobs WHERE status = 'completed'")
        total_jobs = cur.fetchone()[0]
        
        if total_jobs <= MAX_JOBS_TO_KEEP:
            return 0
        
        jobs_to_delete = total_jobs - MAX_JOBS_TO_KEEP
        
        delete_query = """
            DELETE FROM print_jobs
            WHERE job_id IN (
                SELECT job_id FROM print_jobs
                WHERE status = 'completed'
                ORDER BY end_time DESC
                OFFSET %s
            )
        """
        cur.execute(delete_query, (MAX_JOBS_TO_KEEP,))
        deleted_count = cur.rowcount
        conn.commit()
        conn.close()
        
        return deleted_count
    except Exception as e:
        print(f"❌ Cleanup error: {e}")
        return 0

def generate_missing_pdfs():
    """Generate PDFs for completed jobs that don't have them"""
    try:
        conn = psycopg2.connect(**DB_CONFIG)
        cur = conn.cursor()
        
        # Find jobs without PDFs in the last 144 jobs
        cur.execute("""
            WITH recent_jobs AS (
                SELECT job_id, dpp_pdf_url
                FROM print_jobs
                WHERE status = 'completed'
                ORDER BY end_time DESC
                LIMIT %s
            )
            SELECT job_id FROM recent_jobs
            WHERE dpp_pdf_url IS NULL
            ORDER BY job_id DESC
            LIMIT 20
        """, (MAX_JOBS_TO_KEEP,))
        
        jobs_needing_pdfs = [row[0] for row in cur.fetchall()]
        conn.close()
        
        if not jobs_needing_pdfs:
            return 0
        
        success_count = 0
        for job_id in jobs_needing_pdfs:
            try:
                response = requests.post(
                    PDF_SERVICE_URL,
                    json={'job_id': job_id},
                    timeout=30
                )
                if response.status_code == 200 and response.json().get('success'):
                    success_count += 1
                time.sleep(0.5)  # Small delay between requests
            except Exception as e:
                print(f"❌ PDF gen error for job {job_id}: {e}")
                continue
        
        return success_count
    except Exception as e:
        print(f"❌ PDF generation error: {e}")
        return 0

def run_maintenance_cycle():
    """Run one maintenance cycle"""
    print(f"\n[{time.strftime('%Y-%m-%d %H:%M:%S')}] Starting maintenance cycle...")
    
    # Cleanup old jobs
    deleted = cleanup_old_jobs()
    if deleted > 0:
        print(f"✅ Cleaned up {deleted} old print jobs")
    
    # Generate missing PDFs
    generated = generate_missing_pdfs()
    if generated > 0:
        print(f"✅ Generated {generated} new PDFs")
    
    if deleted == 0 and generated == 0:
        print(f"✓ No maintenance needed")

if __name__ == '__main__':
    print(f"{'='*80}")
    print(f"ENMS Demo - Automated Maintenance Service")
    print(f"{'='*80}")
    print(f"Retention policy: Keep last {MAX_JOBS_TO_KEEP} print jobs")
    print(f"Check interval: {CHECK_INTERVAL} seconds")
    print(f"{'='*80}\n")
    
    # Run continuously
    try:
        while True:
            run_maintenance_cycle()
            time.sleep(CHECK_INTERVAL)
    except KeyboardInterrupt:
        print("\n\n✓ Maintenance service stopped")
        sys.exit(0)
