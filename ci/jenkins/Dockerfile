FROM jenkins/jenkins:lts-jdk17

USER root

# Install system dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    gnupg \
    python3 \
    python3-pip \
    python3-venv \
    unzip \
    jq \
    git \
 && rm -rf /var/lib/apt/lists/*

# Install Docker CLI
RUN install -m 0755 -d /etc/apt/keyrings && \
    curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg && \
    chmod a+r /etc/apt/keyrings/docker.gpg && \
    echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian bookworm stable" > /etc/apt/sources.list.d/docker.list && \
    apt-get update && apt-get install -y --no-install-recommends docker-ce-cli && \
    rm -rf /var/lib/apt/lists/*

# Install AWS CLI v2
RUN curl -fsSL "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip" && \
    unzip -q awscliv2.zip && \
    ./aws/install && \
    rm -rf aws awscliv2.zip

# Install Terraform 1.17.0
RUN curl -fsSL "https://releases.hashicorp.com/terraform/1.17.0/terraform_1.17.0_linux_amd64.zip" -o terraform.zip && \
    unzip -q terraform.zip -d /usr/local/bin && \
    chmod +x /usr/local/bin/terraform && \
    rm terraform.zip

# Create python venv for pytest and install dependencies
RUN python3 -m venv /opt/venv && \
    /opt/venv/bin/pip install --no-cache-dir pytest httpx pydantic fastapi uvicorn && \
    ln -s /opt/venv/bin/pytest /usr/local/bin/pytest

# Set up init script for Jenkins pipeline job
RUN mkdir -p /usr/share/jenkins/ref/init.groovy.d
COPY 01-create-job.groovy /usr/share/jenkins/ref/init.groovy.d/01-create-job.groovy

# Install pinned plugins
COPY plugins.txt /usr/share/jenkins/ref/plugins.txt
RUN jenkins-plugin-cli --plugin-file /usr/share/jenkins/ref/plugins.txt

USER root
