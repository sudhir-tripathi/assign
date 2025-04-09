# Use slim version of Python for smaller image size
FROM python:3.10-slim

# Set the working directory in the container
WORKDIR /app

# Install Python dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy the rest of the app
COPY . .

# Expose the port Flask runs on
EXPOSE 5000

# Run the app using Gunicorn for production
CMD ["gunicorn", "--bind", "0.0.0.0:5000", "app:app"]
