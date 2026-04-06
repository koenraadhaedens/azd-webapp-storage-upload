// ---------------------------------------------------------------------------
// monitoring.bicep — Log Analytics Workspace + Application Insights
// ---------------------------------------------------------------------------

@description('Log Analytics Workspace name.')
param logAnalyticsName string

@description('Application Insights resource name.')
param appInsightsName string

@description('Azure region.')
param location string

@description('Resource tags.')
param tags object

// ---------------------------------------------------------------------------
// Log Analytics Workspace (AVM)
// ---------------------------------------------------------------------------

module logAnalytics 'br/public:avm/res/operational-insights/workspace:0.9.0' = {
  name: '${logAnalyticsName}-deploy'
  params: {
    name: logAnalyticsName
    location: location
    tags: tags
    skuName: 'PerGB2018'
    dataRetention: 30
  }
}

// ---------------------------------------------------------------------------
// Application Insights (AVM)
// ---------------------------------------------------------------------------

module appInsights 'br/public:avm/res/insights/component:0.4.0' = {
  name: '${appInsightsName}-deploy'
  params: {
    name: appInsightsName
    location: location
    tags: tags
    workspaceResourceId: logAnalytics.outputs.resourceId
    kind: 'web'
    applicationType: 'web'
  }
}

// ---------------------------------------------------------------------------
// Outputs
// ---------------------------------------------------------------------------

@description('Resource ID of the Log Analytics Workspace.')
output resourceId string = logAnalytics.outputs.resourceId

@description('Name of the Log Analytics Workspace.')
output resourceName string = logAnalytics.outputs.name

@description('Application Insights connection string.')
output appInsightsConnectionString string = appInsights.outputs.connectionString

@description('Application Insights instrumentation key.')
output appInsightsInstrumentationKey string = appInsights.outputs.instrumentationKey
