targetScope = 'subscription'

@description('Base name for all resources')
param appName string

@description('Environment label (dev, uat, prod)')
param environment string

@description('Azure region for deployment')
param location string

@description('Node.js runtime version for App Service')
param nodeVersion string = 'NODE|20-lts'

// Build resource names with environment suffix
var rgName = 'rg-${appName}-${environment}'
var baseName = '${appName}-${environment}'

// Create Resource Group
resource resourceGroup 'Microsoft.Resources/resourceGroups@2023-07-01' = {
  name: rgName
  location: location
  tags: {
    environment: environment
    project: 'azure-cicd-poc'
    managedBy: 'bicep'
    tool: 'azure-devops'
  }
}

// Deploy Monitoring (App Insights + Log Analytics)
module monitoring 'modules/monitoring.bicep' = {
  name: 'monitoring-deploy'
  scope: resourceGroup
  params: {
    baseName: baseName
    location: location
  }
}

// Deploy App Service Plan + Web App
module appService 'modules/appService.bicep' = {
  name: 'appservice-deploy'
  scope: resourceGroup
  params: {
    baseName: baseName
    location: location
    nodeVersion: nodeVersion
    appInsightsConnectionString: monitoring.outputs.appInsightsConnectionString
    appInsightsInstrumentationKey: monitoring.outputs.appInsightsInstrumentationKey
  }
}

// Deploy Azure Monitor Alerts
module alerts 'modules/alerts.bicep' = {
  name: 'alerts-deploy'
  scope: resourceGroup
  params: {
    baseName: baseName
    location: location
    webAppId: appService.outputs.webAppId
    webAppName: appService.outputs.webAppName
  }
}

// Outputs
output webAppName string = appService.outputs.webAppName
output webAppHostName string = appService.outputs.webAppHostName
output webAppPrincipalId string = appService.outputs.webAppPrincipalId
output appInsightsName string = monitoring.outputs.appInsightsName
output logAnalyticsName string = monitoring.outputs.logAnalyticsName
output resourceGroupName string = resourceGroup.name
output actionGroupName string = alerts.outputs.actionGroupName
