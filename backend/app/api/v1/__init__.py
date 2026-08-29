from fastapi import APIRouter

from app.api.v1 import auth, health, victims

api_router_v1 = APIRouter()
api_router_v1.include_router(health.router)
api_router_v1.include_router(auth.router)
api_router_v1.include_router(victims.router)

__all__ = ["api_router_v1", "auth", "health", "victims"]
