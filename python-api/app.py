# home/ubuntu/enms-project/python-api/app.py

import os
import traceback
import psycopg2
from flask import Flask, jsonify, request
from flask_cors import CORS
from psycopg2.extras import RealDictCursor
import csv
from io import StringIO

# These imports might not exist, but let's keep them from your original file
# If they are the cause of the error, the app won't even start.
try:
    from dpp_simulator import get_live_dpp_data
    from pdf_service import generate_pdf_for_job
    print("--- DEBUG: Successfully imported dpp_simulator and pdf_service. ---")
except ImportError:
    print("--- DEBUG: Could not import dpp_simulator or pdf_service. Ignoring for now. ---")
    get_live_dpp_data = lambda: {"error": "DPP simulator not available"}
    generate_pdf_for_job = lambda job_id: {"error": "PDF service not available"}

# Import authentication services
try:
    from auth_service import (
        register_user, login_user, verify_email_token, logout_user,
        check_session, require_auth, require_admin
    )
    print("--- DEBUG: Successfully imported auth_service. ---")
except ImportError as e:
    print(f"--- DEBUG: Could not import auth_service: {e} ---")
    # Provide dummy functions for testing
    require_auth = lambda f: f
    require_admin = lambda f: f


app = Flask(__name__)
# Initialize CORS to allow cross-origin requests from the frontend
CORS(app)


# --- Existing DPP Endpoints (with syntax corrections) ---

@app.route('/api/dpp_summary', methods=['GET'])
def dpp_summary():
    """
    Provides a real-time summary of all printers for the DPP frontend.
    Supports pagination and search via query parameters.
    """
    try:
        # Get pagination and search parameters from query string
        page = request.args.get('page', default=1, type=int)
        limit = request.args.get('limit', default=12, type=int)
        search_term = request.args.get('searchTerm', default=None, type=str)
        
        data = get_live_dpp_data(page=page, limit=limit, searchTerm=search_term)
        if "error" in data:
            return jsonify(data), 500
        return jsonify(data)
    except Exception as e:
        traceback.print_exc()
        return jsonify({"error": str(e)}), 500


@app.route('/api/generate_dpp_pdf', methods=['POST'])
def generate_dpp_pdf_endpoint():
    """
    Web endpoint to trigger PDF generation for a specific job.
    """
    data = request.get_json()
    job_id = data.get('job_id')
    if not job_id:
        return jsonify({"error": "job_id is required"}), 400
    try:
        # Call the real function from our other file
        result = generate_pdf_for_job(job_id)
        if "error" in result:
             return jsonify(result), 500
        return jsonify(result), 200
    except Exception as e:
        traceback.print_exc()
        return jsonify({"error": str(e)}), 500

# --- NEW: Database Connection Function (Docker-aware) with DEBUG LOGGING ---
def get_db_connection():
    """Establishes a connection to the PostgreSQL database using environment variables."""
    print("--- DEBUG: Attempting to connect to database... ---")
    print(f"--- DEBUG: Host: {os.environ.get('POSTGRES_HOST')}, Port: {os.environ.get('POSTGRES_PORT')}, DB: {os.environ.get('POSTGRES_DB')}, User: {os.environ.get('POSTGRES_USER')}")
    try:
        conn = psycopg2.connect(
            dbname=os.environ.get('POSTGRES_DB'),
            user=os.environ.get('POSTGRES_USER'),
            password=os.environ.get('POSTGRES_PASSWORD'),
            host=os.environ.get('POSTGRES_HOST'), # This will be 'postgres' from docker-compose
            port=os.environ.get('POSTGRES_PORT')
        )
        print("--- DEBUG: Database connection SUCCESSFUL. ---")
        return conn
    except Exception as e:
        # This will now catch ANY exception during connection, not just OperationalError
        print("--- DEBUG: DATABASE CONNECTION FAILED! ---")
        traceback.print_exc() # Print the full exception traceback to the logs
        return None

# --- NEW: DEVICE MANAGEMENT API ENDPOINTS ---

