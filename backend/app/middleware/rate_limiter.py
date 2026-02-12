"""Simple in-memory rate limiting middleware."""

import time
from collections import defaultdict
from starlette.middleware.base import BaseHTTPMiddleware
from starlette.requests import Request
from starlette.responses import JSONResponse
from app.config import settings


class RateLimitMiddleware(BaseHTTPMiddleware):
    def __init__(self, app):
        super().__init__(app)
        self.rate_limit_data: dict = defaultdict(list)
        self.authenticated_limit = settings.RATE_LIMIT_AUTHENTICATED
        self.unauthenticated_limit = settings.RATE_LIMIT_UNAUTHENTICATED

    async def dispatch(self, request: Request, call_next):
        # Skip rate limiting for health checks and docs
        if request.url.path in ("/health", "/docs", "/openapi.json", "/"):
            return await call_next(request)

        client_ip = request.client.host if request.client else "unknown"
        has_auth = "authorization" in request.headers
        limit = self.authenticated_limit if has_auth else self.unauthenticated_limit

        now = time.time()
        window_start = now - 60  # 1-minute window

        # Clean old entries
        self.rate_limit_data[client_ip] = [
            t for t in self.rate_limit_data[client_ip] if t > window_start
        ]

        if len(self.rate_limit_data[client_ip]) >= limit:
            return JSONResponse(
                status_code=429,
                content={
                    "error": "Rate limit exceeded",
                    "detail": f"Maximum {limit} requests per minute",
                    "retry_after": 60,
                },
            )

        self.rate_limit_data[client_ip].append(now)
        response = await call_next(request)
        response.headers["X-RateLimit-Limit"] = str(limit)
        response.headers["X-RateLimit-Remaining"] = str(
            limit - len(self.rate_limit_data[client_ip])
        )
        return response
