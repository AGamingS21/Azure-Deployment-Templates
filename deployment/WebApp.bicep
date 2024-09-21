param webAppName string // Generate unique String for web app name
param sku string = 'S1' // The SKU of App Service Plan
param linuxFxVersion string = 'DOTNETCORE|8.0' // The runtime stack of web app
param location string = resourceGroup().location // Location for all resources
param objectId string
param vaultName string
param storageAccountName string

var tableNameProd = 'blazortable'
var tableNameStage = 'blazortableStage'
var tableStorageUri = 'https://${storageAccountName}.table.${environment().suffixes.storage}'
var appServicePlanName = webAppName
var webSiteName = toLower(webAppName)
// var appInsightsName = 'blazorappdeploymentslotsinsights'
// var workspaceName = 'blazorappdeploymentslotlogs'
var tenantId = subscription().tenantId

resource appServicePlan 'Microsoft.Web/serverfarms@2022-09-01' = {
  name: appServicePlanName
  location: location
  properties: {
    reserved: true
  }
  sku: {
    name: sku
  }
  kind: 'linux'
}

resource appService 'Microsoft.Web/sites@2022-09-01' = {
  name: webSiteName
  location: location
  kind: 'linux'
  properties: {
    serverFarmId: appServicePlan.id
    siteConfig: {
      linuxFxVersion: linuxFxVersion
      appSettings: [
        // {
        //   name: 'APPINSIGHTS_CONNECTIONSTRING'
        //   value: appInsights.properties.ConnectionString
        // }
        // {
        //   name: 'APPINSIGHTS_INSTRUMENTATIONKEY'
        //   value: appInsights.properties.InstrumentationKey
        // }
        {
          name: 'TableName'
          value: tableNameProd
        }
        {
          name: 'TableStorageUri'
          value: tableStorageUri
        }
      ]
    }
  }
  identity: {
    type: 'SystemAssigned'
  }
}

resource stagingSlot 'Microsoft.Web/sites/slots@2022-09-01' = {
  name: 'staging'
  parent: appService
  location: location
  kind: 'linux'
  properties: {
    serverFarmId: appServicePlan.id
    siteConfig: {
      linuxFxVersion: linuxFxVersion
      appSettings: [
        // {
        //   name: 'APPINSIGHTS_CONNECTIONSTRING'
        //   value: appInsights.properties.ConnectionString
        // }
        // {
        //   name: 'APPINSIGHTS_INSTRUMENTATIONKEY'
        //   value: appInsights.properties.InstrumentationKey
        // }
        {
          name: 'TableName'
          value: tableNameStage
        }
        {
          name: 'TableStorageUri'
          value: tableStorageUri
        }
      ]
    }
  }
  identity: {
    type: 'SystemAssigned'
  }
}

resource storageAccount 'Microsoft.Storage/storageAccounts@2022-05-01' = {
  name: storageAccountName
  location: location
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
  properties: {
    accessTier: 'Hot'
    allowBlobPublicAccess: true
    supportsHttpsTrafficOnly: true
    minimumTlsVersion: 'TLS1_2'
  }
}

resource storageTableDataContributorRoleDefinition 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = {
  scope: subscription()
  name: '0a9a7e1f-b9d0-4cc4-a60d-0319b160aaa3'
}

resource tableRoleAssignmentProd 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(resourceGroup().id, appService.id, storageTableDataContributorRoleDefinition.id)
  scope: storageAccount
  properties: {
    roleDefinitionId: storageTableDataContributorRoleDefinition.id
    principalId: appService.identity.principalId
  }
}

resource tableRoleAssignmentStaging 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(resourceGroup().id, stagingSlot.id, storageTableDataContributorRoleDefinition.id)
  scope: storageAccount
  properties: {
    roleDefinitionId: storageTableDataContributorRoleDefinition.id
    principalId: stagingSlot.identity.principalId
  }
}

// resource appInsights 'Microsoft.Insights/components@2020-02-02' = {
//   name: appInsightsName
//   location: location
//   kind: 'web'
//   properties: {
//     Application_Type: 'web'
//   }
// }

// resource logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2021-04-01' = {
//   name: workspaceName
//   location: location
//   properties: {
//     sku: sku
//   }
// }

// resource appInsights 'Microsoft.Insights/components@2020-02-02' = {
//   name: appInsightsName
//   location: location
//   kind: 'other'
//   properties: {
//     Application_Type: 'web'
//     Flow_Type: 'Bluefield'
//     Request_Source: 'CustomDeployment'
//     WorkspaceResourceId: logAnalyticsWorkspace.id
//   }
// }

resource keyVault 'Microsoft.KeyVault/vaults@2023-02-01' = {
  name: vaultName
  location: location
  properties: {
    tenantId: tenantId
    sku: {
      family: 'A'
      name: 'standard'
    }
    accessPolicies: [
      {
        objectId: objectId
        permissions: {
          secrets: [
            'List'
            'Get'
            'Set'
            'Delete'
          ]
        }
        tenantId: tenantId
      
      }
    ]
    enabledForDeployment: true
    enabledForTemplateDeployment: true
    enabledForDiskEncryption: true
    enableSoftDelete: true
  }
}
