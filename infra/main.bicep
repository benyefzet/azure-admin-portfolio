// Kruszon environment - entry point deployed at subscription scope.
// Each week turns on one more module with a deploy* flag, so every commit stays deployable.
targetScope = 'subscription'

@description('Environment name used in resource names and tags.')
@allowed([
  'dev'
  'prod'
])
param env string = 'dev'

@description('Primary region. Why North Europe: docs/adr/0001-region-north-europe.md.')
param location string = 'northeurope'

@description('Your GitHub login or e-mail alias, stored in the owner tag.')
param owner string

@description('Week T5: CanNotDelete lock on the network resource group.')
param lockNetwork bool = false

@description('Week T3: storage account in its own resource group.')
param deployStorage bool = false

var tags = {
  project: 'kruszon'
  env: env
  owner: owner
  managedBy: 'bicep'
}

resource rgNetwork 'Microsoft.Resources/resourceGroups@2025-04-01' = {
  name: 'rg-kruszon-network-${env}'
  location: location
  tags: tags
}

resource rgData 'Microsoft.Resources/resourceGroups@2025-04-01' = if (deployStorage) {
  name: 'rg-kruszon-data-${env}'
  location: location
  tags: tags
}

module network 'modules/network.bicep' = {
  scope: rgNetwork
  name: 'network-${env}'
  params: {
    location: location
    env: env
    tags: tags
    enableDeleteLock: lockNetwork
  }
}

module storage 'modules/storage.bicep' = if (deployStorage) {
  scope: rgData
  name: 'storage-${env}'
  params: {
    location: location
    env: env
    tags: tags
  }
}

// Week T7: add "param deployCompute bool = false", a resource group and
// "module compute 'modules/compute.bicep' = if (deployCompute) { ... }" - the same pattern as storage.

output networkResourceGroupName string = rgNetwork.name
output hubVnetId string = network.outputs.hubVnetId
output webSubnetId string = network.outputs.webSubnetId
