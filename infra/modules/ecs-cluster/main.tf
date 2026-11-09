locals {
  name_prefix = "${var.project_name}-${var.environment}"
}

# Container Insights is disabled on purpose. It bills CloudWatch custom metrics and
# log ingestion per task, which is not worth the cost on a USD 40 budget. The free
# AWS/ECS CPU and memory metrics and the ALB metrics cover the alarms in this repo.
resource "aws_ecs_cluster" "this" {
  name = "${local.name_prefix}-cluster"

  setting {
    name  = "containerInsights"
    value = "disabled"
  }

  tags = {
    Name = "${local.name_prefix}-cluster"
  }
}
