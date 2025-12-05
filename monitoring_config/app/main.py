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
    Webhook endpoint for Grafana/Alertmanager alerts
    Receives alert data and sends email via Snowflake
    """
    try:
        payload = await request.json()
        
        # Xử lý payload từ Alertmanager
        if 'alerts' in payload:
            # Alertmanager format
            alerts = payload.get('alerts', [])
            common_labels = payload.get('commonLabels', {})
            common_annotations = payload.get('commonAnnotations', {})
            
            alert_name = common_labels.get('alertname', 'Unknown Alert')
            instance = common_labels.get('instance', 'Unknown')
            severity = common_labels.get('severity', 'warning')
            job = common_labels.get('job', 'Unknown')
            
            # Tách IP từ instance (format: ip:port)
            ip_address = instance.split(':')[0] if ':' in instance else instance
            
            summary = common_annotations.get('summary', 'No summary')
            description = common_annotations.get('description', 'No description')
            
            # Đếm số alert đang firing
            firing_count = len([a for a in alerts if a.get('status') == 'firing'])
            
            # Format email
            email_subject = f"[{severity.upper()}] {alert_name} - {ip_address}"
            
            email_body = f"""
Docker Monitoring Alert
========================

Summary:
{summary}

Description:
{description}

---
This is an automated alert from Docker Monitoring System.
Please review and address the issue.

Regard,
Data Team
"""
        
        # Send email via Snowflake
        success = send_snowflake_email(email_subject, email_body)
        
        if success:
            return {
                "status": "success",
                "message": "Alert email sent via Snowflake",
                "timestamp": datetime.now().isoformat()
            }
        else:
            return {
                "status": "error",
                "message": "Failed to send email via Snowflake",
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
