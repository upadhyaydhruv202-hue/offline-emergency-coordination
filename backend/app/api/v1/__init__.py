from fastapi import APIRouter

from app.api.v1 import auth, hazards, health, incidents, responders, sos, tasks, victims

api_router_v1 = APIRouter()
api_router_v1.include_router(health.router)
api_router_v1.include_router(auth.router)
api_router_v1.include_router(victims.router)
api_router_v1.include_router(incidents.router)
api_router_v1.include_router(hazards.router)
api_router_v1.include_router(sos.router)
api_router_v1.include_router(tasks.router)
api_router_v1.include_router(responders.router)

__all__ = [
    "api_router_v1",
    "auth",
    "hazards",
    "health",
    "incidents",
    "responders",
    "sos",
    "tasks",
    "victims",
]
