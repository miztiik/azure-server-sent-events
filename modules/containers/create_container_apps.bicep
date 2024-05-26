// SET MODULE DATE
param module_metadata object = {
  module_last_updated: '2024-04-13'
  owner: 'miztiik@github'
}

param deploymentParams object
param tags object

param uami_name_akane string
param logAnalyticsWorkspaceName string

param container_app_params object
param acr_name string

param svc_bus_ns_name string
param svc_bus_q_name string
param svc_bus_topic_name string
param sales_events_subscriber_name string
param all_events_subscriber_name string

param sa_name string
param blob_container_name string

param cosmos_db_accnt_name string
param cosmos_db_name string
param cosmos_db_container_name string

@description('Get Storage Account Reference')
resource r_sa 'Microsoft.Storage/storageAccounts@2021-06-01' existing = {
  name: sa_name
}

@description('Get Cosmos DB Account Ref')
resource r_cosmos_db_accnt 'Microsoft.DocumentDB/databaseAccounts@2022-08-15' existing = {
  name: cosmos_db_accnt_name
}

@description('Get Log Analytics Workspace Reference')
resource r_logAnalyticsPayGWorkspace_ref 'Microsoft.OperationalInsights/workspaces@2022-10-01' existing = {
  name: logAnalyticsWorkspaceName
}

@description('Reference existing User-Assigned Identity')
resource r_uami_container_app 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' existing = {
  name: uami_name_akane
}

@description('Get Container Registry Reference')
resource r_acr 'Microsoft.ContainerRegistry/registries@2022-02-01-preview' existing = {
  name: acr_name
}

@description('Get Service Bus Namespace Reference')
resource r_svc_bus_ns_ref 'Microsoft.ServiceBus/namespaces@2021-06-01-preview' existing = {
  name: svc_bus_ns_name
}

var _app_name = replace(
  '${deploymentParams.enterprise_name_suffix}-${deploymentParams.loc_short_code}-${container_app_params.name_prefix}-${deploymentParams.global_uniqueness}',
  '_',
  '-'
)

resource r_mgd_env 'Microsoft.App/managedEnvironments@2022-11-01-preview' = {
  name: '${_app_name}-mgd-env'
  location: deploymentParams.location
  tags: tags

  properties: {
    zoneRedundant: false // Available only for Premium SKU
    appLogsConfiguration: {
      destination: 'log-analytics'
      logAnalyticsConfiguration: {
        customerId: r_logAnalyticsPayGWorkspace_ref.properties.customerId
        sharedKey: r_logAnalyticsPayGWorkspace_ref.listKeys().primarySharedKey
      }
    }
  }
}

resource r_container_app_sse 'Microsoft.App/containerApps@2022-03-01' = {
  name: 'c-sse-app-${deploymentParams.loc_short_code}-${deploymentParams.global_uniqueness}'
  location: deploymentParams.location
  tags: tags
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${r_uami_container_app.id}': {}
    }
  }
  properties: {
    managedEnvironmentId: r_mgd_env.id
    configuration: {
      activeRevisionsMode: 'single'
      secrets: [
        {
          name: 'registry-password'
          value: r_acr.listCredentials().passwords[0].value
        }
        {
          name: 'svc-bus-connection'
          value: '${listKeys('${r_svc_bus_ns_ref.id}/AuthorizationRules/RootManageSharedAccessKey', r_svc_bus_ns_ref.apiVersion).primaryConnectionString}'
        }
      ]
      registries: [
        {
          server: '${r_acr.name}.azurecr.io'
          // username: r_acr.name
          // passwordSecretRef: 'registry-password'
          identity: r_uami_container_app.id
        }
      ]
      ingress: {
        external: true
        targetPort: 80
        transport: 'auto'
        traffic: [
          {
            latestRevision: true
            weight: 100
          }
        ]
      }
    }
    template: {
      scale: {
        minReplicas: 1
        maxReplicas: 3
        rules: [
          {
            name: 'http-scaling-rule'
            http: {
              metadata: {
                concurrentRequests: '5'
              }
            }
          }
        ]
      }
      containers: [
        {
          env: [
            {
              name: 'APPINSIGHTS_INSTRUMENTATIONKEY'
              value: r_logAnalyticsPayGWorkspace_ref.properties.customerId
            }
          ]
          name: 'sse-app'
          // image: 'mcr.microsoft.com/azuredocs/containerapps-helloworld:latest'
          // image: '${sys.toLower(acr_name)}.azurecr.io/miztiik/echo-hello:latest'
          // image: '${sys.toLower(acr_name)}.azurecr.io/miztiik/flask-web-server:latest'
          // image: '${sys.toLower(acr_name)}.azurecr.io/miztiik/event-producer:latest'
          image: '${sys.toLower(acr_name)}.azurecr.io/miztiik/sse-app:latest'
          resources: {
            cpu: json('1.0')
            memory: '2.0Gi'
          }
          probes: [
            {
              type: 'startup'
              httpGet: {
                path: '/'
                port: 80
              }
              failureThreshold: 3
              initialDelaySeconds: 10
              periodSeconds: 10
              successThreshold: 1
              timeoutSeconds: 2
            }
            {
              type: 'liveness'
              httpGet: {
                path: '/'
                port: 80
              }
              failureThreshold: 3
              initialDelaySeconds: 10
              periodSeconds: 10
              successThreshold: 1
              timeoutSeconds: 2
            }
          ]
        }
      ]
    }
  }
}

// OUTPUTS
output module_metadata object = module_metadata
