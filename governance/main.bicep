// Guardrails for the Kruszon lab subscription: where resources may live, which VM sizes are allowed,
// how resource groups are tagged, who may operate VMs, and when spending triggers an alert.
// Deploy: az deployment sub create --location northeurope --parameters governance/main.bicepparam
targetScope = 'subscription'

@description('Regions where resources may be deployed. West Europe is the disaster-recovery region.')
param allowedLocations array = [
  'northeurope'
  'westeurope'
]

@description('Allowed VM sizes: free-account B-series plus the sizes used by the official AZ-104 labs, including the v6 and v7 fallbacks the labs name when v5 has no capacity.')
param allowedVmSizes array = [
  'Standard_B1s'
  'Standard_B2ats_v2'
  'Standard_B2pts_v2'
  'Standard_D2s_v5'
  'Standard_D2s_v6'
  'Standard_D2s_v7'
  'Standard_D4s_v5'
  'Standard_D4s_v6'
  'Standard_D4s_v7'
]

@description('Tag every resource group should carry; resources inherit it from their group.')
param requiredTagName string = 'env'

@description('Deny resource groups without the tag (Default) or only report them as non-compliant (DoNotEnforce). Portal labs that create groups on the fly fail when this is enforced.')
@allowed([
  'Default'
  'DoNotEnforce'
])
param requiredTagEnforcement string = 'DoNotEnforce'

@description('Creates the "Kruszon VM Operator" custom role. Set to false if you create it from roles/vm-operator.json with the CLI instead.')
param deployCustomRole bool = true

@description('Monthly budget in the billing currency of the subscription.')
param budgetAmount int = 25

@description('E-mail addresses that receive budget alerts.')
param budgetContactEmails array

@description('Budgets start on the first day of a month. If a redeploy rejects the date, pass the date of the first deployment.')
param budgetStartDate string = '${utcNow('yyyy-MM')}-01'

@description('Region that stores the managed identity of the policy assignment with the modify effect.')
param location string = deployment().location

// Built-in policy definition IDs (from github.com/Azure/azure-policy, built-in-policies/policyDefinitions).
var builtInPolicies = {
  allowedLocations: 'e56962a6-4747-49cd-b67b-bf8b01975c4c'
  allowedLocationsForResourceGroups: 'e765b5de-1225-4ba3-bd56-1ac6695af988'
  allowedVmSizes: 'cccc23c7-8427-4f53-ad12-b6a63eb452b3'
  requireTagOnResourceGroups: '96670d01-0a4d-4649-9c89-2d3abc0a5025'
  inheritTagFromResourceGroupIfMissing: 'ea3f2387-9b95-492a-a190-fcdc54f7b070'
}

var contributorRoleId = 'b24988ac-6180-42a0-ab88-20f7382dd24c'

// Deny effect: resources outside the list are rejected at deployment time ("global" resources are exempt).
resource allowedLocationsAssignment 'Microsoft.Authorization/policyAssignments@2025-03-01' = {
  name: 'kruszon-allowed-locations'
  properties: {
    displayName: 'Kruszon: allowed locations for resources'
    policyDefinitionId: tenantResourceId('Microsoft.Authorization/policyDefinitions', builtInPolicies.allowedLocations)
    parameters: {
      listOfAllowedLocations: {
        value: allowedLocations
      }
    }
  }
}

// The resource policy above does not cover resource groups - they need their own definition.
resource allowedRgLocationsAssignment 'Microsoft.Authorization/policyAssignments@2025-03-01' = {
  name: 'kruszon-allowed-rg-locations'
  properties: {
    displayName: 'Kruszon: allowed locations for resource groups'
    policyDefinitionId: tenantResourceId('Microsoft.Authorization/policyDefinitions', builtInPolicies.allowedLocationsForResourceGroups)
    parameters: {
      listOfAllowedLocations: {
        value: allowedLocations
      }
    }
  }
}

