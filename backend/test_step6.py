import httpx
import json

BASE_URL = "http://localhost:8000"

def test_auth_flow():
    with httpx.Client(base_url=BASE_URL, timeout=10.0) as client:
        print("--- 1. Registering Jane Doe ---")
        reg_data = {
            "full_name": "Jane Doe",
            "email": "jane@test.com",
            "password": "password123",
            "confirm_password": "password123"
        }
        res = client.post("/auth/register", json=reg_data)
        print(f"Status: {res.status_code}")
        print(f"Response: {res.text}\n")
        
        jane_token = None
        if res.status_code == 201:
            jane_token = res.json()["access_token"]

        print("--- 2. Login Jane Doe ---")
        login_data = {"email": "jane@test.com", "password": "password123"}
        res = client.post("/auth/login", json=login_data)
        print(f"Status: {res.status_code}")
        print(f"Response: {res.text}\n")
        if res.status_code == 200:
            jane_token = res.json()["access_token"]

        print("--- 3. GET /users/me (Authenticated) ---")
        if jane_token:
            res = client.get("/users/me", headers={"Authorization": f"Bearer {jane_token}"})
            print(f"Status: {res.status_code}")
            print(f"Response: {res.text}\n")
        else:
            print("Skipping GET /users/me (no token)\n")

        print("--- 4. Login with wrong password ---")
        login_data_wrong = {"email": "jane@test.com", "password": "wrongpassword"}
        res = client.post("/auth/login", json=login_data_wrong)
        print(f"Status: {res.status_code}")
        print(f"Response: {res.text}\n")

        print("--- 5. Register same email again ---")
        res = client.post("/auth/register", json=reg_data)
        print(f"Status: {res.status_code}")
        print(f"Response: {res.text}\n")

        print("--- 6. Login with blocked user ---")
        # First, mock-create a blocked user via direct DB access or SQL
        import pymysql
        conn = pymysql.connect(host='localhost', user='root', password='Emil2008_', database='marketplace_db')
        cur = conn.cursor()
        cur.execute("DELETE FROM users WHERE email='blocked@test.com'")
        from services.auth_service import hash_password
        pwd_hash = hash_password("password123")
        cur.execute("INSERT INTO users (full_name, email, password_hash, account_status, role) VALUES (%s, %s, %s, %s, %s)", 
                    ("Blocked User", "blocked@test.com", pwd_hash, "blocked", "user"))
        conn.commit()
        cur.close()
        conn.close()
        
        login_data_blocked = {"email": "blocked@test.com", "password": "password123"}
        res = client.post("/auth/login", json=login_data_blocked)
        print(f"Status: {res.status_code}")
        print(f"Response: {res.text}\n")

if __name__ == "__main__":
    test_auth_flow()
