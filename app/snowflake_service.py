from typing import Optional
import snowflake.connector
import os


def send_snowflake_email(subject: str, body: str, recipients: Optional[str] = None) -> bool:
    """
    Send email via Snowflake 
    """
    
    account = os.getenv("SNOWFLAKE_ACCOUNT")
    user = os.getenv("SNOWFLAKE_USER")
    password = os.getenv("SNOWFLAKE_PASSWORD")
    
    if not all([account, user, password]):
        return False
    
    # Get recipient
    recipient_email = recipients or os.getenv("TARGET_EMAIL")
    if not recipient_email:
        return False
    
    # Get integration name 
    email_integration = os.getenv("SNOWFLAKE_EMAIL_INTEGRATION", "docker_monitoring_email_int")
    role = os.getenv("SNOWFLAKE_ROLE")
    
    # Connect to Snowflake
    print(f"INFO: Connecting to Snowflake: {account}")
    conn_params = {
        "account": account,
        "user": user,
        "password": password
    }
    if role:
        conn_params["role"] = role
    
    conn = snowflake.connector.connect(**conn_params)
    cursor = conn.cursor()
    
    # Escape SQL
    safe_subject = subject.replace("'", "''")
    safe_body = body.replace("'", "''")
    
    # Send email
    query = f"""
    CALL SYSTEM$SEND_EMAIL(
        '{email_integration}',
        '{recipient_email}',
        '{safe_subject}',
        '{safe_body}'
    );
    """
    
    cursor.execute(query)
    cursor.close()
    conn.close()
    
    return True