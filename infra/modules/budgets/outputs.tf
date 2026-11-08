output "budget_id" {
  description = "ID of the monthly AWS Cost Budget."
  value       = aws_budgets_budget.monthly.id
}

output "budget_name" {
  description = "Name of the monthly AWS Cost Budget."
  value       = aws_budgets_budget.monthly.name
}
