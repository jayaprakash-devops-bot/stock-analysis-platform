#!/bin/bash

# System Setup Script for Stock Analysis Platform
# This script will install and configure all required dependencies

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    log_error "Please run as root"
    exit 1
fi

# Update system
log_info "Updating system packages..."
apt-get update
apt-get upgrade -y

# Install necessary dependencies
log_info "Installing system dependencies..."
apt-get install -y \
    apt-transport-https \
    ca-certificates \
    curl \
    software-properties-common \
    gnupg \
    lsb-release \
    git \
    build-essential \
    libssl-dev \
    libffi-dev \
    python3-dev \
    python3-pip \
    python3-venv \
    sendmail \
    sendmail-bin \
    mailutils

# Install Docker
log_info "Installing Docker..."
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null

apt-get update
apt-get install -y docker-ce docker-ce-cli containerd.io

# Start and enable Docker
systemctl start docker
systemctl enable docker

# Install Docker Compose
log_info "Installing Docker Compose..."
DOCKER_COMPOSE_VERSION=$(curl -s https://api.github.com/repos/docker/compose/releases/latest | grep '"tag_name":' | cut -d'"' -f4)
curl -L "https://github.com/docker/compose/releases/download/${DOCKER_COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose

# Install Jenkins
log_info "Installing Jenkins..."
curl -fsSL https://pkg.jenkins.io/debian-stable/jenkins.io.key | tee /usr/share/keyrings/jenkins-keyring.asc > /dev/null
echo deb [signed-by=/usr/share/keyrings/jenkins-keyring.asc] https://pkg.jenkins.io/debian-stable binary/ | tee /etc/apt/sources.list.d/jenkins.list > /dev/null
apt-get update
apt-get install -y jenkins

# Add Jenkins to Docker group
usermod -aG docker jenkins

# Start and enable Jenkins
systemctl start jenkins
systemctl enable jenkins

# Configure Sendmail
log_info "Configuring Sendmail..."
# Backup original sendmail config
cp /etc/mail/sendmail.mc /etc/mail/sendmail.mc.backup

# Configure sendmail to listen on all interfaces and port 25
sed -i 's/DAEMON_OPTIONS(`Port=smtp, Addr=127.0.0.1, Name=MTA`)dnl/DAEMON_OPTIONS(`Port=smtp, Addr=0.0.0.0, Name=MTA`)dnl/' /etc/mail/sendmail.mc

# Regenerate sendmail configuration
makemap hash /etc/mail/access < /etc/mail/access
m4 /etc/mail/sendmail.mc > /etc/mail/sendmail.cf

# Restart sendmail
systemctl restart sendmail

# Install and configure PostgreSQL
log_info "Installing and configuring PostgreSQL..."
apt-get install -y postgresql postgresql-contrib

# Set up PostgreSQL user and database
sudo -u postgres psql -c "CREATE USER stockuser WITH PASSWORD 'stockpassword';"
sudo -u postgres psql -c "CREATE DATABASE stockanalysis OWNER stockuser;"
sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE stockanalysis TO stockuser;"

# Configure PostgreSQL to accept connections
sed -i "s/#listen_addresses = 'localhost'/listen_addresses = '*'/" /etc/postgresql/*/main/postgresql.conf
echo "host all all 0.0.0.0/0 md5" >> /etc/postgresql/*/main/pg_hba.conf

systemctl restart postgresql

# Install and configure MongoDB
log_info "Installing and configuring MongoDB..."
wget -qO - https://www.mongodb.org/static/pgp/server-6.0.asc | apt-key add -
echo "deb [ arch=amd64,arm64 ] https://repo.mongodb.org/apt/ubuntu $(lsb_release -cs)/mongodb-org/6.0 multiverse" | tee /etc/apt/sources.list.d/mongodb-org-6.0.list
apt-get update
apt-get install -y mongodb-org

# Start and enable MongoDB
systemctl start mongod
systemctl enable mongod

# Create MongoDB user
mongosh --eval "use admin; db.createUser({user: 'stockuser', pwd: 'stockpassword', roles: ['readWriteAnyDatabase']})"

# Install and configure Redis
log_info "Installing and configuring Redis..."
apt-get install -y redis-server

# Configure Redis
sed -i 's/supervised no/supervised systemd/' /etc/redis/redis.conf
sed -i 's/bind 127.0.0.1 ::1/bind 0.0.0.0/' /etc/redis/redis.conf
echo "requirepass redispassword" >> /etc/redis/redis.conf

systemctl restart redis

# Install Python libraries
log_info "Installing Python libraries..."
pip3 install --upgrade pip

# Data analysis and visualization
pip3 install \
    numpy \
    pandas \
    matplotlib \
    seaborn \
    plotly \
    scipy \
    scikit-learn

# Machine learning and AI
pip3 install \
    tensorflow \
    torch \
    torchvision \
    transformers \
    langchain \
    openai \
    llama-index

# API and web frameworks
pip3 install \
    flask \
    fastapi \
    django \
    requests \
    beautifulsoup4 \
    scrapy

# Database connectors
pip3 install \
    psycopg2-binary \
    pymongo \
    redis \
    sqlalchemy

# Financial libraries
pip3 install \
    yfinance \
    alpha-vantage \
    pandas-datareader \
    ta-lib

# Other utilities
pip3 install \
    jupyter \
    notebook \
    python-dotenv \
    celery \
    pytest

# Create project directory
log_info "Creating project directory..."
mkdir -p /opt/stock-analysis-platform
chmod 755 /opt/stock-analysis-platform

# Display installation summary
log_info "Installation completed successfully!"
echo ""
echo "=================== INSTALLATION SUMMARY ==================="
echo "Docker: Installed and running"
echo "Docker Compose: Installed"
echo "Jenkins: Installed and running (Port 8080)"
echo "Sendmail: Configured to listen on port 25"
echo "PostgreSQL: Installed with user 'stockuser' and database 'stockanalysis'"
echo "MongoDB: Installed with user 'stockuser'"
echo "Redis: Installed with password 'redispassword'"
echo "Python libraries: All required libraries installed"
echo "Project directory: /opt/stock-analysis-platform"
echo ""
echo "Next steps:"
echo "1. Access Jenkins at http://$(hostname -I | awk '{print $1}'):8080"
echo "2. Get the initial admin password: sudo cat /var/lib/jenkins/secrets/initialAdminPassword"
echo "3. Set up your Jenkins pipeline"
echo "4. Begin developing your stock analysis platform in /opt/stock-analysis-platform"
echo "============================================================"

# Save credentials to file
cat > /opt/stock-analysis-platform/credentials.txt << EOL
Database Credentials:
PostgreSQL:
  Username: stockuser
  Password: stockpassword
  Database: stockanalysis

MongoDB:
  Username: stockuser
  Password: stockpassword

Redis:
  Password: redispassword

Please change these default passwords in production!
EOL

log_warning "Credentials saved to /opt/stock-analysis-platform/credentials.txt"
log_warning "Please change these default passwords for production use!"



