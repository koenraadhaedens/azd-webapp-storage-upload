// ---------------------------------------------------------------------------
// appservice.bicep — App Service Plan + App Service + RBAC + App Settings
// ---------------------------------------------------------------------------

@description('App Service Plan name.')
param planName string

@description('App Service name.')
param appName string

@description('Azure region.')
param location string

@description('Resource tags.')
param tags object

@description('Log Analytics workspace name for diagnostics.')
param logAnalyticsWorkspaceName string

@description('Application Insights connection string.')
param appInsightsConnectionString string

@description('Storage account name for the uploads container.')
param storageAccountName string

@description('Logic App HTTP trigger SAS URL.')
param logicAppUrl string

@description('Resource ID of the VNet integration subnet.')
param vnetIntegrationSubnetId string

@description('Principal ID of the deploying user (for data plane role assignment).')
param principalId string

// ---------------------------------------------------------------------------
// Role Definition IDs
// ---------------------------------------------------------------------------

var storageBlobDataContributorRoleId = 'ba92f5b4-2d11-453d-a403-e96b0029c9fe'

// ---------------------------------------------------------------------------
// App Service Plan (AVM)
// ---------------------------------------------------------------------------

module appServicePlan 'br/public:avm/res/web/serverfarm:0.4.0' = {
  name: '${planName}-deploy'
  params: {
    name: planName
    location: location
    tags: tags
    skuName: 'B2'
    skuCapacity: 1
    reserved: true
  }
}

// ---------------------------------------------------------------------------
// App Service (AVM)
// ---------------------------------------------------------------------------

module appService 'br/public:avm/res/web/site:0.12.0' = {
  name: '${appName}-deploy'
  params: {
    name: appName
    location: location
    tags: union(tags, { 'azd-service-name': 'web' })
    kind: 'app,linux'
    serverFarmResourceId: appServicePlan.outputs.resourceId
    managedIdentities: {
      systemAssigned: true
    }
    siteConfig: {
      linuxFxVersion: 'DOTNETCORE|9.0'
      alwaysOn: true
      minTlsVersion: '1.2'
      ftpsState: 'Disabled'
      http20Enabled: true
      vnetRouteAllEnabled: true
    }
    httpsOnly: true
    virtualNetworkSubnetId: vnetIntegrationSubnetId
    appSettingsKeyValuePairs: {
      APPLICATIONINSIGHTS_CONNECTION_STRING: appInsightsConnectionString
      STORAGE_ACCOUNT_NAME: storageAccountName
      LOGIC_APP_URL: logicAppUrl
      ASPNETCORE_ENVIRONMENT: 'Production'
    }
    diagnosticSettings: [
      {
        workspaceResourceId: logWorkspace.id
        logCategoriesAndGroups: [{ categoryGroup: 'allLogs', enabled: true }]
        metricCategories: [{ category: 'AllMetrics', enabled: true }]
      }
    ]
  }
}

resource logWorkspace 'Microsoft.OperationalInsights/workspaces@2023-09-01' existing = {
  name: logAnalyticsWorkspaceName
}

// ---------------------------------------------------------------------------
// Storage Account reference for RBAC scoping
// ---------------------------------------------------------------------------

resource storageAccount 'Microsoft.Storage/storageAccounts@2023-05-01' existing = {
  name: storageAccountName
}

// ---------------------------------------------------------------------------
// RBAC: App Service Managed Identity → Storage Blob Data Contributor
// ---------------------------------------------------------------------------

resource appServiceStorageRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(storageAccount.id, appName, storageBlobDataContributorRoleId)
  scope: storageAccount
  properties: {
    roleDefinitionId: subscriptionResourceId(
      'Microsoft.Authorization/roleDefinitions',
      storageBlobDataContributorRoleId
    )
    principalId: appService.outputs.systemAssignedMIPrincipalId
    principalType: 'ServicePrincipal'
  }
}

// ---------------------------------------------------------------------------
// RBAC: Deploying User → Storage Blob Data Contributor (for portal access)
// ---------------------------------------------------------------------------

resource deployerStorageRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (!empty(principalId)) {
  name: guid(storageAccount.id, principalId, storageBlobDataContributorRoleId)
  scope: storageAccount
  properties: {
    roleDefinitionId: subscriptionResourceId(
      'Microsoft.Authorization/roleDefinitions',
      storageBlobDataContributorRoleId
    )
    principalId: principalId
    principalType: 'User'
  }
}

// ---------------------------------------------------------------------------
// Outputs
// ---------------------------------------------------------------------------

@description('Resource ID of the App Service.')
output resourceId string = appService.outputs.resourceId

@description('Name of the App Service.')
output resourceName string = appService.outputs.name

@description('Default hostname of the App Service.')
output defaultHostname string = appService.outputs.defaultHostname

@description('System-assigned managed identity principal ID.')
output principalId string = appService.outputs.systemAssignedMIPrincipalId
