// ---------------------------------------------------------------------------
// storage.bicep — Storage Account, Private Endpoint, DNS Zone Group
// ---------------------------------------------------------------------------

@description('Storage account name (max 24 chars, no hyphens).')
@maxLength(24)
param name string

@description('Azure region.')
param location string

@description('Resource tags.')
param tags object

@description('Log Analytics workspace name for diagnostics.')
param logAnalyticsWorkspaceName string

@description('Resource ID of the subnet for the private endpoint.')
param privateEndpointSubnetId string

@description('Resource ID of the blob private DNS zone (created by network module).')
param blobPrivateDnsZoneId string

// ---------------------------------------------------------------------------
// Storage Account (AVM)
// ---------------------------------------------------------------------------

module storageAccount 'br/public:avm/res/storage/storage-account:0.14.0' = {
  name: '${name}-deploy'
  params: {
    name: name
    location: location
    tags: tags
    kind: 'StorageV2'
    skuName: 'Standard_LRS'
    accessTier: 'Hot'
    supportsHttpsTrafficOnly: true
    minimumTlsVersion: 'TLS1_2'
    allowBlobPublicAccess: false
    allowSharedKeyAccess: false
    publicNetworkAccess: 'Disabled'
    networkAcls: {
      bypass: 'AzureServices'
      defaultAction: 'Deny'
    }
    blobServices: {
      containers: [
        {
          name: 'uploads'
          publicAccess: 'None'
        }
      ]
    }
    diagnosticSettings: [
      {
        workspaceResourceId: logWorkspace.id
        metricCategories: [{ category: 'AllMetrics', enabled: true }]
      }
    ]
  }
}

resource logWorkspace 'Microsoft.OperationalInsights/workspaces@2023-09-01' existing = {
  name: logAnalyticsWorkspaceName
}

// ---------------------------------------------------------------------------
// Private Endpoint — blob subresource
// ---------------------------------------------------------------------------

resource privateEndpoint 'Microsoft.Network/privateEndpoints@2024-01-01' = {
  name: 'pe-${name}-blob'
  location: location
  tags: tags
  properties: {
    subnet: { id: privateEndpointSubnetId }
    privateLinkServiceConnections: [
      {
        name: 'plsc-blob'
        properties: {
          privateLinkServiceId: storageAccount.outputs.resourceId
          groupIds: ['blob']
        }
      }
    ]
  }
}

resource privateDnsZoneGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2024-01-01' = {
  parent: privateEndpoint
  name: 'default'
  properties: {
    privateDnsZoneConfigs: [
      {
        name: 'blob-config'
        properties: { privateDnsZoneId: blobPrivateDnsZoneId }
      }
    ]
  }
}

// ---------------------------------------------------------------------------
// Outputs
// ---------------------------------------------------------------------------

@description('Resource ID of the storage account.')
output resourceId string = storageAccount.outputs.resourceId

@description('Name of the storage account.')
output resourceName string = storageAccount.outputs.name

@description('Principal ID of the storage account (empty — storage has no MI).')
output principalId string = ''
