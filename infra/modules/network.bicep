// ---------------------------------------------------------------------------
// network.bicep — VNet, subnets, NSG, Private DNS Zone
// ---------------------------------------------------------------------------

@description('Virtual network name.')
param vnetName string

@description('Azure region.')
param location string

@description('Resource tags.')
param tags object

@description('Log Analytics workspace name for diagnostics.')
param logAnalyticsWorkspaceName string

// ---------------------------------------------------------------------------
// NSG for private endpoint subnet (minimal rules for demo)
// ---------------------------------------------------------------------------

resource nsgPrivateEp 'Microsoft.Network/networkSecurityGroups@2024-01-01' = {
  name: 'nsg-privateep-${vnetName}'
  location: location
  tags: tags
  properties: {
    securityRules: []
  }
}

// ---------------------------------------------------------------------------
// Virtual Network (AVM)
// ---------------------------------------------------------------------------

module vnet 'br/public:avm/res/network/virtual-network:0.5.0' = {
  name: '${vnetName}-deploy'
  params: {
    name: vnetName
    location: location
    tags: tags
    addressPrefixes: ['10.0.0.0/16']
    subnets: [
      {
        name: 'snet-appservice-dev'
        addressPrefix: '10.0.1.0/24'
        delegation: 'Microsoft.Web/serverFarms'
        serviceEndpoints: []
      }
      {
        name: 'snet-privateep-dev'
        addressPrefix: '10.0.2.0/24'
        networkSecurityGroupResourceId: nsgPrivateEp.id
        privateEndpointNetworkPolicies: 'Disabled'
      }
    ]
  }
}

// ---------------------------------------------------------------------------
// Private DNS Zone for Blob Storage
// ---------------------------------------------------------------------------

resource privateDnsZone 'Microsoft.Network/privateDnsZones@2020-06-01' = {
  name: 'privatelink.blob.core.windows.net'
  location: 'global'
  tags: tags
}

resource dnsZoneVnetLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = {
  parent: privateDnsZone
  name: 'link-${vnetName}'
  location: 'global'
  tags: tags
  properties: {
    virtualNetwork: { id: vnet.outputs.resourceId }
    registrationEnabled: false
  }
}

// ---------------------------------------------------------------------------
// Diagnostic settings for VNet
// ---------------------------------------------------------------------------

resource logWorkspace 'Microsoft.OperationalInsights/workspaces@2023-09-01' existing = {
  name: logAnalyticsWorkspaceName
}

resource vnetDiag 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: 'diag-${vnetName}'
  scope: nsgPrivateEp
  properties: {
    workspaceId: logWorkspace.id
    logs: [
      { categoryGroup: 'allLogs', enabled: true }
    ]
  }
}

// ---------------------------------------------------------------------------
// Outputs
// ---------------------------------------------------------------------------

@description('Resource ID of the VNet.')
output vnetId string = vnet.outputs.resourceId

@description('Name of the VNet.')
output vnetName string = vnet.outputs.name

@description('Resource ID of the App Service integration subnet.')
output appServiceSubnetId string = vnet.outputs.subnetResourceIds[0]

@description('Resource ID of the private endpoints subnet.')
output privateEndpointSubnetId string = vnet.outputs.subnetResourceIds[1]

@description('Resource ID of the blob private DNS zone.')
output blobPrivateDnsZoneId string = privateDnsZone.id
