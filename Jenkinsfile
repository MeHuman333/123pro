pipeline {
    agent any
    environment {
        AWS_ACCESS_KEY_ID = credentials('aws-access-key-id')
        AWS_SECRET_ACCESS_KEY = credentials('aws-secret-access-key')
    }
    stages{
        stage('build project'){
            steps{
                git 'https://github.com/MeHuman333/123pro.git'
                sh 'mvn clean package'
              
            }
        }
        stage('Building  docker image'){
            steps{
                script{
                    sh 'docker build -t mehooman/capstone01:v1 .'
                    sh 'docker images'
                }
            }
        }
        stage('push to docker-hub'){
            steps{
                withCredentials([usernamePassword(credentialsId: 'docker-cred', passwordVariable: 'PASS', usernameVariable: 'USER')]) {
                    sh "echo $PASS | docker login -u $USER --password-stdin"
                    sh 'docker push mehooman/capstone01:v1'
                }
            }
        }
        
        stage('Terraform Operations for test workspace') {
            steps {
                sh '''
                terraform workspace select test || terraform workspace new test
                terraform init
                terraform plan
                terraform destroy -auto-approve
                '''
            }
        }
       stage('Terraform destroy & apply for test workspace') {
            steps {
                sh 'terraform apply -auto-approve'
            }
       }
       stage('Terraform Operations for Production workspace') {
            when {
                expression { return currentBuild.currentResult == 'SUCCESS' }
            }
            steps {
                sh '''
                #!/bin/bash

# Define the variables
                KEY_PAIR_NAME="key02"
                SECURITY_GROUP_ID="0544be77a2a16315f" # Use the provided Security Group ID

                # Select or create the Terraform workspace
                terraform workspace select prod || terraform workspace new prod

                # Initialize Terraform
                terraform init

                # Check if the key pair exists in the state and import if not
                if terraform state show aws_key_pair.example 2>/dev/null; then
                echo "Key pair already exists in the prod workspace"
                else
                echo "Importing key pair..."
                terraform import aws_key_pair.example $KEY_PAIR_NAME || echo "Key pair import failed or already exists"    
                fi

                # Check if the security group exists in the state and import if not
                if terraform state show aws_security_group.allow_ssh 2>/dev/null; then
                echo "Security group already exists in the prod workspace"
                else
                echo "Importing security group..."
                terraform import aws_security_group.allow_ssh $SECURITY_GROUP_ID || echo "Security group import failed or already exists"
                fi

# Destroy existing infrastructure
                terraform destroy -auto-approve

# Apply new configuration
                terraform apply -auto-approve

                             
                 '''
            }
       }
    }
}
