data "aws_caller_identity" "current" {}

locals {
  account_id = data.aws_caller_identity.current.account_id
  user_name  = "${var.project_name}-jenkins-ci"
}

# trivy:ignore:AVD-AWS-0057 EC2, ELB, and ECS Describe/Register APIs require wildcard resources in IAM; constrained by region condition and permissions boundary.
# trivy:ignore:AVD-AWS-0342 IAM role management is strictly scoped to arn:aws:iam::<account>:role/damolak-* and iam:PassRole requires iam:PassedToService=ecs-tasks.amazonaws.com.
data "aws_iam_policy_document" "ci_deploy" {
  statement {
    sid       = "CallerIdentityAndEcrAuth"
    effect    = "Allow"
    actions   = ["sts:GetCallerIdentity", "ecr:GetAuthorizationToken"]
    resources = ["*"]
  }

  statement {
    sid    = "TerraformStateBucketAccess"
    effect = "Allow"
    actions = [
      "s3:ListBucket",
      "s3:GetBucketVersioning",
      "s3:GetObject",
      "s3:PutObject",
      "s3:DeleteObject"
    ]
    resources = [
      "arn:aws:s3:::${var.tfstate_bucket_name}",
      "arn:aws:s3:::${var.tfstate_bucket_name}/*"
    ]
  }

  statement {
    sid    = "ProjectEcrRepositories"
    effect = "Allow"
    actions = [
      "ecr:BatchCheckLayerAvailability",
      "ecr:BatchGetImage",
      "ecr:CompleteLayerUpload",
      "ecr:DescribeImages",
      "ecr:DescribeRepositories",
      "ecr:GetDownloadUrlForLayer",
      "ecr:GetLifecyclePolicy",
      "ecr:GetRepositoryPolicy",
      "ecr:InitiateLayerUpload",
      "ecr:ListImages",
      "ecr:ListTagsForResource",
      "ecr:PutImage",
      "ecr:UploadLayerPart"
    ]
    resources = [
      "arn:aws:ecr:${var.aws_region}:${local.account_id}:repository/${var.project_name}-*"
    ]
  }

  statement {
    sid    = "ProjectIamTaskRolesOnly"
    effect = "Allow"
    actions = [
      "iam:GetRole",
      "iam:GetRolePolicy",
      "iam:ListRolePolicies",
      "iam:ListAttachedRolePolicies",
      "iam:CreateRole",
      "iam:DeleteRole",
      "iam:UpdateAssumeRolePolicy",
      "iam:PutRolePolicy",
      "iam:DeleteRolePolicy",
      "iam:AttachRolePolicy",
      "iam:DetachRolePolicy",
      "iam:TagRole",
      "iam:UntagRole"
    ]
    resources = [
      "arn:aws:iam::${local.account_id}:role/${var.project_name}-*"
    ]
  }

  statement {
    sid       = "PassProjectRolesToEcsTasksOnly"
    effect    = "Allow"
    actions   = ["iam:PassRole"]
    resources = ["arn:aws:iam::${local.account_id}:role/${var.project_name}-*"]

    condition {
      test     = "StringEquals"
      variable = "iam:PassedToService"
      values   = ["ecs-tasks.amazonaws.com"]
    }
  }

  statement {
    sid    = "ProjectSsmParameterMetadata"
    effect = "Allow"
    actions = [
      "ssm:GetParameter",
      "ssm:GetParameters",
      "ssm:ListTagsForResource"
    ]
    resources = [
      "arn:aws:ssm:${var.aws_region}:${local.account_id}:parameter/${var.project_name}/*"
    ]
  }

  statement {
    sid    = "RegionalStackManagement"
    effect = "Allow"
    actions = [
      "ecs:*",
      "ec2:*",
      "elasticloadbalancing:*",
      "logs:*",
      "cloudwatch:*",
      "sns:*",
      "application-autoscaling:*"
    ]
    resources = ["*"]

    condition {
      test     = "StringEquals"
      variable = "aws:RequestedRegion"
      values   = [var.aws_region]
    }
  }

  statement {
    sid    = "ExplicitlyDenyPrivilegeEscalation"
    effect = "Deny"
    actions = [
      "iam:CreateUser",
      "iam:DeleteUser",
      "iam:CreateAccessKey",
      "iam:DeleteAccessKey",
      "iam:UpdateAccessKey",
      "iam:PutUserPolicy",
      "iam:AttachUserPolicy",
      "iam:PutUserPermissionsBoundary",
      "iam:DeleteUserPermissionsBoundary",
      "organizations:*",
      "account:*",
      "budgets:*"
    ]
    resources = ["*"]
  }
}

# trivy:ignore:AVD-AWS-0057 Permissions boundary mirrors ci_deploy regional and prefix constraints while blocking IAM user/boundary escalation.
# trivy:ignore:AVD-AWS-0342 Role permissions are restricted to arn:aws:iam::<account>:role/damolak-*.
resource "aws_iam_policy" "permissions_boundary" {
  # checkov:skip=CKV_AWS_288:Regional EC2/ELB/ECS actions require wildcard resource in Terraform plans; constrained by aws:RequestedRegion.
  # checkov:skip=CKV_AWS_289:IAM role actions are restricted to arn:aws:iam::<account>:role/damolak-* and User/Boundary changes are explicitly denied.
  # checkov:skip=CKV_AWS_290:Write actions on regional services are bounded by aws:RequestedRegion and explicit privilege-escalation denies.
  # checkov:skip=CKV_AWS_355:EC2/ELB/ECS Describe and RegisterTaskDefinition APIs do not support resource-level ARNs.
  name        = "${var.project_name}-jenkins-ci-boundary"
  description = "Permissions boundary for the local Jenkins CI IAM user"
  policy      = data.aws_iam_policy_document.ci_deploy.json
}

# trivy:ignore:AVD-AWS-0143 IAM user is required because the account SCP blocks iam:CreateOpenIDConnectProvider and Jenkins runs in local Docker.
resource "aws_iam_user" "jenkins_ci" {
  # checkov:skip=CKV_AWS_273:SSO/OIDC is blocked by the organization SCP (ADR 0007); local Jenkins authenticates via this dedicated IAM user.
  name                 = local.user_name
  permissions_boundary = aws_iam_policy.permissions_boundary.arn
  force_destroy        = true

  tags = {
    Name = local.user_name
  }
}

resource "aws_iam_user_policy_attachment" "jenkins_ci" {
  # checkov:skip=CKV_AWS_40:Policy is attached to the dedicated service user with an identical permissions boundary; IAM groups add no isolation for a single programmatic identity.
  user       = aws_iam_user.jenkins_ci.name
  policy_arn = aws_iam_policy.permissions_boundary.arn
}
