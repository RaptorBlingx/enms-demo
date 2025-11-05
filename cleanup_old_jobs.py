#!/usr/bin/env python3
"""
Cleanup old print jobs from the database.
Keeps only the most recent 144 completed jobs (12 pages × 12 rows).
This prevents database bloat and improves DPP page performance.
"""
import psycopg2
import sys
import os

# Database configuration from environment or defaults
DB_CONFIG = {
    'host': os.environ.get('POSTGRES_HOST', 'localhost'),
    'port': int(os.environ.get('POSTGRES_PORT', '5434')),
    'database': os.environ.get('POSTGRES_DB', 'reg_ml_demo'),
    'user': os.environ.get('POSTGRES_USER', 'reg_ml_demo'),
    'password': os.environ.get('POSTGRES_PASSWORD', 'raptorblingx_demo')
}

# Retention policy: keep only last N completed jobs
MAX_JOBS_TO_KEEP = 144  # 12 pages × 12 rows per page

def cleanup_old_jobs(dry_run=False):
    """
    Delete old completed print jobs, keeping only the most recent ones.
    
    Args:
        dry_run: If True, only show what would be deleted without actually deleting
    """
    conn = None
    try:
        conn = psycopg2.connect(**DB_CONFIG)
        cur = conn.cursor()
        
        # Count total completed jobs
        cur.execute("SELECT COUNT(*) FROM print_jobs WHERE status = 'completed'")
        total_jobs = cur.fetchone()[0]
        
        print(f"\n{'='*80}")
        print(f"PRINT JOBS CLEANUP - Retention Policy")
        print(f"{'='*80}\n")
        print(f"Total completed jobs: {total_jobs}")
        print(f"Retention limit: {MAX_JOBS_TO_KEEP} jobs")
        
        if total_jobs <= MAX_JOBS_TO_KEEP:
            print(f"\n✓ No cleanup needed. Current count ({total_jobs}) is within limit.")
            print(f"{'='*80}\n")
            return
        
        jobs_to_delete = total_jobs - MAX_JOBS_TO_KEEP
        print(f"Jobs to delete: {jobs_to_delete}")
        
        if dry_run:
            print(f"\n⚠️  DRY RUN MODE - No actual deletion will occur\n")
            
            # Show which jobs would be deleted
            cur.execute("""
                SELECT job_id, device_id, filename, end_time, 
                       COALESCE(kwh_consumed, 0) as kwh,
                       dpp_pdf_url
                FROM print_jobs
                WHERE status = 'completed'
                ORDER BY end_time DESC
                OFFSET %s
                LIMIT 10
            """, (MAX_JOBS_TO_KEEP,))
            
            sample_jobs = cur.fetchall()
            if sample_jobs:
                print(f"Sample of jobs that would be deleted (oldest 10):")
                print(f"{'Job ID':<10} {'Device':<20} {'Filename':<25} {'kWh':<8} {'End Time':<20}")
                print(f"{'-'*90}")
                for job in sample_jobs:
                    job_id, device_id, filename, end_time, kwh, pdf_url = job
                    filename = (filename[:22] + '...') if filename and len(filename) > 25 else (filename or 'N/A')
                    print(f"{job_id:<10} {device_id:<20} {filename:<25} {kwh:<8.3f} {str(end_time)[:19]}")
        else:
            print(f"\n⚠️  DELETING {jobs_to_delete} old jobs...\n")
            
            # Delete old jobs - using a subquery to identify which jobs to delete
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
            
            print(f"✅ Successfully deleted {deleted_count} old print jobs")
            
            # Show current stats
            cur.execute("SELECT COUNT(*) FROM print_jobs WHERE status = 'completed'")
            remaining_jobs = cur.fetchone()[0]
            print(f"✅ Remaining completed jobs: {remaining_jobs}")
            
            # Show oldest remaining job
            cur.execute("""
                SELECT job_id, device_id, end_time 
                FROM print_jobs 
                WHERE status = 'completed' 
                ORDER BY end_time ASC 
                LIMIT 1
            """)
            oldest = cur.fetchone()
            if oldest:
                print(f"✅ Oldest remaining job: #{oldest[0]} from {oldest[2]}")
        
        print(f"\n{'='*80}\n")
        
    except Exception as e:
        print(f"\n❌ ERROR: {str(e)}")
        import traceback
        traceback.print_exc()
        sys.exit(1)
    finally:
        if conn:
            conn.close()

if __name__ == '__main__':
    # Check for dry-run flag
    dry_run = '--dry-run' in sys.argv or '-n' in sys.argv
    
    if dry_run:
        print("Running in DRY RUN mode...")
    else:
        print("⚠️  WARNING: This will DELETE old print jobs from the database!")
        print(f"   Only the most recent {MAX_JOBS_TO_KEEP} jobs will be kept.")
        print("   Press Ctrl+C to cancel within 3 seconds...")
        import time
        time.sleep(3)
    
    cleanup_old_jobs(dry_run=dry_run)
