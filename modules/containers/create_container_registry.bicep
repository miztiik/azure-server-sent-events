// SET MODULE DATE
param module_metadata object = {
  module_last_updated: '2024-05-25'
  owner: 'miztiik@github'
}
param deploymentParams object
param tags object

param acr_params object

param uami_name_akane string
param logAnalyticsWorkspaceId string

// @description('Get Log Analytics Workspace Reference')
// resource r_logAnalyticsPayGWorkspace_ref 'Microsoft.OperationalInsights/workspaces@2022-10-01' existing = {
//   name: logAnalyticsWorkspaceName
// }
@description('Get existing User-Assigned Identity')
resource r_uami_container_registry 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' existing = {
  name: uami_name_akane
}

var uniq_str = substring(uniqueString(resourceGroup().id), 0, 6)

var __acr_name = replace(
  replace('${acr_params.name_prefix}-${deploymentParams.global_uniqueness}-${uniq_str}', '_', ''),
  '-',
  ''
)

resource r_acr 'Microsoft.ContainerRegistry/registries@2023-01-01-preview' = {
  name: __acr_name
  location: deploymentParams.location
  tags: tags
  sku: {
    name: 'Basic'
    // name: 'Standard'
    // name: 'Premium'
  }
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${r_uami_container_registry.id}': {}
    }
  }
  properties: {
    adminUserEnabled: true
    anonymousPullEnabled: false
    publicNetworkAccess: 'Enabled'
    // zoneRedundancy: 'Enabled'
    networkRuleBypassOptions: 'AzureServices'
  }
}

////////////////////////////////////////////
//                                        //
//         Diagnostic Settings            //
//                                        //
////////////////////////////////////////////

resource r_acr_diag 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: '${__acr_name}_diag'
  scope: r_acr
  properties: {
    workspaceId: logAnalyticsWorkspaceId
    logs: [
      {
        categoryGroup: 'allLogs'
        enabled: true
      }
    ]
    metrics: [
      {
        category: 'AllMetrics'
        timeGrain: 'PT5M'
        enabled: true
      }
    ]
  }
}

// OUTPUTS
output module_metadata object = module_metadata

output acr_login_server string = r_acr.properties.loginServer
output acr_name string = r_acr.name
