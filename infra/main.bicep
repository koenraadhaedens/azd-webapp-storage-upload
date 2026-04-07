targetScope = 'subscription'

// ---------------------------------------------------------------------------
// Parameters
// ---------------------------------------------------------------------------

@description('Azure region for all resources.')
param location string = 'eastus2'

@description('Short environment name used in resource names.')
param environment string = 'dev'

@description('Short project name used in resource names.')
@maxLength(12)
param projectName string = 'secureupload'

@description('Principal ID of the deploying user — populated automatically by azd.')
param principalId string

@description('Resource tags applied to all resources.')
param tags object = {
  Environment: environment
  ManagedBy: 'Bicep'
  Project: projectName
  SecurityControl: 'Ignore'
}

// ---------------------------------------------------------------------------
// Resource Group
// ---------------------------------------------------------------------------

var rgName = 'rg-${environment}'

resource rg 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: rgName
  location: location
  tags: tags
}

// ---------------------------------------------------------------------------
// Variables
// ---------------------------------------------------------------------------

var uniqueSuffix = take(uniqueString(rg.id), 6)

var stName = 'st${take(replace(projectName, '-', ''), 8)}${take(environment, 3)}${uniqueSuffix}'
var aspName = 'asp-${projectName}-${environment}'
var appName = 'app-${projectName}-${environment}-${uniqueSuffix}'
var logicName = 'logic-${projectName}-${environment}-${uniqueSuffix}'
var vnetName = 'vnet-${projectName}-${environment}'
var logName = 'log-${projectName}-${environment}'
var appiName = 'appi-${projectName}-${environment}'

// ---------------------------------------------------------------------------
// Modules
// ---------------------------------------------------------------------------

module monitoring 'modules/monitoring.bicep' = {
  name: 'monitoring-deploy'
  scope: rg
  params: {
    logAnalyticsName: logName
    appInsightsName: appiName
    location: location
    tags: tags
  }
}

module network 'modules/network.bicep' = {
  name: 'network-deploy'
  scope: rg
  params: {
    vnetName: vnetName
    location: location
    tags: tags
    logAnalyticsWorkspaceName: logName
  }
  dependsOn: [monitoring]
}

module storage 'modules/storage.bicep' = {
  name: 'storage-deploy'
  scope: rg
  params: {
    name: stName
    location: location
    tags: tags
    logAnalyticsWorkspaceName: logName
    privateEndpointSubnetId: network.outputs.privateEndpointSubnetId
    blobPrivateDnsZoneId: network.outputs.blobPrivateDnsZoneId
  }
}

module logicApp 'modules/logicapp.bicep' = {
  name: 'logicapp-deploy'
  scope: rg
  params: {
    name: logicName
    location: location
    tags: tags
    logAnalyticsWorkspaceName: logName
  }
  dependsOn: [monitoring]
}

module appService 'modules/appservice.bicep' = {
  name: 'appservice-deploy'
  scope: rg
  params: {
    planName: aspName
    appName: appName
    location: location
    tags: tags
    logAnalyticsWorkspaceName: logName
    appInsightsConnectionString: monitoring.outputs.appInsightsConnectionString
    storageAccountName: stName
    logicAppUrl: logicApp.outputs.triggerUrl
    vnetIntegrationSubnetId: network.outputs.appServiceSubnetId
    principalId: principalId
  }
}

// ---------------------------------------------------------------------------
// Outputs (consumed by azd)
// ---------------------------------------------------------------------------

@description('Resource group name — consumed by azd.')
output AZURE_RESOURCE_GROUP string = rg.name

@description('App Service default hostname.')
output AZURE_APP_SERVICE_URL string = 'https://${appService.outputs.defaultHostname}'

@description('Storage account name.')
output STORAGE_ACCOUNT_NAME string = stName

@description('Application Insights connection string.')
output APPLICATIONINSIGHTS_CONNECTION_STRING string = monitoring.outputs.appInsightsConnectionString

@description('Logic App HTTP trigger URL (SAS-protected).')
output LOGIC_APP_URL string = logicApp.outputs.triggerUrl
