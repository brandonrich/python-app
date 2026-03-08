pipeline {
    agent any

    triggers {
        pollSCM('H/5 * * * *')  // Poll GitHub every 5 minutes for changes
    }

    environment {
        APP_NAME = 'python-demo-app'
        APP_PORT = '5001'
        GIT_COMMIT_SHORT = sh(script: "git rev-parse --short HEAD", returnStdout: true).trim()
        DOCKER_IMAGE = "${APP_NAME}:${GIT_COMMIT_SHORT}"
    }

    stages {
        stage('Checkout') {
            steps {
                echo "Checking out code from GitHub"
                checkout scm
                slackSend(
                    channel: '#build',
                    message: "🛠️ Build started for ${env.JOB_NAME} #${env.BUILD_NUMBER}\nLink: ${env.BUILD_URL}"
                )
            }
        }
                
        stage('Install Dependencies') {
            steps {
                sh '''
                    python3 -m venv .venv
                    . .venv/bin/activate
                    pip install -r requirements.txt
                '''
            }
        }

        stage('Quality Checks') {
            parallel {
                stage('Run Tests') {
                    steps {
                        sh '''
                            . .venv/bin/activate
                            pytest test_app.py -v --junitxml=test-results.xml
                        '''
                    }
                    post {
                        always {
                            junit 'test-results.xml'
                        }
                    }
                }

                stage('Run linting with Ruff') {
                    steps {
                        sh '''
                            . .venv/bin/activate
                            ruff check .
                        '''
                    }
                }

                stage('Run security scan with Bandit') {
                    steps {
                        sh '''
                            . .venv/bin/activate
                            pwd
                            ls -la bandit.yml  
                            echo "contents of bandit.yml:"
                            cat bandit.yml                  
                            bandit -r . -c bandit.yml
                        '''
                    }
                }
            }
        }

        stage('Build Docker Image') {
            steps {
                sh "docker build -t ${DOCKER_IMAGE} ."
            }
        }

        stage('Push to Registry') {
            steps {
                // Note: This stage requires 'dockerhub-creds' credential in Jenkins
                // For local demo purposes, this stage can be skipped
                withCredentials([
                    usernamePassword(
                        credentialsId: 'dockerhub-creds',
                        usernameVariable: 'DOCKER_USER',
                        passwordVariable: 'DOCKER_PASS'
                    )
                ]) {
                    sh """
                        echo \${DOCKER_PASS} | docker login -u \${DOCKER_USER} --password-stdin
                        docker tag ${DOCKER_IMAGE} \${DOCKER_USER}/python-demo-app:${BUILD_NUMBER}
                        docker tag ${DOCKER_IMAGE} \${DOCKER_USER}/python-demo-app:${GIT_COMMIT_SHORT}
                        docker tag ${DOCKER_IMAGE} \${DOCKER_USER}/python-demo-app:latest
                        docker push \${DOCKER_USER}/python-demo-app:${BUILD_NUMBER}
                        docker push \${DOCKER_USER}/python-demo-app:${GIT_COMMIT_SHORT}
                        docker push \${DOCKER_USER}/python-demo-app:latest
                    """
                }
            }
            post {
                always {
                    sh 'docker logout'
                }
            }            
        }
    }

    post {
        success {
            echo 'Pipeline completed successfully!'
            slackSend(
                channel: '#build',
                message: "✅ Build succeeded for ${env.JOB_NAME} #${env.BUILD_NUMBER}\nLink: ${env.BUILD_URL}"
            )
        }
        failure {
            echo 'Pipeline failed!'
            slackSend(
                channel: '#build',
                message: "🚨 Build failed for ${env.JOB_NAME} #${env.BUILD_NUMBER}\nLink: ${env.BUILD_URL}\nError: ${env.BUILD_LOG}"
            )
        }
        always {
            echo 'Cleaning up...'
            sh 'docker system prune -f'
            cleanWs()
        }
    }
}
