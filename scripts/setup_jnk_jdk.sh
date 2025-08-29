#!/bin/bash

# Java and Jenkins Installation Script
# This script will install Java JDK 17+ and the latest Jenkins

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
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

log_debug() {
    echo -e "${BLUE}[DEBUG]${NC} $1"
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
    curl \
    wget \
    gnupg \
    software-properties-common \
    apt-transport-https \
    ca-certificates

# Install Java JDK 17
log_info "Installing Java JDK 17..."
apt-get install -y openjdk-17-jdk

# Alternatively, if you want to install the latest Java LTS version (21 as of 2023)
# You can use the following commands:
# add-apt-repository -y ppa:linuxuprising/java
# apt-get update
# apt-get install -y oracle-java21-installer

# Verify Java installation
java_version=$(java -version 2>&1 | awk -F '"' '/version/ {print $2}')
if [ -z "$java_version" ]; then
    log_error "Java installation failed"
    exit 1
else
    log_info "Java version $java_version installed successfully"
fi

# Set JAVA_HOME environment variable
JAVA_HOME=$(update-alternatives --list java | head -n1 | sed 's|/bin/java||')
echo "export JAVA_HOME=$JAVA_HOME" >> /etc/environment
echo "export PATH=\$PATH:\$JAVA_HOME/bin" >> /etc/environment
source /etc/environment
log_info "JAVA_HOME set to $JAVA_HOME"

# Install Jenkins
log_info "Installing Jenkins..."

# Add Jenkins repository key
curl -fsSL https://pkg.jenkins.io/debian-stable/jenkins.io-2023.key | tee \
  /usr/share/keyrings/jenkins-keyring.asc > /dev/null

# Add Jenkins repository
echo "deb [signed-by=/usr/share/keyrings/jenkins-keyring.asc]" \
  https://pkg.jenkins.io/debian-stable binary/ | tee \
  /etc/apt/sources.list.d/jenkins.list > /dev/null

# Update package list
apt-get update

# Install Jenkins
apt-get install -y jenkins

# Start and enable Jenkins
log_info "Starting Jenkins service..."
systemctl start jenkins
systemctl enable jenkins

# Wait for Jenkins to start
sleep 10

# Check Jenkins status
JENKINS_STATUS=$(systemctl is-active jenkins)
if [ "$JENKINS_STATUS" = "active" ]; then
    log_info "Jenkins is running successfully"
else
    log_error "Jenkins failed to start"
    systemctl status jenkins
    exit 1
fi

# Configure firewall (if enabled)
if command -v ufw &> /dev/null; then
    if ufw status | grep -q "active"; then
        log_info "Configuring firewall for Jenkins..."
        ufw allow 8080
        ufw allow OpenSSH
        ufw reload
    fi
fi

# Get initial admin password
JENKINS_INITIAL_PASSWORD=""
if [ -f /var/lib/jenkins/secrets/initialAdminPassword ]; then
    JENKINS_INITIAL_PASSWORD=$(cat /var/lib/jenkins/secrets/initialAdminPassword)
    log_info "Jenkins initial admin password: $JENKINS_INITIAL_PASSWORD"
else
    log_warning "Could not find Jenkins initial admin password file"
fi

# Display installation summary
log_info "Installation completed successfully!"
echo ""
echo "=================== INSTALLATION SUMMARY ==================="
echo "Java Version: $java_version"
echo "JAVA_HOME: $JAVA_HOME"
echo "Jenkins Status: $JENKINS_STATUS"
echo "Jenkins Port: 8080"
echo "Jenkins Initial Admin Password: $JENKINS_INITIAL_PASSWORD"
echo ""
echo "Next steps:"
echo "1. Access Jenkins at http://$(hostname -I | awk '{print $1}'):8080"
echo "2. Enter the initial admin password shown above"
echo "3. Install suggested plugins"
echo "4. Create your admin user"
echo "============================================================"

# Save credentials to file
cat > /root/jenkins_credentials.txt << EOL
Java Installation:
  Version: $java_version
  JAVA_HOME: $JAVA_HOME

Jenkins Installation:
  Status: $JENKINS_STATUS
  URL: http://$(hostname -I | awk '{print $1}'):8080
  Initial Admin Password: $JENKINS_INITIAL_PASSWORD

To get the initial admin password again, run:
sudo cat /var/lib/jenkins/secrets/initialAdminPassword
EOL

log_info "Credentials saved to /root/jenkins_credentials.txt"

# Optional: Install commonly used Jenkins plugins
log_info "To install common Jenkins plugins, you can use the following script after Jenkins setup:"
cat > /root/install_jenkins_plugins.sh << 'EOL'
#!/bin/bash
# Script to install common Jenkins plugins
JENKINS_URL="http://localhost:8080"
JENKINS_USER="admin"
JENKINS_PASSWORD="$1"

if [ -z "$JENKINS_PASSWORD" ]; then
    echo "Usage: $0 <jenkins_admin_password>"
    exit 1
fi

# List of common plugins to install
PLUGINS="git github workflow-aggregator pipeline-stage-view blueocean docker-workflow ssh-slaves email-ext mailer"

# Get Jenkins CLI
wget "$JENKINS_URL/jnlpJars/jenkins-cli.jar"

# Install each plugin
for plugin in $PLUGINS; do
    echo "Installing $plugin..."
    java -jar jenkins-cli.jar -s "$JENKINS_URL" -auth "$JENKINS_USER:$JENKINS_PASSWORD" install-plugin "$plugin"
done

# Restart Jenkins after installing plugins
echo "Restarting Jenkins..."
java -jar jenkins-cli.jar -s "$JENKINS_URL" -auth "$JENKINS_USER:$JENKINS_PASSWORD" safe-restart

echo "Plugin installation completed. Jenkins is restarting..."
EOL

chmod +x /root/install_jenkins_plugins.sh
log_info "Plugin installation script created at /root/install_jenkins_plugins.sh"
