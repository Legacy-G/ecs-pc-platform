pipeline {
    agent any

    options {
        timestamps()
        timeout(time: 30, unit: 'MINUTES')
        disableConcurrentBuilds()
        buildDiscarder(logRotator(numToKeepStr: '10'))
    }

    triggers {
        pollSCM('H/2 * * * *')
    }

    environment {
        AWS_DEFAULT_REGION = 'eu-north-1'
        AWS_REGION         = 'eu-north-1'
        AWS_MAX_ATTEMPTS   = '5'
        AWS_RETRY_MODE     = 'standard'
        ECR_REPOSITORY     = 'damolak-api'
        TF_DIR             = 'infra/envs/dev'
        DEPLOYED_URL       = ''
    }

    stages {
        stage('Checkout') {
            steps {
                checkout scm
                script {
                    env.GIT_SHA = sh(returnStdout: true, script: 'git rev-parse --short HEAD').trim()
                    echo "Checking out Git commit: ${env.GIT_SHA}"
                }
            }
        }

        stage('Lint') {
            steps {
                sh 'bash scripts/check-prose.sh'
            }
        }

        stage('Unit Tests') {
            steps {
                sh 'pytest -v --junitxml=test-results.xml services/api/tests'
            }
        }

        stage('Build') {
            steps {
                sh "docker build --provenance=false --sbom=false --load -t ${env.ECR_REPOSITORY}:${env.GIT_SHA} services/api"
            }
        }

        stage('Image scan') {
            steps {
                sh """
                    docker run --rm \
                      -v /var/run/docker.sock:/var/run/docker.sock \
                      aquasec/trivy:0.76.2 image \
                      --no-progress \
                      --ignore-unfixed \
                      --severity HIGH,CRITICAL \
                      --exit-code 0 \
                      ${env.ECR_REPOSITORY}:${env.GIT_SHA} || true
                """
            }
        }

        stage('Push to ECR') {
            steps {
                withCredentials([usernamePassword(
                    credentialsId: 'aws-jenkins-ci',
                    usernameVariable: 'AWS_ACCESS_KEY_ID',
                    passwordVariable: 'AWS_SECRET_ACCESS_KEY'
                )]) {
                    sh '''
                        ACCOUNT_ID=$(aws sts get-caller-identity --query "Account" --output text)
                        echo "${ACCOUNT_ID}" > /tmp/account_id.txt
                        REGISTRY="${ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"
                        aws ecr get-login-password --region "${AWS_REGION}" | docker login --username AWS --password-stdin "${REGISTRY}"
                        docker tag "${ECR_REPOSITORY}:${GIT_SHA}" "${REGISTRY}/${ECR_REPOSITORY}:${GIT_SHA}"
                        docker push "${REGISTRY}/${ECR_REPOSITORY}:${GIT_SHA}"
                    '''
                }
            }
        }

        stage('Terraform fmt/validate/plan') {
            steps {
                withCredentials([usernamePassword(
                    credentialsId: 'aws-jenkins-ci',
                    usernameVariable: 'AWS_ACCESS_KEY_ID',
                    passwordVariable: 'AWS_SECRET_ACCESS_KEY'
                )]) {
                    sh '''
                        ACCOUNT_ID=$(cat /tmp/account_id.txt 2>/dev/null || aws sts get-caller-identity --query "Account" --output text)
                        cat > ${TF_DIR}/backend.hcl <<EOF
bucket       = "damolak-tfstate-${ACCOUNT_ID}-${AWS_REGION}"
key          = "dev/terraform.tfstate"
region       = "${AWS_REGION}"
encrypt      = true
use_lockfile = true
EOF
                        terraform fmt -check -recursive infra
                        terraform -chdir="${TF_DIR}" init -backend-config=backend.hcl -input=false
                        terraform -chdir="${TF_DIR}" validate
                        terraform -chdir="${TF_DIR}" plan -input=false \
                          -var="image_tag=${GIT_SHA}" \
                          -var="git_sha=${GIT_SHA}" \
                          -out=jenkins.tfplan
                    '''
                }
            }
        }

        stage('Apply plan') {
            when {
                branch 'main'
            }
            steps {
                withCredentials([usernamePassword(
                    credentialsId: 'aws-jenkins-ci',
                    usernameVariable: 'AWS_ACCESS_KEY_ID',
                    passwordVariable: 'AWS_SECRET_ACCESS_KEY'
                )]) {
                    sh '''
                        terraform -chdir="${TF_DIR}" apply -input=false jenkins.tfplan
                        rm -f "${TF_DIR}/jenkins.tfplan"
                    '''
                }
            }
        }

        stage('ALB Smoke Test') {
            when {
                branch 'main'
            }
            steps {
                withCredentials([
                    usernamePassword(
                        credentialsId: 'aws-jenkins-ci',
                        usernameVariable: 'AWS_ACCESS_KEY_ID',
                        passwordVariable: 'AWS_SECRET_ACCESS_KEY'
                    ),
                    string(
                        credentialsId: 'ssm-api-key',
                        variable: 'API_KEY'
                    )
                ]) {
                    sh '''
                        DEPLOYED_URL=$(terraform -chdir="${TF_DIR}" output -raw service_url)
                        echo "Running smoke test against ALB URL: ${DEPLOYED_URL}"
                        bash scripts/smoke.sh "${DEPLOYED_URL}" "${GIT_SHA}"
                    '''
                }
            }
        }
    }

    post {
        always {
            archiveArtifacts artifacts: 'test-results.xml', allowEmptyArchive: true
            deleteDir()
        }
        success {
            script {
                echo "==========================================================="
                echo "Deployment Successful!"
                echo "Deployed URL: ${env.DEPLOYED_URL}"
                echo "Deployed SHA: ${env.GIT_SHA}"
                echo "==========================================================="
            }
        }
    }
}
