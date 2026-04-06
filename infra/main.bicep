targetScope = 'resourceGroup'

// ---------------------------------------------------------------------------
// Parameters
// ---------------------------------------------------------------------------

@description('Azure region for all resources.')
param location string = 'eastus2'

@description('Short environment name used in resource names.')
@maxLength(8)
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
// Variables
// ---------------------------------------------------------------------------

var uniqueSuffix = take(uniqueString(resourceGroup().id), 6)

var kvName = 'kv-${take(projectName, 8)}-${take(environment, 3)}-${uniqueSuffix}'
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
  params: {
    logAnalyticsName: logName
    appInsightsName: appiName
    location: location
    tags: tags
  }
}

module network 'modules/network.bicep' = {
  name: 'network-deploy'
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
  params: {
    name: stName
    location: location
    tags: tags
    logAnalyticsWorkspaceName: logName
    privateEndpointSubnetId: network.outputs.privateEndpointSubnetId
    vnetId: network.outputs.vnetId
  }
}

module logicApp 'modules/logicapp.bicep' = {
  name: 'logicapp-deploy'
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
    storageAccountResourceId: storage.outputs.resourceId
  }
}

// ---------------------------------------------------------------------------
// Outputs (consumed by azd)
// ---------------------------------------------------------------------------

@description('App Service default hostname.')
output AZURE_APP_SERVICE_URL string = 'https://${appService.outputs.defaultHostname}'

@description('Storage account name.')
output STORAGE_ACCOUNT_NAME string = stName

@description('Application Insights connection string.')
output APPLICATIONINSIGHTS_CONNECTION_STRING string = monitoring.outputs.appInsightsConnectionString

@description('Logic App HTTP trigger URL (SAS-protected).')
output LOGIC_APP_URL string = logicApp.outputs.triggerUrl
