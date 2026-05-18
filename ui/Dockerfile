# 1. Use an official Python runtime as a parent image
FROM python:3.9-slim

# 2. Install System Dependencies (Java is required for Nextflow)
RUN apt-get update && apt-get install -y \
    openjdk-17-jre-slim \
    curl \
    wget \
    graphviz \
    && rm -rf /var/lib/apt/lists/*

# 3. Install Nextflow
RUN curl -s https://get.nextflow.io | bash && \
    mv nextflow /usr/local/bin/ && \
    chmod +x /usr/local/bin/nextflow

# 4. Set the working directory inside the container
WORKDIR /app

# 5. Copy requirements and install Python libraries
# You'll need: streamlit, pandas, boto3
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# 6. Copy your project files
COPY . .

# 7. Expose the port Streamlit runs on
EXPOSE 8501

# 8. Command to run the app
CMD ["streamlit", "run", "ui/app.py", "--server.port=8501", "--server.address=0.0.0.0"]