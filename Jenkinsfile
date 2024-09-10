pipeline {
    agent any
    environment {
        AWS_ACCESS_KEY_ID = credentials('aws-access-key-id')
        AWS_SECRET_ACCESS_KEY = credentials('aws-secret-access-key')
    }
    stages {
        stage('Build Project') {
            steps {
                git 'https://github.com/lax66/star-agile-banking-finance_CAP01.git'
                sh 'mvn clean package'
            }
        }
        stage('Build Docker Image') {
            steps {
                script {
                    sh 'docker build -t laxg66/capstone01:v1 .'
                    sh 'docker images'
                }
            }
        }
        stage('Push to Docker Hub') {
            steps {
                withCredentials([usernamePassword(credentialsId: 'docker-creds', passwordVariable: 'PASS', usernameVariable: 'USER')]) {
                    sh "echo $PASS | docker login -u $USER --password-stdin"
                    sh 'docker push laxg66/capstone01:v1'
                }
            }
        }
        stage('Terraform Operations for Test Workspace') {
            steps {
                script {
                    sh '''
                    terraform workspace select test || terraform workspace new test
                    terraform init
                    terraform plan
                    terraform destroy -auto-approve || echo "Failed to destroy test resources"
                    terraform apply -auto-approve || echo "Failed to apply test resources"
                    '''
                }
            }
        }
        stage('Terraform Operations for Production Workspace') {
            when {
                expression { return currentBuild.currentResult == 'SUCCESS' }
            }
            steps {
                script {
                    sh '''
                    terraform workspace select prod || terraform workspace new prod
                    terraform init

                    # Import key pair if it exists in the state
                    if terraform state show aws_key_pair.example 2>/dev/null; then
                        echo "Key pair already exists in the prod workspace"
                    else
                        echo "Key pair does not exist in the state; Terraform will create it if needed."
                    fi

                    terraform plan
                    terraform apply -auto-approve || echo "Failed to apply production resources"
                    '''
                }
            }
        }
    }
    post {
        always {
            // Clean up Docker images or perform any necessary final steps
            sh 'docker system prune -af || echo "Failed to prune Docker system"'
        }
    }
}
