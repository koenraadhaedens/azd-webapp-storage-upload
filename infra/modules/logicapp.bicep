// ---------------------------------------------------------------------------
// logicapp.bicep — Logic App Consumption + HTTP Trigger Workflow
// ---------------------------------------------------------------------------

@description('Logic App resource name.')
param name string

@description('Azure region.')
param location string

@description('Resource tags.')
param tags object

@description('Log Analytics workspace name for diagnostics.')
param logAnalyticsWorkspaceName string

// ---------------------------------------------------------------------------
// Logic App (Consumption) — raw Bicep (no AVM module for Consumption workflows)
// ---------------------------------------------------------------------------

resource logicApp 'Microsoft.Logic/workflows@2019-05-01' = {
  name: name
  location: location
  tags: tags
  properties: {
    state: 'Enabled'
    definition: {
      '$schema': 'https://schema.management.azure.com/providers/Microsoft.Logic/schemas/2016-06-01/workflowdefinition.json#'
      contentVersion: '1.0.0.0'
      parameters: {
        '$connections': {
          defaultValue: {}
          type: 'Object'
        }
      }
      triggers: {
        manual: {
          type: 'Request'
          kind: 'Http'
          inputs: {
            schema: {
              type: 'object'
              properties: {
                email: { type: 'string' }
                otp: { type: 'string' }
              }
              required: ['email', 'otp']
            }
          }
        }
      }
      actions: {
        Send_an_email: {
          type: 'ApiConnection'
          inputs: {
            host: {
              connection: {
                name: '@parameters(\'$connections\')[\'office365\'][\'connectionId\']'
              }
            }
            method: 'post'
            path: '/v2/Mail'
            body: {
              To: '@triggerBody()?[\'email\']'
              Subject: 'Your Secure Upload Portal OTP'
              Body: '<p>Your one-time password is: <strong>@{triggerBody()?[\'otp\']}</strong></p><p>This code expires in 10 minutes. Do not share it with anyone.</p>'
              Importance: 'Normal'
            }
          }
          runAfter: {}
        }
        Response: {
          type: 'Response'
          kind: 'Http'
          inputs: {
            statusCode: 200
            body: { message: 'OTP email sent.' }
          }
          runAfter: {
            Send_an_email: ['Succeeded']
          }
        }
      }
      outputs: {}
    }
    parameters: {
      '$connections': {
        value: {
          office365: {
            connectionId: office365ApiConnection.id
            connectionName: 'office365'
            id: subscriptionResourceId('Microsoft.Web/locations/managedApis', location, 'office365')
          }
        }
      }
    }
  }
}

// ---------------------------------------------------------------------------
// Office 365 API Connection placeholder
// The connection requires manual authorization via the Azure Portal or
// az logic workflow run CLI after initial deploy.
// ---------------------------------------------------------------------------

resource office365ApiConnection 'Microsoft.Web/connections@2016-06-01' = {
  name: 'office365-${name}'
  location: location
  tags: tags
  properties: {
    displayName: 'Office 365 - OTP Email Sender'
    api: {
      id: subscriptionResourceId('Microsoft.Web/locations/managedApis', location, 'office365')
    }
    parameterValues: {}
  }
}

// ---------------------------------------------------------------------------
// Diagnostic Settings
// ---------------------------------------------------------------------------

resource logWorkspace 'Microsoft.OperationalInsights/workspaces@2023-09-01' existing = {
  name: logAnalyticsWorkspaceName
}

resource diagnosticSettings 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: 'diag-${name}'
  scope: logicApp
  properties: {
    workspaceId: logWorkspace.id
    logs: [{ categoryGroup: 'allLogs', enabled: true }]
    metrics: [{ category: 'AllMetrics', enabled: true }]
  }
}

// ---------------------------------------------------------------------------
// Outputs
// ---------------------------------------------------------------------------

@description('Resource ID of the Logic App.')
output resourceId string = logicApp.id

@description('Name of the Logic App.')
output resourceName string = logicApp.name

@description('HTTP trigger callback URL (SAS-protected).')
output triggerUrl string = listCallbackUrl(
  '${logicApp.id}/triggers/manual',
  '2019-05-01'
).value

@description('Principal ID (Logic App has no MI in this pattern).')
output principalId string = ''