# GET /api/devices/ (Fetch all devices for the main table) - WITH DEBUG LOGGING
@app.route('/api/devices/', methods=['GET'])
def get_devices():
    print("\n--- DEBUG: ENTERED get_devices() endpoint. ---")
    conn = get_db_connection()

    if not conn:
        print("--- DEBUG: get_db_connection() returned None. Exiting with 500. ---")
        return jsonify({"error": "Database connection failed as reported by get_db_connection"}), 500

    try:
        print("--- DEBUG: Connection object exists, proceeding to create cursor. ---")
        with conn.cursor() as cur:
            print("--- DEBUG: Cursor created. Executing SQL query... ---")
            cur.execute("""
                SELECT device_id, device_model, friendly_name, location, notes,
                       shelly_id, api_ip, simplyprint_id, sp_company_id,
                       printer_size_category, bed_width, bed_depth
                FROM public.devices ORDER BY friendly_name ASC
            """)
            print("--- DEBUG: SQL query executed successfully. Fetching results... ---")
            columns = [desc[0] for desc in cur.description]
            devices = [dict(zip(columns, row)) for row in cur.fetchall()]
            print("--- DEBUG: Results fetched and processed. Returning data. ---")
        return jsonify(devices)
    except Exception as e:
        print("--- DEBUG: An exception occurred INSIDE THE 'try' block of get_devices(). ---")
        traceback.print_exc()
        return jsonify({"error": str(e)}), 500
    finally:
        if conn:
            print("--- DEBUG: Closing database connection in get_devices(). ---")
            conn.close()

# GET /api/devices/<device_id> (Fetch a single device for the edit form)
@app.route('/api/devices/<string:device_id>', methods=['GET'])
def get_device(device_id):
    conn = get_db_connection()
    if not conn:
        return jsonify({"error": "Database connection failed"}), 500

    try:
        with conn.cursor() as cur:
            cur.execute("SELECT * FROM public.devices WHERE device_id = %s", (device_id,))
            columns = [desc[0] for desc in cur.description]
            device_data = cur.fetchone()
            if device_data is None:
                return jsonify({"error": "Device not found"}), 404
            device = dict(zip(columns, device_data))
        return jsonify(device)
    except Exception as e:
        traceback.print_exc()
        return jsonify({"error": str(e)}), 500
    finally:
        if conn:
            conn.close()

# POST /api/devices/ (Create a new device)
@app.route('/api/devices/', methods=['POST'])
def add_device():
    new_device = request.get_json()
    if not new_device or not new_device.get('device_id') or not new_device.get('device_model'):
        return jsonify({"error": "device_id and device_model are required"}), 400

    conn = get_db_connection()
    if not conn:
        return jsonify({"error": "Database connection failed"}), 500

    columns = [key for key in new_device.keys() if new_device[key] not in [None, '']]
    values = [new_device[key] for key in columns]

    if not columns:
        return jsonify({"error": "No data provided to insert"}), 400

    sql = f"INSERT INTO public.devices ({', '.join(columns)}) VALUES ({', '.join(['%s'] * len(values))}) RETURNING device_id;"

    try:
        with conn.cursor() as cur:
            cur.execute(sql, values)
            device_id = cur.fetchone()[0]
            conn.commit()
        return jsonify({"status": "success", "device_id": device_id}), 201
    except Exception as e:
        conn.rollback()
        traceback.print_exc()
        return jsonify({"error": str(e)}), 500
    finally:
        if conn:
            conn.close()

# PUT /api/devices/<device_id> (Update an existing device)
@app.route('/api/devices/<string:device_id>', methods=['PUT'])
def update_device(device_id):
    updates = request.get_json()
    if not updates:
        return jsonify({"error": "No update data provided"}), 400

    conn = get_db_connection()
    if not conn:
        return jsonify({"error": "Database connection failed"}), 500

    set_clause = ", ".join([f"{key} = %s" for key in updates.keys()])
    values = list(updates.values())
    values.append(device_id)

    sql = f"UPDATE public.devices SET {set_clause} WHERE device_id = %s;"

    try:
        with conn.cursor() as cur:
            cur.execute(sql, values)
            conn.commit()
        return jsonify({"status": "success", "updated_id": device_id})
    except Exception as e:
        conn.rollback()
        traceback.print_exc()
        return jsonify({"error": str(e)}), 500
    finally:
        if conn:
            conn.close()

