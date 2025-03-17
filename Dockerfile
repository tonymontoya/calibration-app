# Use an official lightweight Python image.
FROM python:3.9-slim

# Set environment variables to prevent Python from writing .pyc files and to buffer output.
ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1

# Set work directory
WORKDIR /app

# Install system dependencies. libpq-dev is needed for PostgreSQL integration.
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    libpq-dev \
  && rm -rf /var/lib/apt/lists/*

# Copy requirements.txt and install Python dependencies
COPY requirements.txt /app/
RUN pip install --upgrade pip && pip install -r requirements.txt

# Copy the entire project to the container
COPY . /app

# Expose port 8000 for the Flask application (used by Gunicorn)
EXPOSE 8000

# Run the Flask app using Gunicorn
CMD ["gunicorn", "--bind", "0.0.0.0:8000", "app:app"]
