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
        AWS_DEFAULT_REGION  = 'eu-north-1'
        AWS_REGION          = 'eu-north-1'
        AWS_MAX_ATTEMPTS    = '5'
        AWS_RETRY_MODE      = 'standard'
        TF_PLUGIN_CACHE_DIR = '/var/jenkins_home/.terraform.d/plugin-cache'
        ECR_REPOSITORY      = 'damolak-api'
        TF_DIR              = 'infra/envs/dev'
        DEPLOYED_URL        = ''
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
                        ACCOUNT_ID=$(cat /tmp/account_id.txt 2>/dev/null || true)
                        if [ -z "${ACCOUNT_ID}" ]; then
                            for i in 1 2 3 4 5; do
                                ACCOUNT_ID=$(aws sts get-caller-identity --query "Account" --output text 2>/dev/null || true)
                                [ -n "${ACCOUNT_ID}" ] && break || sleep 2
                            done
                        fi
                        if [ -z "${ACCOUNT_ID}" ]; then
                            echo "ERROR: Failed to retrieve AWS Account ID" >&2
                            exit 1
                        fi
                        echo "${ACCOUNT_ID}" > /tmp/account_id.txt
                        REGISTRY="${ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"
                        LOGGED_IN=false
                        for i in 1 2 3 4 5; do
                            LOGIN_PASS=$(aws ecr get-login-password --region "${AWS_REGION}" 2>/dev/null || true)
                            if [ -n "${LOGIN_PASS}" ]; then
                                if echo "${LOGIN_PASS}" | docker login --username AWS --password-stdin "${REGISTRY}"; then
                                    LOGGED_IN=true
                                    break
                                fi
                            fi
                            sleep 3
                        done
                        if [ "${LOGGED_IN}" != "true" ]; then
                            echo "ERROR: Failed to authenticate to ECR registry" >&2
                            exit 1
                        fi
                        docker tag "${ECR_REPOSITORY}:${GIT_SHA}" "${REGISTRY}/${ECR_REPOSITORY}:${GIT_SHA}"
                        for i in 1 2 3; do
                            docker push "${REGISTRY}/${ECR_REPOSITORY}:${GIT_SHA}" && break || sleep 3
                        done
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
                        ACCOUNT_ID=$(cat /tmp/account_id.txt 2>/dev/null || true)
                        if [ -z "${ACCOUNT_ID}" ]; then
                            for i in 1 2 3 4 5; do
                                ACCOUNT_ID=$(aws sts get-caller-identity --query "Account" --output text 2>/dev/null || true)
                                [ -n "${ACCOUNT_ID}" ] && break || sleep 2
                            done
                        fi
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
                    script {
                        env.DEPLOYED_URL = sh(returnStdout: true, script: "terraform -chdir=${env.TF_DIR} output -raw service_url").trim()
                    }
                    sh '''
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
