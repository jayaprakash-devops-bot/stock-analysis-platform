#!/bin/bash

# Jenkins Plugin Installation Script
# This script installs recommended plugins for a comprehensive CI/CD pipeline

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

# Check if Jenkins is running
JENKINS_STATUS=$(systemctl is-active jenkins)
if [ "$JENKINS_STATUS" != "active" ]; then
    log_error "Jenkins is not running. Please start Jenkins first."
    exit 1
fi

# Get Jenkins CLI
JENKINS_URL="http://localhost:8080"
JENKINS_CLI_JAR="/tmp/jenkins-cli.jar"

log_info "Downloading Jenkins CLI..."
wget -q -O $JENKINS_CLI_JAR $JENKINS_URL/jnlpJars/jenkins-cli.jar

if [ ! -f "$JENKINS_CLI_JAR" ]; then
    log_error "Failed to download Jenkins CLI"
    exit 1
fi


JENKINS_PASSWORD="1af12c9c993849759b74595c11456466"
JENKINS_USER="administrator"

# List of essential plugins to install
PLUGINS=(
    # Core plugins
    "workflow-aggregator"           # Pipeline
    "build-timeout"                 # Build timeout
    "credentials-binding"           # Credentials binding
    "timestamper"                   # Timestamps in console output
    "ws-cleanup"                    # Workspace cleanup
    
    # Git and SCM
    "git"                           # Git integration
    "github"                        # GitHub integration
    "github-branch-source"          # GitHub branch source
    "git-parameter"                 # Git parameter
    
    # Docker and containerization
    "docker-plugin"                 # Docker plugin
    "docker-workflow"               # Docker pipeline
    "docker-commons"                # Docker common functions
    
    # Python and data science
    "python"                        # Python plugin
    "ansible"                       # Ansible integration
    "pipeline-utility-steps"        # Utility steps for pipeline
    
    # Database and data tools
    "database"                      # Database plugin
    "database-mysql"                # MySQL database
    "database-postgresql"           # PostgreSQL database
    "mongodb"                       # MongoDB plugin
    
    # Notification and reporting
    "email-ext"                     # Extended email notifications
    "mailer"                        # Email notifications
    "slack"                         # Slack notifications
    "telegram"                      # Telegram notifications
    
    # UI and visualization
    "blueocean"                     # Blue Ocean UI
    "dashboard-view"                # Dashboard view
    "plot"                          # Plot plugin
    "analysis-core"                 # Analysis core
    
    # Security
    "role-strategy"                 # Role-based authorization
    "matrix-auth"                   # Matrix authorization
    "ssh-agent"                     # SSH agent
    "ssh-slaves"                    # SSH slaves
    
    # Build and test tools
    "junit"                         # JUnit test results
    "htmlpublisher"                 # HTML publisher
    "warnings-ng"                   # Warnings next generation
    "cobertura"                     # Cobertura coverage report
    
    # Utilities
    "parameterized-trigger"         # Parameterized trigger
    "copyartifact"                  # Copy artifacts
    "envinject"                     # Environment injector
    "config-file-provider"          # Config file provider
    
    # Monitoring and metrics
    "metrics"                       # Metrics plugin
    "prometheus"                    # Prometheus metrics
    "jacoco"                        # JaCoCo code coverage
    
    # API and integration
    "rest-api"                      # REST API
    "script-security"               # Script security
    "job-dsl"                       # Job DSL
    "configuration-as-code"         # Jenkins Configuration as Code
)

log_info "Installing Jenkins plugins..."
for plugin in "${PLUGINS[@]}"; do
    log_debug "Installing $plugin..."
    java -jar $JENKINS_CLI_JAR -s $JENKINS_URL -auth $JENKINS_USER:$JENKINS_PASSWORD install-plugin $plugin
done

log_info "Restarting Jenkins to apply plugin changes..."
java -jar $JENKINS_CLI_JAR -s $JENKINS_URL -auth $JENKINS_USER:$JENKINS_PASSWORD safe-restart

log_info "Plugin installation completed!"
log_info "Jenkins will restart with the new plugins."
log_info "Access Jenkins at: $JENKINS_URL"

# Create a plugin list file for reference
cat > /root/jenkins_plugins_list.txt << EOL
Jenkins Plugins Installed:
$(printf "%s\n" "${PLUGINS[@]}")
EOL

log_info "Plugin list saved to /root/jenkins_plugins_list.txt"


