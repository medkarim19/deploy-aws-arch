def EC2_PUBLIC_IP = ""
def RDS_ENDPOINT = ""
def DEPLOYER_KEY_URI = ""

pipeline {
    agent any
    
    environment {
      AWS_ACCESS_KEY_ID = credentials('jenkins_aws_access_key_id')
      AWS_SECRET_ACCESS_KEY = credentials('jenkins_aws_secret_access_key')
      ECR_REPO_URL = '682033469889.dkr.ecr.us-east-1.amazonaws.com'
      ECR_REPO_NAME = 'enis-app'
      IMAGE_REPO = "${ECR_REPO_URL}/${ECR_REPO_NAME}"
      IMAGE_REPO_FRONTEND = "${IMAGE_REPO}:frontend-app-1.0"
      IMAGE_REPO_BACKEND = "${IMAGE_REPO}:backend-app-1.0" 
      AWS_REGION = "us-east-1"
    }
    
    stages {
        stage('Checkout') {
            steps {
                checkout scmGit(branches: [[name: '*/main']], extensions: [], userRemoteConfigs: [[credentialsId: 'githubtoken', url: 'https://github.com/melekbadreddine/aws-pipeline']])
            }
        }
        stage('Provision Server and Database') {
            steps {
                script {
                    dir('terraform') {
                        // Initialize Terraform
                        sh "terraform init"
                        sh "terraform plan -lock=false"

                        // Apply Terraform configuration
                        sh "terraform apply -lock=false --auto-approve"

                        // Get EC2 Public IP
                        EC2_PUBLIC_IP = sh(
                            script: '''
                                terraform output instance_details | grep "instance_public_ip" | awk '{print $3}' | tr -d '"'
                            ''',
                            returnStdout: true
                        ).trim()

                        // Get RDS Endpoint
                        RDS_ENDPOINT = sh(
                            script: '''
                                terraform output rds_endpoint | grep "endpoint" | awk -F'=' '{print $2}' | tr -d '[:space:]"' | sed 's/:3306//'
                            ''',
                            returnStdout: true
                        ).trim()

                        // Get Deployer Key URI
                        DEPLOYER_KEY_URI = sh(
                            script: 'terraform output deployer_key_s3_uri | tr -d \'"\'',
                            returnStdout: true
                        ).trim()

                        // Debugging: Print captured values
                        echo "EC2 Public IP: ${EC2_PUBLIC_IP}"
                        echo "RDS Endpoint: ${RDS_ENDPOINT}"
                        echo "Deployer Key URI: ${DEPLOYER_KEY_URI}"
                    }
                }
            }
        }
        stage('Update Frontend Configuration') {
            steps {
                script {
                    dir('frontend/src') {
                        writeFile file: 'config.js', text: """
                            export const API_BASE_URL = 'http://${EC2_PUBLIC_IP}:8000';
                        """
                        sh '''
                            echo "Contents of config.js after update:"
                            cat config.js
                        '''
                    }
                }
            }
        }
        stage('Update Backend Configuration') {
            steps {
                script {
                    dir('backend/backend') {
                        // Verify the existence of settings.py
                        sh '''
                        if [ -f "settings.py" ]; then
                                echo "Found settings.py at $(pwd)"
                            else
                                echo "settings.py not found in $(pwd)!"
                                exit 1
                        fi
                        '''
                        // Update the HOST in the DATABASES section
                        sh """
                        sed -i "/'HOST':/c\\        'HOST': '${RDS_ENDPOINT}'," settings.py
                        """
                        // Verify the DATABASES section after the update
                        sh '''
                        echo "DATABASES section of settings.py after update:"
                        sed -n '/DATABASES = {/,/^}/p' settings.py
                        '''
                    }
                }
            }
        }
        stage('Create Database in RDS') {
            steps {
                script {
                    sh """
                    mysql -h ${RDS_ENDPOINT} -P 3306 -u dbuser -pDBpassword2024 -e "CREATE DATABASE IF NOT EXISTS enis_tp;"
                    mysql -h ${RDS_ENDPOINT} -P 3306 -u dbuser -pDBpassword2024 -e "SHOW DATABASES;"
                    """
                }
            }
        }
        stage('Build Frontend Docker Image') {
            steps {
                    dir('frontend') {
                        script {
                            echo 'Building Frontend Docker Image...'
                            def frontendImage = docker.build('frontend-app')
                            echo "Built Image: ${frontendImage.id}"
                        }
                    }
                }
            }
        stage('Build Backend Docker Image') {
            steps {
                    dir('backend') {
                        script {
                            echo 'Building Backend Docker Image...'
                            def backendImage = docker.build('backend-app')
                            echo "Built Image: ${backendImage.id}"
                        }
                    }
                }
            }
        stage('Login to AWS ECR') {
            steps {
                script {
                    sh '''
                    # Debug environment
                    echo "PATH: $PATH"
                    echo "AWS CLI version:"
                    aws --version || { echo "AWS CLI not installed"; exit 1; }

                    echo "Docker version:"
                    docker --version || { echo "Docker CLI not installed"; exit 1; }

                    # Login to ECR
                    aws ecr get-login-password --region ${AWS_REGION} | docker login --username AWS --password-stdin ${ECR_REPO_URL}
                    '''
                }
            }
        }
        stage('Tag and Push Frontend Image') {
            steps {
                    script {
                        echo 'Tagging and pushing Frontend Image...'
                        sh "docker tag frontend-app:latest $IMAGE_REPO_FRONTEND"
                        sh "docker push $IMAGE_REPO_FRONTEND"
                    }
                }
            }
        stage('Tag and Push Backend Image') {
            steps {
                script {
                    echo 'Tagging and pushing Backend Image...'
                    sh "docker tag backend-app:latest $IMAGE_REPO_BACKEND"
                    sh "docker push $IMAGE_REPO_BACKEND"
                }
            }
        }
        stage('Download SSH Key from S3') {
            steps {
                script {
                    dir('ansible') {
                        sh """
                        # Check and delete the existing key if it exists
                        if [ -f "deployer_key.pem" ]; then
                            echo "Deleting existing deployer_key.pem"
                            rm deployer_key.pem
                        fi


                        # Download the SSH key from S3
                        aws s3 cp ${DEPLOYER_KEY_URI} deployer_key.pem


                        # Set the proper permissions for the private key
                        chmod 600 deployer_key.pem
                        """
                    }
                }
            }
        }
        stage('Update Hosts File') {
            steps {
                script {
                    dir('ansible') {
                        sh """
                        if [ -f "hosts" ]; then
                            echo "Found hosts file at \$(pwd)"
                            sed -i "2s|.*|${EC2_PUBLIC_IP}|" hosts
                            echo "Updated hosts file:"
                            cat hosts
                        else
                            echo "hosts file not found in \$(pwd)!"
                            exit 1
                        fi
                        """
                    }
                }
            }
        }
        stage('Run Ansible Playbook') {
            steps {
                script {
                    dir('ansible') {
                        sh """
                        if [ -f "docker_deploy_playbook.yml" ]; then
                            echo "Found playbook docker_deploy_playbook.yml"


                            # Ensure community.docker collection is installed
                            ansible-galaxy collection install community.docker --force


                            # Run the Ansible playbook
                            ansible-playbook -i hosts docker_deploy_playbook.yml
                        else
                            echo "Playbook docker_deploy_playbook.yml not found!"
                            exit 1
                        fi
                        """
                    }
                }
            }
        }

    }
    post {
       success {
           script {
               def instanceUrl = "http://${EC2_PUBLIC_IP}:81"
               echo "The instance is successfully deployed. Access it here: ${instanceUrl}"
           }
       }
       failure {
           echo "The pipeline failed. Please check the logs for details."
       }
   }
}
