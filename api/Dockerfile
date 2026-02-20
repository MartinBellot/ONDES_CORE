# ============================================================
#  Ondes Backend — Production Dockerfile
#  Python 3.12-slim + FFmpeg (HLS processing) + Daphne (ASGI)
# ============================================================
FROM python:3.12-slim

# Prevent .pyc files and enable unbuffered logs
ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1

# System dependencies
#   ffmpeg        → HLS video conversion (social/media_processing.py)
#   libpq-dev     → psycopg2 native driver
#   build-essential / libffi-dev → C extensions
RUN apt-get update && apt-get install -y --no-install-recommends \
    ffmpeg \
    libpq-dev \
    build-essential \
    libffi-dev \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Install Python dependencies first (layer cache optimisation)
COPY requirements.txt .
RUN pip install --upgrade pip && pip install --no-cache-dir -r requirements.txt

# Copy application code
COPY . .

# Entrypoint (migrate + collectstatic + start daphne)
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

EXPOSE 8000

ENTRYPOINT ["/entrypoint.sh"]
