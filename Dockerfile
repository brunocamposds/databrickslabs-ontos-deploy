# ==============================================================================
# Stage 1: Build the React frontend
# ==============================================================================
FROM node:22-alpine AS frontend-builder
WORKDIR /app/frontend

# Install dependencies first (layer caching) with legacy peer deps to resolve AJV version conflicts
COPY src/frontend/package*.json ./
RUN npm ci --legacy-peer-deps --no-audit --no-fund

# Copy frontend source code and compile Vite production bundle
COPY src/frontend/ ./
RUN npm run build

# ==============================================================================
# Stage 2: Runtime image with Python 3.11
# ==============================================================================
FROM python:3.11-slim AS runtime
WORKDIR /app

# Install minimal OS dependencies needed for database and healthchecks
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    git \
    libpq5 \
    && rm -rf /var/lib/apt/lists/*

# Install locked Python requirements
COPY src/requirements.txt /app/requirements.txt
RUN pip install --no-cache-dir -r /app/requirements.txt

# Copy backend application codebase
COPY src/backend /app/backend
RUN chmod +x /app/backend/entrypoint.sh

# Copy compiled frontend SPA static assets directly into the backend static mount directory
COPY --from=frontend-builder /app/frontend/static /app/backend/static

# Configure environment variables
ENV PYTHONPATH="/app/backend"
ENV PYTHONUNBUFFERED=1
ENV FRONTEND_STATIC_DIR="/app/backend/static"

# Default runtime configuration for isolated lab mode
ENV ENV="LOCAL"
ENV DB_USE_PASSWORD_AUTH="true"
ENV MOCK_WORKSPACE_CLIENT="true"
ENV MOCK_USER_DETAILS="true"
ENV APP_AUDIT_LOG_DIR="audit_logs"

WORKDIR /app/backend

EXPOSE 8000

# Health check to ensure API and DB are healthy
HEALTHCHECK --interval=15s --timeout=5s --start-period=30s --retries=3 \
  CMD curl -f http://localhost:8000/api/health || exit 1

# Start the application using the entrypoint script
CMD ["/app/backend/entrypoint.sh"]
