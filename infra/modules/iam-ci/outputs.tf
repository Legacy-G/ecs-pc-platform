output "iam_user_name" {
  description = "Name of the Jenkins CI IAM user (access keys are created out-of-band via CLI script)."
  value       = aws_iam_user.jenkins_ci.name
}

output "iam_user_arn" {
  description = "ARN of the Jenkins CI IAM user."
  value       = aws_iam_user.jenkins_ci.arn
}

output "permissions_boundary_arn" {
  description = "ARN of the IAM permissions boundary attached to the Jenkins CI user."
  value       = aws_iam_policy.permissions_boundary.arn
}
