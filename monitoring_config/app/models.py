from pydantic import BaseModel
from typing import Optional, Dict, Any, List


class HealthCheck(BaseModel):
    status: str
    timestamp: str
    service: str

class GrafanaWebhookPayload(BaseModel):
    """Model for Grafana webhook alert payload"""
    title: Optional[str] = "Grafana Alert"
    state: Optional[str] = "alerting"
    message: Optional[str] = "No message"
    evalMatches: Optional[List[Dict[str, Any]]] = None
    ruleUrl: Optional[str] = None
    ruleName: Optional[str] = None
    orgId: Optional[int] = None