# DELETE /api/devices/<device_id> (Delete a device)
@app.route('/api/devices/<string:device_id>', methods=['DELETE'])
def delete_device(device_id):
    conn = get_db_connection()
    if not conn:
        return jsonify({"error": "Database connection failed"}), 500

    sql = "DELETE FROM public.devices WHERE device_id = %s;"
    try:
        with conn.cursor() as cur:
            cur.execute(sql, (device_id,))
            conn.commit()
        return jsonify({"status": "success", "deleted_id": device_id})
    except Exception as e:
        conn.rollback()
        traceback.print_exc()
        return jsonify({"error": str(e)}), 500
    finally:
        if conn:
            conn.close()


# ====================================================================
# AUTHENTICATION ENDPOINTS
# ====================================================================

@app.route('/api/auth/register', methods=['POST'])
def auth_register():
    """User registration endpoint"""
    try:
        data = request.get_json()
        
        # Validate required fields
        required_fields = ['email', 'password', 'organization', 'full_name', 'position', 'country']
        missing_fields = [field for field in required_fields if not data.get(field)]
        
        if missing_fields:
            return jsonify({
                'success': False,
                'error': f'Missing required fields: {", ".join(missing_fields)}'
            }), 400
        
        # Get IP address and user agent
        # X-Forwarded-For can be a long chain from Cloudflare, get first IP only
        forwarded_for = request.headers.get('X-Forwarded-For', request.remote_addr)
        ip_address = forwarded_for.split(',')[0].strip() if forwarded_for else request.remote_addr
        # Truncate to 45 chars to fit in VARCHAR(50) field
        ip_address = ip_address[:45] if ip_address else 'unknown'
        
        user_agent = request.headers.get('User-Agent', '')[:500]  # Truncate user agent too
        
        # Register user
        result = register_user(
            email=data['email'],
            password=data['password'],
            organization=data['organization'],
            full_name=data['full_name'],
            position=data['position'],
            mobile=data.get('mobile', ''),
            country=data['country'],
            ip_address=ip_address,
            user_agent=user_agent
        )
        
        if result['success']:
            return jsonify(result), 201
        else:
            return jsonify(result), 400
            
    except Exception as e:
        traceback.print_exc()
        # Provide user-friendly error messages
        error_msg = str(e)
        if 'email_lowercase' in error_msg:
            error_msg = 'Email address must be lowercase'
        elif 'unique constraint' in error_msg.lower() or 'duplicate key' in error_msg.lower():
            error_msg = 'This email is already registered'
        elif 'check constraint' in error_msg.lower():
            error_msg = 'Invalid data format. Please check your inputs.'
        else:
            error_msg = 'Registration failed. Please try again.'
        
        return jsonify({'success': False, 'error': error_msg}), 500


@app.route('/api/auth/login', methods=['POST'])
def auth_login():
    """User login endpoint"""
    try:
        data = request.get_json()
        print(f"[AUTH] Login attempt - Email: {data.get('email') if data else 'NO DATA'}")
        
        if not data.get('email') or not data.get('password'):
            print(f"[AUTH] Login failed - Missing credentials")
            return jsonify({
                'success': False,
                'error': 'Email and password are required'
            }), 400
        
        # Get IP address and user agent
        # X-Forwarded-For can be a long chain from Cloudflare, get first IP only
        forwarded_for = request.headers.get('X-Forwarded-For', request.remote_addr)
        ip_address = forwarded_for.split(',')[0].strip() if forwarded_for else request.remote_addr
        # Truncate to 45 chars to fit in VARCHAR(50) field
        ip_address = ip_address[:45] if ip_address else 'unknown'
        
        user_agent = request.headers.get('User-Agent', '')[:500]  # Truncate user agent too
        
        # Login user
        result = login_user(
            email=data['email'],
            password=data['password'],
            ip_address=ip_address,
            user_agent=user_agent
        )
        
        if result['success']:
            return jsonify(result), 200
        else:
            return jsonify(result), 401
            
    except Exception as e:
        traceback.print_exc()
        return jsonify({'success': False, 'error': str(e)}), 500


