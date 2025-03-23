# Copy base configuration file
RUN cp statuspage/statuspage/configuration_example.py statuspage/statuspage/configuration.py

# Update ALLOWED_HOSTS to allow all hosts
RUN sed -i "s/ALLOWED_HOSTS = .*/ALLOWED_HOSTS = ['*']/" statuspage/statuspage/configuration.py

# Generate SECRET_KEY (this line is correctly placed!)
RUN . venv/bin/activate && python3 statuspage/generate_secret_key.py

# Change REDIS host from 'localhost' to 'redis'
RUN sed -i "/REDIS/,/}/s/'localhost'/'redis'/" statuspage/statuspage/configuration.py

# Update DB host from 'localhost' to 'db'
RUN sed -i "/DATABASES/,/}/s/'HOST': 'localhost'/'HOST': 'db'/" statuspage/statuspage/configuration.py

# Run setup script (optional - commented out)
#RUN chmod +x upgrade.sh && ./upgrade.sh

# Open the application port
EXPOSE 8000

# Activate virtual environment
SHELL ["/bin/bash", "-c"]
RUN source /opt/status-page/venv/bin/activate && \

# Run database migrations
python3 statuspage/manage.py migrate --noinput

CMD ["bash", "-c", "./upgrade.sh && python3 statuspage/manage.py runserver 0.0.0.0:8000 --insecure"]
