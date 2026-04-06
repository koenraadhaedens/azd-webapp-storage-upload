using './main.bicep'

param location = readEnvironmentVariable('AZURE_LOCATION', 'eastus2')
param environment = readEnvironmentVariable('AZURE_ENV_NAME', 'dev')
param projectName = 'secureupload'
param principalId = readEnvironmentVariable('AZURE_PRINCIPAL_ID', '')