@app.route('/api/auth/verify-email', methods=['POST'])
def auth_verify_email():
    """Email verification endpoint"""
    try:
        data = request.get_json()
        
        if not data.get('token'):
            return jsonify({
                'success': False,
                'error': 'Verification token is required'
            }), 400
        
        # Verify email
        result = verify_email_token(data['token'])
        
        if result['success']:
            return jsonify(result), 200
        else:
            return jsonify(result), 400
            
    except Exception as e:
        traceback.print_exc()
        return jsonify({'success': False, 'error': str(e)}), 500


@app.route('/api/auth/forgot-password', methods=['POST'])
def auth_forgot_password():
    """Request password reset endpoint"""
    try:
        data = request.get_json()
        
        if not data.get('email'):
            return jsonify({
                'success': False,
                'error': 'Email is required'
            }), 400
        
        # Get IP address
        ip_address = request.headers.get('X-Forwarded-For', request.remote_addr)
        
        # Request password reset
        from auth_service import request_password_reset
        result = request_password_reset(data['email'], ip_address)
        
        # Always return success to prevent email enumeration
        return jsonify(result), 200
            
    except Exception as e:
        traceback.print_exc()
        return jsonify({'success': False, 'error': str(e)}), 500


@app.route('/api/auth/reset-password', methods=['POST'])
def auth_reset_password():
    """Reset password with token endpoint"""
    try:
        data = request.get_json()
        
        if not data.get('token'):
            return jsonify({
                'success': False,
                'error': 'Reset token is required'
            }), 400
        
        if not data.get('password'):
            return jsonify({
                'success': False,
                'error': 'New password is required'
            }), 400
        
        # Get IP address
        ip_address = request.headers.get('X-Forwarded-For', request.remote_addr)
        
        # Reset password
        from auth_service import reset_password_with_token
        result = reset_password_with_token(data['token'], data['password'], ip_address)
        
        if result['success']:
            return jsonify(result), 200
        else:
            return jsonify(result), 400
            
    except Exception as e:
        traceback.print_exc()
        return jsonify({'success': False, 'error': str(e)}), 500


@app.route('/api/auth/logout', methods=['POST'])
@require_auth
def auth_logout():
    """User logout endpoint"""
    try:
        # Get token from header
        auth_header = request.headers.get('Authorization', '')
        token = auth_header.split(' ')[1] if auth_header.startswith('Bearer ') else None
        
        if not token:
            return jsonify({'success': False, 'error': 'No token provided'}), 400
        
        # Get IP address
        ip_address = request.headers.get('X-Forwarded-For', request.remote_addr)
        
        # Logout user
        result = logout_user(token, ip_address)
        
        if result['success']:
            return jsonify(result), 200
        else:
            return jsonify(result), 400
            
    except Exception as e:
        traceback.print_exc()
        return jsonify({'success': False, 'error': str(e)}), 500


@app.route('/api/auth/check-session', methods=['GET'])
def auth_check_session():
    """Check if current session is valid"""
    try:
        # Get token from header
        auth_header = request.headers.get('Authorization', '')
        
        if not auth_header.startswith('Bearer '):
            return jsonify({'valid': False, 'error': 'No authorization token provided'}), 401
        
        token = auth_header.split(' ')[1]
        
        # Check session
        result = check_session(token)
        
        if result['valid']:
            return jsonify(result), 200
        else:
            return jsonify(result), 401
            
    except Exception as e:
        traceback.print_exc()
        return jsonify({'valid': False, 'error': str(e)}), 500


# ====================================================================
# ADMIN ENDPOINTS
# ====================================================================

