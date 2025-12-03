from fastapi import FastAPI, HTTPException, Request
from fastapi.middleware.cors import CORSMiddleware
import uvicorn
from datetime import datetime
import os
from snowflake_service import send_snowflake_email
from models import *


app = FastAPI(
    title="Docker Monitoring Alert API",
    version="1.0.0"
)

# CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)



# Root endpoint
@app.get("/")
async def root():
    return {
        "message": "Docker Monitoring Alert API",
        "version": "1.0.0",
        "docs": "/docs",
        "endpoints": {
            "health": "/health",
            "grafana_webhook": "/webhook/grafana",
            "test_webhook": "/webhook/test"
        }
    }

@app.get("/health", response_model=HealthCheck)
async def health_check():
    """Health check endpoint"""
    return {
        "status": "healthy",
        "timestamp": datetime.now().isoformat(),
        "service": "fastapi-alert-server"
    }


# Webhook endpoints for Grafana alerts
@app.post("/webhook/grafana")
async def grafana_webhook(request: Request):
    """
    Webhook endpoint for Grafana alerts
    Receives alert data and sends email via Snowflake
    """
    try:
        payload = await request.json()
        
        # Extract alert information
        title = payload.get("title", "Grafana Alert")
        state = payload.get("state", "alerting")
        message = payload.get("message", "No message provided")
        rule_name = payload.get("ruleName", title)
        rule_url = payload.get("ruleUrl", "")
        
        # Only send email for alerting state (skip "ok" state to avoid spam)
        if state.lower() != "alerting":
            return {
                "status": "skipped",
                "message": f"Email not sent for state: {state}"
            }
        
        # Format email subject and body
        email_subject = f"[ALERT] Docker Monitoring: {rule_name}"
        
        email_body = f"""
Docker Monitoring Alert from Grafana
=====================================

Status: {state.upper()}
Alert: {rule_name}
Message: {message}

{"Dashboard: " + rule_url if rule_url else ""}

Timestamp: {datetime.now().isoformat()}

---
Full Alert Details:
{payload}

---
This is an automated message from Docker Monitoring System.
Please review and address the issue.

Regards,
Monitoring Team
        """
        
        # Send email via Snowflake
        success = send_snowflake_email(email_subject, email_body)
        
        if success:
            return {
                "status": "success",
                "message": "Alert email sent via Snowflake",
                "alert": rule_name,
                "state": state,
                "timestamp": datetime.now().isoformat()
            }
        else:
            return {
                "status": "error",
                "message": "Failed to send email via Snowflake",
                "alert": rule_name,
                "state": state,
                "timestamp": datetime.now().isoformat()
            }
            
    except Exception as e:
        print(f"ERROR: Grafana webhook error: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/webhook/test")
async def test_webhook():
    """Test endpoint to verify Snowflake email integration"""
    test_subject = "[TEST] Email from Docker Monitoring"
    test_body = f"""
This is a test email from the Docker Monitoring System.

If you receive this email, the Snowflake email integration is working correctly!

Timestamp: {datetime.now().isoformat()}

Configuration:
- Snowflake Account: {os.getenv("SNOWFLAKE_ACCOUNT", "Not set")}
- Snowflake User: {os.getenv("SNOWFLAKE_USER", "Not set")}
- Email Integration: {os.getenv("SNOWFLAKE_EMAIL_INTEGRATION", "my_email_int")}
- Target Email: {os.getenv("TARGET_EMAIL", "Not set")}
- Role: {os.getenv("SNOWFLAKE_ROLE", "Default role")}

---
This is an automated test message from Docker Monitoring System.
    """
    
    success = send_snowflake_email(test_subject, test_body)
    
    if success:
        return {
            "status": "success",
            "message": "Test email sent successfully via Snowflake",
            "timestamp": datetime.now().isoformat()
        }
    else:
        return {
            "status": "error",
            "message": "Failed to send test email. Check logs for details.",
            "timestamp": datetime.now().isoformat()
        }

if __name__ == "__main__":
    uvicorn.run("main:app", host="0.0.0.0", port=8000, reload=True)