// Cost guardrail. This definition evaluates virtual machines only - scale sets are not covered.
resource allowedVmSizesAssignment 'Microsoft.Authorization/policyAssignments@2025-03-01' = {
  name: 'kruszon-allowed-vm-sizes'
  properties: {
    displayName: 'Kruszon: allowed virtual machine sizes'
    policyDefinitionId: tenantResourceId('Microsoft.Authorization/policyDefinitions', builtInPolicies.allowedVmSizes)
    parameters: {
      listOfAllowedSKUs: {
        value: allowedVmSizes
      }
    }
  }
}

resource requireTagOnRgsAssignment 'Microsoft.Authorization/policyAssignments@2025-03-01' = {
  name: 'kruszon-require-env-tag-on-rg'
  properties: {
    displayName: 'Kruszon: resource groups must have the ${requiredTagName} tag'
    policyDefinitionId: tenantResourceId('Microsoft.Authorization/policyDefinitions', builtInPolicies.requireTagOnResourceGroups)
    enforcementMode: requiredTagEnforcement
    parameters: {
      tagName: {
        value: requiredTagName
      }
    }
  }
}

// Modify effect: adds the tag to new or updated resources. Remediating existing resources needs a managed
// identity holding the role the definition lists (Contributor).
resource inheritTagAssignment 'Microsoft.Authorization/policyAssignments@2025-03-01' = {
  name: 'kruszon-inherit-env-tag'
  location: location
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    displayName: 'Kruszon: inherit the ${requiredTagName} tag from the resource group'
    policyDefinitionId: tenantResourceId('Microsoft.Authorization/policyDefinitions', builtInPolicies.inheritTagFromResourceGroupIfMissing)
    parameters: {
      tagName: {
        value: requiredTagName
      }
    }
  }
}

resource inheritTagRemediationRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(subscription().id, inheritTagAssignment.id, contributorRoleId)
  properties: {
    principalId: inheritTagAssignment.identity.principalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', contributorRoleId)
  }
}

// Least privilege: help-desk staff can start, restart and deallocate VMs, but not create, resize or delete them.
// powerOff is left out on purpose - a VM that is only stopped (not deallocated) is still billed for compute.
resource vmOperatorRole 'Microsoft.Authorization/roleDefinitions@2022-04-01' = if (deployCustomRole) {
  name: guid(subscription().id, 'kruszon-vm-operator')
  properties: {
    roleName: 'Kruszon VM Operator'
    description: 'Start, restart and deallocate virtual machines. Cannot create, resize or delete them.'
    type: 'CustomRole'
    permissions: [
      {
        actions: [
          'Microsoft.Compute/virtualMachines/read'
          'Microsoft.Compute/virtualMachines/instanceView/read'
          'Microsoft.Compute/virtualMachines/start/action'
          'Microsoft.Compute/virtualMachines/restart/action'
          'Microsoft.Compute/virtualMachines/deallocate/action'
          'Microsoft.Resources/subscriptions/resourceGroups/read'
        ]
        notActions: []
      }
    ]
    assignableScopes: [
      subscription().id
    ]
  }
}

// A budget only alerts - it never stops or deletes resources.
resource monthlyBudget 'Microsoft.Consumption/budgets@2026-06-01' = {
  name: 'budget-kruszon-monthly'
  properties: {
    category: 'Cost'
    amount: budgetAmount
    timeGrain: 'Monthly'
    timePeriod: {
      startDate: budgetStartDate
    }
    notifications: {
      actual50: {
        enabled: true
        operator: 'GreaterThanOrEqualTo'
        threshold: 50
        thresholdType: 'Actual'
        contactEmails: budgetContactEmails
      }
      actual80: {
        enabled: true
        operator: 'GreaterThanOrEqualTo'
        threshold: 80
        thresholdType: 'Actual'
        contactEmails: budgetContactEmails
      }
      forecast100: {
        enabled: true
        operator: 'GreaterThanOrEqualTo'
        threshold: 100
        thresholdType: 'Forecasted'
        contactEmails: budgetContactEmails
      }
    }
  }
}

output vmOperatorRoleId string = deployCustomRole ? vmOperatorRole.id : ''
