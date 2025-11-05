#!/usr/bin/env python3
"""
Fast backfill - Generate PDFs for remaining jobs concurrently
"""
import psycopg2
import requests
import concurrent.futures
import time

DB_CONFIG = {
    'host': 'localhost',
    'port': 5434,
    'database': 'reg_ml_demo',
    'user': 'reg_ml_demo',
    'password': 'raptorblingx_demo'
}

PDF_SERVICE_URL = 'http://localhost:8090/api/generate_dpp_pdf'

def generate_pdf(job_id):
    """Generate PDF for a single job"""
    try:
        response = requests.post(
            PDF_SERVICE_URL,
            json={'job_id': job_id},
            timeout=30
        )
        if response.status_code == 200:
            result = response.json()
            if result.get('success'):
                return (job_id, 'success', None)
            else:
                return (job_id, 'error', result.get('message', 'Unknown error'))
        else:
            return (job_id, 'error', f'HTTP {response.status_code}')
    except Exception as e:
        return (job_id, 'error', str(e))

def fast_backfill():
    """Generate all PDFs using parallel requests"""
    conn = psycopg2.connect(**DB_CONFIG)
    cur = conn.cursor()
    
    # Get all completed jobs without PDFs
    cur.execute("""
        SELECT job_id FROM print_jobs 
        WHERE status = 'completed' 
        ORDER BY job_id
    """)
    
    job_ids = [row[0] for row in cur.fetchall()]
    total_jobs = len(job_ids)
    conn.close()
    
    print(f"\n{'='*80}")
    print(f"FAST PDF BACKFILL - Generating {total_jobs} PDFs")
    print(f"{'='*80}\n")
    
    success_count = 0
    error_count = 0
    
    # Use ThreadPoolExecutor for concurrent requests
    with concurrent.futures.ThreadPoolExecutor(max_workers=8) as executor:
        futures = {executor.submit(generate_pdf, job_id): job_id for job_id in job_ids}
        
        for i, future in enumerate(concurrent.futures.as_completed(futures), 1):
            job_id, status, error = future.result()
            
            if status == 'success':
                success_count += 1
            else:
                error_count += 1
                if error_count <= 5:  # Show first 5 errors
                    print(f"❌ Job {job_id}: {error}")
            
            # Progress every 10 jobs
            if i % 10 == 0 or i == total_jobs:
                print(f"Progress: {i}/{total_jobs} ({100*i/total_jobs:.1f}%) | ✅ {success_count} | ❌ {error_count}")
    
    print(f"\n{'='*80}")
    print(f"BACKFILL COMPLETE")
    print(f"{'='*80}")
    print(f"✅ Success: {success_count}/{total_jobs}")
    print(f"❌ Errors:  {error_count}/{total_jobs}")
    print(f"{'='*80}\n")

if __name__ == '__main__':
    fast_backfill()