@app.route('/api/admin/users', methods=['GET'])
@require_admin
def admin_get_users():
    """Get all users (admin only)"""
    try:
        conn = get_db_connection()
        if not conn:
            return jsonify({'error': 'Database connection failed'}), 500
        
        # Get query parameters
        page = request.args.get('page', 1, type=int)
        limit = request.args.get('limit', 50, type=int)
        search = request.args.get('search', '', type=str)
        
        offset = (page - 1) * limit
        
        cursor = conn.cursor(cursor_factory=RealDictCursor)
        
        # Build search query
        where_clause = ""
        params = []
        if search:
            where_clause = """
                WHERE email ILIKE %s 
                OR full_name ILIKE %s 
                OR organization ILIKE %s
                OR country ILIKE %s
            """
            search_param = f'%{search}%'
            params = [search_param, search_param, search_param, search_param]
        
        # Get total count
        count_query = f"SELECT COUNT(*) as total FROM demo_users {where_clause}"
        cursor.execute(count_query, params)
        total = cursor.fetchone()['total']
        
        # Get users
        query = f"""
            SELECT 
                id, email, organization, full_name, position, mobile, country,
                email_verified, role, created_at, last_login, is_active,
                ip_address_signup
            FROM demo_users
            {where_clause}
            ORDER BY created_at DESC
            LIMIT %s OFFSET %s
        """
        cursor.execute(query, params + [limit, offset])
        users = cursor.fetchall()
        
        cursor.close()
        conn.close()
        
        return jsonify({
            'success': True,
            'users': users,
            'pagination': {
                'page': page,
                'limit': limit,
                'total': total,
                'pages': (total + limit - 1) // limit
            }
        }), 200
        
    except Exception as e:
        traceback.print_exc()
        return jsonify({'success': False, 'error': str(e)}), 500


@app.route('/api/admin/stats', methods=['GET'])
@require_admin
def admin_get_stats():
    """Get user statistics (admin only)"""
    try:
        conn = get_db_connection()
        if not conn:
            return jsonify({'error': 'Database connection failed'}), 500
        
        cursor = conn.cursor(cursor_factory=RealDictCursor)
        
        # Get overall stats
        cursor.execute("SELECT * FROM v_demo_user_stats")
        stats = cursor.fetchone()
        
        # Get country distribution
        cursor.execute("""
            SELECT country, COUNT(*) as count
            FROM demo_users
            WHERE is_active = TRUE
            GROUP BY country
            ORDER BY count DESC
            LIMIT 10
        """)
        countries = cursor.fetchall()
        
        # Get organization distribution
        cursor.execute("""
            SELECT organization, COUNT(*) as count
            FROM demo_users
            WHERE is_active = TRUE
            GROUP BY organization
            ORDER BY count DESC
            LIMIT 10
        """)
        organizations = cursor.fetchall()
        
        # Get recent activity
        cursor.execute("""
            SELECT action, COUNT(*) as count, MAX(created_at) as last_occurrence
            FROM demo_audit_log
            WHERE created_at >= NOW() - INTERVAL '24 hours'
            GROUP BY action
            ORDER BY count DESC
        """)
        recent_activity = cursor.fetchall()
        
        cursor.close()
        conn.close()
        
        return jsonify({
            'success': True,
            'stats': stats,
            'countries': countries,
            'organizations': organizations,
            'recent_activity': recent_activity
        }), 200
        
    except Exception as e:
        traceback.print_exc()
        return jsonify({'success': False, 'error': str(e)}), 500


@app.route('/api/admin/export-users', methods=['GET'])
@require_admin
def admin_export_users():
    """Export all users to CSV (admin only)"""
    try:
        conn = get_db_connection()
        if not conn:
            return jsonify({'error': 'Database connection failed'}), 500
        
        cursor = conn.cursor(cursor_factory=RealDictCursor)
        
        # Get all users
        cursor.execute("""
            SELECT 
                id, email, organization, full_name, position, mobile, country,
                email_verified, role, created_at, last_login, is_active,
                ip_address_signup
            FROM demo_users
            ORDER BY created_at DESC
        """)
        users = cursor.fetchall()
        
        cursor.close()
        conn.close()
        
        # Create CSV
        output = StringIO()
        if users:
            writer = csv.DictWriter(output, fieldnames=users[0].keys())
            writer.writeheader()
            writer.writerows(users)
        
        csv_content = output.getvalue()
        output.close()
        
        # Return CSV
        from flask import Response
        return Response(
            csv_content,
            mimetype='text/csv',
            headers={'Content-Disposition': 'attachment; filename=enms_demo_users.csv'}
        )
        
    except Exception as e:
        traceback.print_exc()
        return jsonify({'success': False, 'error': str(e)}), 500


# --- Main execution block ---
if __name__ == '__main__':
    # For production, debug should be False. Gunicorn or another WSGI server will be used.
    print("--- DEBUG: Starting Flask development server. ---")
    app.run(host='0.0.0.0', port=5000, debug=False)
