FROM python:3.12-slim

WORKDIR /app

# Install system dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    gcc \
    && rm -rf /var/lib/apt/lists/*

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY web/ web/
COPY sync/ sync/

ENV PORT=8080
EXPOSE 8080

CMD ["sh", "-c", "gunicorn --chdir web -w 4 -b 0.0.0.0:${PORT:-8080} server:app"]
