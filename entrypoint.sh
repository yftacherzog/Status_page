#!/bin/bash

echo "Applying database migrations..."
python3 manage.py migrate --noinput

echo "Collecting static files..."
python3 manage.py collectstatic --noinput

echo "Starting Gunicorn..."
exec gunicorn --workers 3 --bind 0.0.0.0:8000 statuspage.wsgi:application

