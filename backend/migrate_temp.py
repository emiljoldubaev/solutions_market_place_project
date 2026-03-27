import pymysql

try:
    conn = pymysql.connect(host='localhost', user='root', password='Emil2008_', database='marketplace_db')
    cur = conn.cursor()
    
    # Check if columns exist first
    cur.execute("SHOW COLUMNS FROM users LIKE 'password_reset_token'")
    if not cur.fetchone():
        cur.execute("ALTER TABLE users ADD COLUMN password_reset_token VARCHAR(255) NULL")
        print("Added password_reset_token")
        
    cur.execute("SHOW COLUMNS FROM users LIKE 'password_reset_expires'")
    if not cur.fetchone():
        cur.execute("ALTER TABLE users ADD COLUMN password_reset_expires DATETIME NULL")
        print("Added password_reset_expires")
        
    conn.commit()
    cur.close()
    conn.close()
    print("Database migration successful.")
except Exception as e:
    print(f"Error: {e}")
