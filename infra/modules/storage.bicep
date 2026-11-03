// Storage for Kruszon - starter module. You extend it in T3 (account settings), T5 (private endpoint) and T6 (data).

@description('Region of the storage account.')
param location string

@description('Environment name used in resource names, e.g. dev.')
param env string

@description('Tags applied to every resource.')
param tags object

@description('Redundancy. Exam: know what LRS, ZRS, GRS, RA-GRS and GZRS protect against and what each costs.')
@allowed([
  'Standard_LRS'
  'Standard_ZRS'
  'Standard_GRS'
  'Standard_RAGRS'
  'Standard_GZRS'
])
param skuName string = 'Standard_LRS'

// Names: 3-24 lowercase letters and digits, unique across Azure. uniqueString() is stable for this resource group.
var storageAccountName = take('stkruszon${env}${uniqueString(resourceGroup().id)}', 24)

resource storageAccount 'Microsoft.Storage/storageAccounts@2025-06-01' = {
  name: storageAccountName
  location: location
  tags: tags
  kind: 'StorageV2'
  sku: {
    name: skuName
  }
  properties: {
    accessTier: 'Hot'
    minimumTlsVersion: 'TLS1_2'
    supportsHttpsTrafficOnly: true
    allowBlobPublicAccess: false
    // TODO (T6): set to false when every client uses Microsoft Entra ID or a user delegation SAS.
    allowSharedKeyAccess: true
    // TODO (T5): 'Disabled' once the private endpoint and its DNS zone work.
    publicNetworkAccess: 'Enabled'
    networkAcls: {
      // TODO (T6): defaultAction 'Deny' + virtualNetworkRules for snet-web (service endpoint Microsoft.Storage).
      defaultAction: 'Allow'
      bypass: 'AzureServices'
    }
    encryption: {
      // Microsoft-managed keys. Exam: customer-managed keys need Key Vault and a managed identity.
      keySource: 'Microsoft.Storage'
      services: {
        blob: {
          enabled: true
          keyType: 'Account'
        }
        file: {
          enabled: true
          keyType: 'Account'
        }
      }
    }
  }
}

resource blobService 'Microsoft.Storage/storageAccounts/blobServices@2025-06-01' = {
  parent: storageAccount
  name: 'default'
  properties: {
    deleteRetentionPolicy: {
      enabled: true
      days: 7
    }
    containerDeleteRetentionPolicy: {
      enabled: true
      days: 7
    }
    // TODO (T6): isVersioningEnabled and changeFeed (object replication needs both on the source account).
  }
}

resource ordersContainer 'Microsoft.Storage/storageAccounts/blobServices/containers@2025-06-01' = {
  parent: blobService
  name: 'orders'
  properties: {
    publicAccess: 'None'
  }
}

// TODO (T6): file share 'documents' (fileServices + shares) with share soft delete; snapshot it from the portal.
// TODO (T6): lifecycle management (managementPolicies): orders older than 30 days -> Cool, older than 180 days -> Archive.
// TODO (T5): private endpoint for the 'blob' sub-resource in snet-pe (pass network.outputs.privateEndpointSubnetId).

output storageAccountName string = storageAccount.name
output storageAccountId string = storageAccount.id
