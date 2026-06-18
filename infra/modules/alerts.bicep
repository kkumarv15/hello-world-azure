@description('Base name for resources')
param baseName string

@description('Web App resource ID')
param webAppId string

@description('Web App name')
param webAppName string

@description('Location for action group resources')
param location string

var actionGroupName = 'ag-${baseName}'
var highCpuAlertName = 'alert-high-cpu-${baseName}'
var highMemoryAlertName = 'alert-high-memory-${baseName}'
var http5xxAlertName = 'alert-http5xx-${baseName}'

// Action Group — email ops team + webhook placeholder
resource actionGroup 'Microsoft.Insights/actionGroups@2023-01-01' = {
  name: actionGroupName
  location: 'global'
  properties: {
    groupShortName: 'HelloWorldOps'
    enabled: true
    emailReceivers: [
      {
        name: 'OpsTeamEmail'
        emailAddress: 'ops-team@example.com'
        useCommonAlertSchema: true
      }
    ]
    webhookReceivers: [
      {
        name: 'AlertWebhook'
        serviceUri: 'https://hooks.example.com/alerts'
        useCommonAlertSchema: true
      }
    ]
  }
}

// Alert: CPU > 80% for 5 minutes
resource highCpuAlert 'Microsoft.Insights/metricAlerts@2018-03-01' = {
  name: highCpuAlertName
  location: 'global'
  properties: {
    description: 'CPU usage exceeded 80% for 5 minutes on ${webAppName}'
    severity: 2
    enabled: true
    scopes: [
      webAppId
    ]
    evaluationFrequency: 'PT5M'
    windowSize: 'PT5M'
    criteria: {
      allOf: [
        {
          name: 'HighCpuThreshold'
          metricName: 'CpuPercentage'
          metricNamespace: 'Microsoft.Web/sites'
          operator: 'GreaterThan'
          threshold: 80
          timeAggregation: 'Average'
          criterionType: 'StaticThresholdCriterion'
        }
      ]
    }
    actions: [
      {
        actionGroupId: actionGroup.id
      }
    ]
  }
}

// Alert: Memory > 80% for 5 minutes
resource highMemoryAlert 'Microsoft.Insights/metricAlerts@2018-03-01' = {
  name: highMemoryAlertName
  location: 'global'
  properties: {
    description: 'Memory usage exceeded 80% for 5 minutes on ${webAppName}'
    severity: 2
    enabled: true
    scopes: [
      webAppId
    ]
    evaluationFrequency: 'PT5M'
    windowSize: 'PT5M'
    criteria: {
      allOf: [
        {
          name: 'HighMemoryThreshold'
          metricName: 'MemoryPercentage'
          metricNamespace: 'Microsoft.Web/sites'
          operator: 'GreaterThan'
          threshold: 80
          timeAggregation: 'Average'
          criterionType: 'StaticThresholdCriterion'
        }
      ]
    }
    actions: [
      {
        actionGroupId: actionGroup.id
      }
    ]
  }
}

// Alert: HTTP 5xx rate > 5% in 5 minutes
resource http5xxAlert 'Microsoft.Insights/metricAlerts@2018-03-01' = {
  name: http5xxAlertName
  location: 'global'
  properties: {
    description: 'HTTP 5xx errors exceeded 5% in 5 minutes on ${webAppName}'
    severity: 1
    enabled: true
    scopes: [
      webAppId
    ]
    evaluationFrequency: 'PT5M'
    windowSize: 'PT5M'
    criteria: {
      allOf: [
        {
          name: 'Http5xxRate'
          metricName: 'Http5xx'
          metricNamespace: 'Microsoft.Web/sites'
          operator: 'GreaterThan'
          threshold: 10
          timeAggregation: 'Total'
          criterionType: 'StaticThresholdCriterion'
        }
      ]
    }
    actions: [
      {
        actionGroupId: actionGroup.id
      }
    ]
  }
}

output actionGroupName string = actionGroup.name
