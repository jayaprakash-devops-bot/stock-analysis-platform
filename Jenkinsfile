pipeline {
  agent any
  stages {
    stage('Checkout') {
      steps {
        checkout scm
        script {
          currentBuild.displayName = "#${env.BUILD_ID} - ${env.GIT_BRANCH}"
          currentBuild.description = "Commit: ${env.GIT_COMMIT.take(8)}"
        }

      }
    }

    stage('Setup Environment') {
      steps {
        sh '''
                    echo "Setting up Python environment..."
                    python -m venv venv
                    source venv/bin/activate
                    pip install --upgrade pip
                '''
      }
    }

    stage('Install Dependencies') {
      steps {
        sh '''
                    source venv/bin/activate
                    echo "Installing Python dependencies..."
                    pip install -r requirements.txt
                    
                    echo "Installing testing dependencies..."
                    pip install pytest pytest-cov flake8
                '''
      }
    }

    stage('Code Quality Check') {
      steps {
        sh '''
                    source venv/bin/activate
                    echo "Running flake8 code style check..."
                    flake8 . --count --select=E9,F63,F7,F82 --show-source --statistics
                    flake8 . --count --exit-zero --max-complexity=10 --max-line-length=127 --statistics
                '''
      }
    }

    stage('Unit Tests') {
      post {
        always {
          junit 'test-reports/*.xml'
          publishHTML([
                                    allowMissing: false,
                                    alwaysLinkToLastBuild: false,
                                    keepAll: true,
                                    reportDir: 'htmlcov',
                                    reportFiles: 'index.html',
                                    reportName: 'Python Coverage Report'
                                ])
          }

        }
        steps {
          sh '''
                    source venv/bin/activate
                    echo "Running unit tests with coverage..."
                    python -m pytest tests/unit/ -v --cov=src --cov-report=xml:coverage.xml
                '''
        }
      }

      stage('Integration Tests') {
        post {
          always {
            sh 'docker-compose -f docker-compose.test.yml down'
          }

        }
        steps {
          sh '''
                    source venv/bin/activate
                    echo "Starting test database..."
                    docker-compose -f docker-compose.test.yml up -d
                    
                    echo "Waiting for database to be ready..."
                    sleep 10
                    
                    echo "Running integration tests..."
                    python -m pytest tests/integration/ -v
                '''
        }
      }

      stage('Build Docker Images') {
        steps {
          script {
            echo "Building Docker images..."
            sh "docker build -t ${DOCKER_REGISTRY}/${DOCKER_NAMESPACE}/${APP_NAME}-api:${VERSION} -f docker/api.Dockerfile ."
            sh "docker build -t ${DOCKER_REGISTRY}/${DOCKER_NAMESPACE}/${APP_NAME}-frontend:${VERSION} -f docker/frontend.Dockerfile ."
            sh "docker build -t ${DOCKER_REGISTRY}/${DOCKER_NAMESPACE}/${APP_NAME}-worker:${VERSION} -f docker/worker.Dockerfile ."
          }

        }
      }

      stage('Security Scan') {
        steps {
          script {
            echo "Scanning Docker images for vulnerabilities..."
            sh "docker scan ${DOCKER_REGISTRY}/${DOCKER_NAMESPACE}/${APP_NAME}-api:${VERSION}"
            sh "docker scan ${DOCKER_REGISTRY}/${DOCKER_NAMESPACE}/${APP_NAME}-frontend:${VERSION}"
          }

        }
      }

      stage('Push to Registry') {
        when {
          branch 'main'
        }
        steps {
          script {
            echo "Logging into Docker registry..."
            withCredentials([usernamePassword(credentialsId: 'docker-registry-creds', usernameVariable: 'DOCKER_USER', passwordVariable: 'DOCKER_PASSWORD')]) {
              sh "echo ${DOCKER_PASSWORD} | docker login ${DOCKER_REGISTRY} -u ${DOCKER_USER} --password-stdin"
            }

            echo "Pushing images to registry..."
            sh "docker push ${DOCKER_REGISTRY}/${DOCKER_NAMESPACE}/${APP_NAME}-api:${VERSION}"
            sh "docker push ${DOCKER_REGISTRY}/${DOCKER_NAMESPACE}/${APP_NAME}-frontend:${VERSION}"
            sh "docker push ${DOCKER_REGISTRY}/${DOCKER_NAMESPACE}/${APP_NAME}-worker:${VERSION}"

            // Also tag as latest for main branch
            sh "docker tag ${DOCKER_REGISTRY}/${DOCKER_NAMESPACE}/${APP_NAME}-api:${VERSION} ${DOCKER_REGISTRY}/${DOCKER_NAMESPACE}/${APP_NAME}-api:latest"
            sh "docker tag ${DOCKER_REGISTRY}/${DOCKER_NAMESPACE}/${APP_NAME}-frontend:${VERSION} ${DOCKER_REGISTRY}/${DOCKER_NAMESPACE}/${APP_NAME}-frontend:latest"
            sh "docker push ${DOCKER_REGISTRY}/${DOCKER_NAMESPACE}/${APP_NAME}-api:latest"
            sh "docker push ${DOCKER_REGISTRY}/${DOCKER_NAMESPACE}/${APP_NAME}-frontend:latest"
          }

        }
      }

      stage('Deploy to Staging') {
        when {
          branch 'main'
        }
        steps {
          script {
            echo "Deploying to staging environment..."
            sh "ansible-playbook -i inventory/staging deploy.yml -e app_version=${VERSION}"
          }

        }
      }

      stage('Run E2E Tests') {
        when {
          branch 'main'
        }
        steps {
          script {
            echo "Running end-to-end tests on staging..."
            sh "python -m pytest tests/e2e/ -v --url=http://staging.your-domain.com"
          }

        }
      }

      stage('Deploy to Production') {
        when {
          branch 'main'
          expression {
            return currentBuild.resultIsBetterOrEqualTo('SUCCESS')
          }

        }
        steps {
          script {
            timeout(time: 15, unit: 'MINUTES') {
              input(message: 'Deploy to production?', ok: 'Deploy')
            }

            echo "Deploying to production environment..."
            sh "ansible-playbook -i inventory/production deploy.yml -e app_version=${VERSION}"
          }

        }
      }

    }
    environment {
      DOCKER_REGISTRY = 'your-docker-registry.com'
      DOCKER_NAMESPACE = 'stock-analysis'
      APP_NAME = 'stock-analysis-platform'
      VERSION = "${env.BUILD_ID}"
      POSTGRES_HOST = 'localhost'
      POSTGRES_DB = 'stockanalysis'
      POSTGRES_USER = credentials('postgres-user')
      POSTGRES_PASSWORD = credentials('postgres-password')
      PYTHON_VERSION = '3.9'
    }
    post {
      always {
        echo "Pipeline completed with status: ${currentBuild.result}"
        cleanWs()
      }

      success {
        slackSend(color: 'good', message: "Pipeline SUCCESS: ${env.JOB_NAME} #${env.BUILD_NUMBER}")
      }

      failure {
        slackSend(color: 'danger', message: "Pipeline FAILED: ${env.JOB_NAME} #${env.BUILD_NUMBER}")
      }

      unstable {
        slackSend(color: 'warning', message: "Pipeline UNSTABLE: ${env.JOB_NAME} #${env.BUILD_NUMBER}")
      }

    }
    options {
      buildDiscarder(logRotator(numToKeepStr: '10'))
      timeout(time: 30, unit: 'MINUTES')
      disableConcurrentBuilds()
    }
  }