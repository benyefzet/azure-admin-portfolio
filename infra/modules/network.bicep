// Hub-and-spoke network for Kruszon - the exemplar module of this repository.
//
// Study every line before you extend it: AZ-104 asks you to interpret and modify Bicep files exactly like this one.
// Address plan (no overlaps, so the spokes can be peered or routed later):
//   hub        10.0.0.0/16   shared services (Bastion, NVA, DNS resolver in a real company)
//   app spoke  10.1.0.0/16   web tier (load balancer + VM scale set), App Service VNet integration
//   data spoke 10.2.0.0/16   private endpoints for storage

@description('Region of all network resources.')
param location string

@description('Environment name used in resource names, e.g. dev.')
param env string

@description('Tags applied to every resource.')
param tags object

@description('Adds a CanNotDelete lock to the resource group. scripts/destroy.sh removes locks before deleting.')
param enableDeleteLock bool = false

// ---------------------------------------------------------------------------
// Security: application security groups group VMs by role, NSG rules target the role instead of IP addresses.
// ---------------------------------------------------------------------------

resource asgWeb 'Microsoft.Network/applicationSecurityGroups@2025-05-01' = {
  name: 'asg-kruszon-web-${env}'
  location: location
  tags: tags
}

resource nsgWeb 'Microsoft.Network/networkSecurityGroups@2025-05-01' = {
  name: 'nsg-kruszon-web-${env}'
  location: location
  tags: tags
  properties: {
    securityRules: [
      {
        name: 'Allow-HTTP-Internet-To-Web'
        properties: {
          description: 'Customers reach the web tier on port 80 (TLS terminates in front of it later).'
          priority: 100
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourceAddressPrefix: 'Internet'
          sourcePortRange: '*'
          destinationApplicationSecurityGroups: [
            {
              id: asgWeb.id
            }
          ]
          destinationPortRange: '80'
        }
      }
      // TODO (T4): allow SSH (22) to the web ASG only from the hub address space, then verify it in
      //            Network Watcher > Effective security rules. Default rules still deny everything else from the Internet.
    ]
  }
}

// One NSG may be associated with many subnets in the same region; it starts with the default rules only.
resource nsgDefault 'Microsoft.Network/networkSecurityGroups@2025-05-01' = {
  name: 'nsg-kruszon-default-${env}'
  location: location
  tags: tags
  properties: {
    securityRules: []
  }
}

// ---------------------------------------------------------------------------
// Virtual networks
// ---------------------------------------------------------------------------

resource hubVnet 'Microsoft.Network/virtualNetworks@2025-05-01' = {
  name: 'vnet-kruszon-hub-${env}'
  location: location
  tags: tags
  properties: {
    addressSpace: {
      addressPrefixes: [
        '10.0.0.0/16'
      ]
    }
    subnets: [
      {
        name: 'snet-shared'
        properties: {
          addressPrefix: '10.0.1.0/24'
          networkSecurityGroup: {
            id: nsgDefault.id
          }
        }
      }
      {
        // Bastion Basic/Standard/Premium require exactly this name and at least a /26.
        // The free Developer SKU needs no subnet, but it cannot reach peered networks (see docs/adr).
        name: 'AzureBastionSubnet'
        properties: {
          addressPrefix: '10.0.255.0/26'
        }
      }
    ]
  }
}

// Spokes are described as data and created in a loop - add a third spoke by adding an object here.
var spokes = [
  {
    name: 'vnet-kruszon-app-${env}'
    addressPrefix: '10.1.0.0/16'
    subnets: [
      {
        name: 'snet-web'
        properties: {
          addressPrefix: '10.1.1.0/24'
          networkSecurityGroup: {
            id: nsgWeb.id
          }
        }
      }
      {
        // Delegated subnet for App Service regional VNet integration (outbound traffic from the web app into the VNet).
        name: 'snet-appsvc'
        properties: {
          addressPrefix: '10.1.2.0/24'
          networkSecurityGroup: {
            id: nsgDefault.id
          }
          delegations: [
            {
              name: 'appservice'
              properties: {
                serviceName: 'Microsoft.Web/serverFarms'
              }
            }
          ]
        }
      }
    ]
  }
  {
    name: 'vnet-kruszon-data-${env}'
    addressPrefix: '10.2.0.0/16'
    subnets: [
      {
        name: 'snet-pe'
        properties: {
          addressPrefix: '10.2.1.0/24'
          networkSecurityGroup: {
            id: nsgDefault.id
          }
        }
      }
    ]
  }
]

resource spokeVnets 'Microsoft.Network/virtualNetworks@2025-05-01' = [
  for spoke in spokes: {
    name: spoke.name
    location: location
    tags: tags
    properties: {
      addressSpace: {
        addressPrefixes: [
          spoke.addressPrefix
        ]
      }
      subnets: spoke.subnets
    }
  }
]

// ---------------------------------------------------------------------------
// Peering: every link needs a pair (hub -> spoke and spoke -> hub).
// Peering is NOT transitive: the app spoke cannot reach the data spoke through the hub on its own.
// TODO (T5): fix that with a route table (UDR) pointing 10.2.0.0/16 to an NVA in snet-shared,
//            or with a direct app <-> data peering - and log the before/after in docs/troubleshooting.md.
// ---------------------------------------------------------------------------

@batchSize(1) // peerings on the same hub VNet are created one at a time to avoid "AnotherOperationInProgress"
resource hubToSpoke 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2025-05-01' = [
  for (spoke, i) in spokes: {
    parent: hubVnet
    name: 'peer-hub-to-${spoke.name}'
    properties: {
      remoteVirtualNetwork: {
        id: spokeVnets[i].id
      }
      allowVirtualNetworkAccess: true
      allowForwardedTraffic: true
      allowGatewayTransit: false
      useRemoteGateways: false
    }
  }
]

resource spokeToHub 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2025-05-01' = [
  for (spoke, i) in spokes: {
    parent: spokeVnets[i]
    name: 'peer-${spoke.name}-to-hub'
    properties: {
      remoteVirtualNetwork: {
        id: hubVnet.id
      }
      allowVirtualNetworkAccess: true
      allowForwardedTraffic: true // lets traffic forwarded by an NVA in the hub enter the spoke
      allowGatewayTransit: false
      useRemoteGateways: false
    }
  }
]

// TODO (T5): public Standard load balancer for snet-web (frontend IP, backend pool, health probe, rule on port 80).
// TODO (T5): private DNS zone privatelink.blob.core.windows.net linked to the hub and both spokes.

// ---------------------------------------------------------------------------
// Protection: a lock overrides RBAC - even an Owner cannot delete the group until the lock is removed.
// ---------------------------------------------------------------------------

resource deleteLock 'Microsoft.Authorization/locks@2020-05-01' = if (enableDeleteLock) {
  name: 'lock-kruszon-network-cannotdelete'
  properties: {
    level: 'CanNotDelete'
    notes: 'Protects the hub-and-spoke network. scripts/destroy.sh removes it before deleting the group.'
  }
}

output hubVnetId string = hubVnet.id
output spokeVnetIds array = [for (spoke, i) in spokes: spokeVnets[i].id]
output webSubnetId string = resourceId('Microsoft.Network/virtualNetworks/subnets', spokes[0].name, 'snet-web')
output appServiceSubnetId string = resourceId('Microsoft.Network/virtualNetworks/subnets', spokes[0].name, 'snet-appsvc')
output privateEndpointSubnetId string = resourceId('Microsoft.Network/virtualNetworks/subnets', spokes[1].name, 'snet-pe')
output webAsgId string = asgWeb.id
