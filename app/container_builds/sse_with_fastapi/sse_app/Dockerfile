# Use the official Python base image
# FROM python:3.9-alpine
# FROM python:3.11.9-bullseye
FROM python:3.10-alpine
LABEL Automation_By="Mystique"

# Don't buffer output:
# https://stackoverflow.com/questions/59812009/what-is-the-use-of-pythonunbuffered-in-docker-file
# https://docs.python.org/3.10/using/cmdline.html?highlight=pythonunbuffered#envvar-PYTHONUNBUFFERED
ENV PYTHONUNBUFFERED=1

# Set the working directory inside the container
WORKDIR /app

# Copy the requirements file
COPY requirements.txt /app

# Install the dependencies
RUN pip install --no-cache-dir -r requirements.txt

# Copy the content
COPY . /app

# Expose the port
EXPOSE 80
EXPOSE 8000

# Run the command to start uWSGI
# CMD ["gunicorn", "--bind", "0.0.0.0:80", "--workers", "8", "--timeout", "600", "--access-logfile", "-", "--error-logfile", "-", "app:app"]
CMD ["python", "main.py"]