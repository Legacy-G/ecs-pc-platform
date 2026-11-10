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

        stage('Lint and Prose Audit') {
            steps {
                sh 'bash scripts/check-prose.sh'
            }
        }

        stage('Unit Tests') {
            steps {
                sh 'pytest -v --junitxml=test-results.xml services/api/tests'
            }
        }

        stage('Build Container Image') {
            steps {
                sh "docker build --provenance=false --sbom=false -t ${env.ECR_REPOSITORY}:${env.GIT_SHA} services/api"
            }
        }

        stage('Security Scan') {
            steps {
                sh """
                    docker run --rm \
                      -v /var/run/docker.sock:/var/run/docker.sock \
                      aquasec/trivy:0.76.2 image \
                      --ignore-unfixed \
                      --severity HIGH,CRITICAL \
                      --exit-code 0 \
                      ${env.ECR_REPOSITORY}:${env.GIT_SHA}
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
                    sh """
                        ACCOUNT_ID=\$(aws sts get-caller-identity --query "Account" --output text)
                        REGISTRY="\${ACCOUNT_ID}.dkr.ecr.${env.AWS_REGION}.amazonaws.com"
                        aws ecr get-login-password --region ${env.AWS_REGION} | docker login --username AWS --password-stdin "\${REGISTRY}"
                        docker tag ${env.ECR_REPOSITORY}:${env.GIT_SHA} "\${REGISTRY}/${env.ECR_REPOSITORY}:${env.GIT_SHA}"
                        docker push "\${REGISTRY}/${env.ECR_REPOSITORY}:${env.GIT_SHA}"
                    """
                }
            }
        }

        stage('Terraform Format, Validate, and Plan') {
            steps {
                withCredentials([usernamePassword(
                    credentialsId: 'aws-jenkins-ci',
                    usernameVariable: 'AWS_ACCESS_KEY_ID',
                    passwordVariable: 'AWS_SECRET_ACCESS_KEY'
                )]) {
                    sh """
                        terraform fmt -check -recursive infra
                        terraform -chdir=${env.TF_DIR} init -input=false
                        terraform -chdir=${env.TF_DIR} validate
                        terraform -chdir=${env.TF_DIR} plan -input=false \
                          -var="image_tag=${env.GIT_SHA}" \
                          -var="git_sha=${env.GIT_SHA}" \
                          -out=jenkins.tfplan
                    """
                }
            }
        }

        stage('Apply Plan') {
            when {
                branch 'main'
            }
            steps {
                withCredentials([usernamePassword(
                    credentialsId: 'aws-jenkins-ci',
                    usernameVariable: 'AWS_ACCESS_KEY_ID',
                    passwordVariable: 'AWS_SECRET_ACCESS_KEY'
                )]) {
                    sh """
                        terraform -chdir=${env.TF_DIR} apply -input=false jenkins.tfplan
                        rm -f ${env.TF_DIR}/jenkins.tfplan
                    """
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
                    sh """
                        echo "Running smoke test against ALB URL: ${env.DEPLOYED_URL}"
                        bash scripts/smoke.sh "${env.DEPLOYED_URL}" "${env.GIT_SHA}"
                    """
                }
            }
        }
    }

    post {
        always {
            archiveArtifacts artifacts: 'test-results.xml', allowEmptyArchive: true
            cleanWs deleteDirs: true, notFailBuild: true
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
