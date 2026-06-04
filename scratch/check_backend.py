import urllib.request
import json
import time

url = "https://script.google.com/macros/s/AKfycbwoPY6b22vZA-nc_SUxC_ylM_7tLXqS405Ikr0PYmNLAIMNSSbx_zQ3ZFVu0VXFChfa/exec"

def make_request(action, payload_data):
    payload = {
        "action": action,
        "payload": payload_data
    }
    req = urllib.request.Request(
        url, 
        data=json.dumps(payload).encode('utf-8'),
        headers={'Content-Type': 'application/json', 'User-Agent': 'Mozilla/5.0'}
    )
    try:
        with urllib.request.urlopen(req) as response:
            return json.loads(response.read().decode('utf-8'))
    except Exception as e:
        return {"success": False, "error": str(e)}

# Generate a unique email
email = f"test_{int(time.time())}@example.com"
print(f"Testing signup with {email}...")
signup_res = make_request("signUp", {
    "email": email,
    "pin": "1234",
    "userName": "Python Tester"
})
print("Signup response:", signup_res)

if signup_res.get("success"):
    print("\nTesting login with same credentials...")
    login_res = make_request("login", {
        "email": email,
        "pin": "1234"
    })
    print("Login response:", login_res)
else:
    print("Signup failed, skipping login test.")
