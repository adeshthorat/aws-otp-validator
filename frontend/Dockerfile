FROM python:3.11-slim

WORKDIR /app

# Create log directory
RUN mkdir -p /var/logs && chmod 777 /var/logs

# Copy frontend files
COPY index.html .
COPY style.css .
COPY script.js .
COPY proxy.py .

# Expose port
EXPOSE 8000

# Run the proxy server
CMD ["python", "proxy.py"]
