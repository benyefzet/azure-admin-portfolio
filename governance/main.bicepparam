using 'main.bicep'

// The budget alert recipient is not stored in the repository.
// Set it before deploying: $env:KRUSZON_BUDGET_EMAIL = "you@example.com"
param budgetContactEmails = [
  readEnvironmentVariable('KRUSZON_BUDGET_EMAIL', 'budget-alerts@example.invalid')
]
param budgetAmount = 25
param requiredTagEnforcement = 'DoNotEnforce'
param deployCustomRole = true
