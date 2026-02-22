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
        stage('Install Dependencies') {
            steps {
                sh '''
                    python3 -m venv venv
                    . venv/bin/activate
                    pip install -r requirements.txt
                '''
            }
        }

        stage('Run Tests') {
            steps {
                sh '''
                    . venv/bin/activate
                    pytest test_app.py -v --junitxml=test-results.xml
                '''
            }
            post {
                always {
                    junit 'test-results.xml'
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
        }

        stage('Deploy') {
            steps {
                echo 'Deploying application...'
                sh """
                    docker stop ${APP_NAME} || true
                    docker rm ${APP_NAME} || true
                    docker run -d --name ${APP_NAME} -p ${APP_PORT}:5000 ${DOCKER_IMAGE}
                """
            }
        }

        stage('Health Check') {
            steps {
                sh """
                    sleep 5
                    curl -f http://localhost:${APP_PORT}/health || exit 1
                """
            }
        }
    }

    post {
        success {
            echo 'Pipeline completed successfully!'
        }
        failure {
            echo 'Pipeline failed!'
        }
        always {
            echo 'Cleaning up...'
            sh 'docker system prune -f'
        }
    }
}
