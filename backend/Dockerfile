FROM python:3.12-slim

WORKDIR /srv
COPY backend/requirements.txt /tmp/requirements.txt
RUN pip install --no-cache-dir -r /tmp/requirements.txt
COPY backend /srv/backend
COPY scenario /srv/scenario

ENV PYTHONPATH=/srv/backend \
    TIPO_MODE=mock \
    PORT=8080
WORKDIR /srv/backend
EXPOSE 8080
CMD ["sh", "-c", "uvicorn app.main:app --host 0.0.0.0 --port ${PORT}"]
