param name string
param location string = resourceGroup().location
param tags object = {}
param entraAuth bool = false

@minLength(1)
param publisherEmail string = 'noreply@microsoft.com'

@minLength(1)
param publisherName string = 'n/a'
param sku string = 'Developer'
param skuCount int = 1
param applicationInsightsName string
param openAiUris array
param managedIdentityName string
param clientAppId string = ' '
param tenantId string = tenant().tenantId
param audience string = 'https://cognitiveservices.azure.com/.default'

var openAiApiBackendId = 'openai-backend'
var openAiApiUamiNamedValue = 'uami-client-id'
var openAiApiEntraNamedValue = 'entra-auth'
var openAiApiClientNamedValue = 'client-id'
var openAiApiTenantNamedValue = 'tenant-id'
var openAiApiAudienceNamedValue = 'audience'

resource applicationInsights 'Microsoft.Insights/components@2020-02-02' existing = {
  name: applicationInsightsName
}

resource managedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2018-11-30' existing = {
  name: managedIdentityName
}

resource apimService 'Microsoft.ApiManagement/service@2021-08-01' = {
  name: name
  location: location
  tags: union(tags, { 'azd-service-name': name })
  sku: {
    name: sku
    capacity: (sku == 'Consumption') ? 0 : ((sku == 'Developer') ? 1 : skuCount)
  }
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${managedIdentity.id}': {}
    }
  }
  properties: {
    publisherEmail: publisherEmail
    publisherName: publisherName
    // Custom properties are not supported for Consumption SKU
    customProperties: sku == 'Consumption' ? {} : {
      'Microsoft.WindowsAzure.ApiManagement.Gateway.Security.Ciphers.TLS_ECDHE_RSA_WITH_AES_256_CBC_SHA': 'false'
      'Microsoft.WindowsAzure.ApiManagement.Gateway.Security.Ciphers.TLS_ECDHE_RSA_WITH_AES_128_CBC_SHA': 'false'
      'Microsoft.WindowsAzure.ApiManagement.Gateway.Security.Ciphers.TLS_RSA_WITH_AES_128_GCM_SHA256': 'false'
      'Microsoft.WindowsAzure.ApiManagement.Gateway.Security.Ciphers.TLS_RSA_WITH_AES_256_CBC_SHA256': 'false'
      'Microsoft.WindowsAzure.ApiManagement.Gateway.Security.Ciphers.TLS_RSA_WITH_AES_128_CBC_SHA256': 'false'
      'Microsoft.WindowsAzure.ApiManagement.Gateway.Security.Ciphers.TLS_RSA_WITH_AES_256_CBC_SHA': 'false'
      'Microsoft.WindowsAzure.ApiManagement.Gateway.Security.Ciphers.TLS_RSA_WITH_AES_128_CBC_SHA': 'false'
      'Microsoft.WindowsAzure.ApiManagement.Gateway.Security.Ciphers.TripleDes168': 'false'
      'Microsoft.WindowsAzure.ApiManagement.Gateway.Security.Protocols.Tls10': 'false'
      'Microsoft.WindowsAzure.ApiManagement.Gateway.Security.Protocols.Tls11': 'false'
      'Microsoft.WindowsAzure.ApiManagement.Gateway.Security.Protocols.Ssl30': 'false'
      'Microsoft.WindowsAzure.ApiManagement.Gateway.Security.Backend.Protocols.Tls10': 'false'
      'Microsoft.WindowsAzure.ApiManagement.Gateway.Security.Backend.Protocols.Tls11': 'false'
      'Microsoft.WindowsAzure.ApiManagement.Gateway.Security.Backend.Protocols.Ssl30': 'false'
    }
  }
}

resource apimOpenaiApi 'Microsoft.ApiManagement/service/apis@2022-08-01' = {
  name: 'azure-openai-service-api'
  parent: apimService
  properties: {
    path: 'openai'
    apiRevision: '1'
    displayName: 'Azure OpenAI Service API'
    subscriptionRequired: entraAuth ? false:true 
    subscriptionKeyParameterNames: {
      header: 'api-key'
    }
    format: 'openapi+json'
    value: loadJsonContent('./openapi/openai-openapiv3.json')
    protocols: [
      'https'
    ]
  }
}

resource openAiBackends 'Microsoft.ApiManagement/service/backends@2021-08-01' = [for (openAiUri, i) in openAiUris: {
  name: '${openAiApiBackendId}-${i}'
  parent: apimService
  properties: {
    description: openAiApiBackendId
    url: openAiUri
    protocol: 'http'
    tls: {
      validateCertificateChain: true
      validateCertificateName: true
    }
  }
}]

resource apimOpenaiApiUamiNamedValue 'Microsoft.ApiManagement/service/namedValues@2022-08-01' = {
  name: openAiApiUamiNamedValue
  parent: apimService
  properties: {
    displayName: openAiApiUamiNamedValue
    secret: true
    value: managedIdentity.properties.clientId
  }
}

resource apiopenAiApiEntraNamedValue 'Microsoft.ApiManagement/service/namedValues@2022-08-01' = {
  name: openAiApiEntraNamedValue
  parent: apimService
  properties: {
    displayName: openAiApiEntraNamedValue
    secret: false
    value: entraAuth
  }
}
resource apiopenAiApiClientNamedValue 'Microsoft.ApiManagement/service/namedValues@2022-08-01' = {
  name: openAiApiClientNamedValue
  parent: apimService
  properties: {
    displayName: openAiApiClientNamedValue
    secret: true
    value: clientAppId
  }
}
resource apiopenAiApiTenantNamedValue 'Microsoft.ApiManagement/service/namedValues@2022-08-01' = {
  name: openAiApiTenantNamedValue
  parent: apimService
  properties: {
    displayName: openAiApiTenantNamedValue
    secret: true
    value: tenantId
  }
}
resource apimOpenaiApiAudienceiNamedValue 'Microsoft.ApiManagement/service/namedValues@2022-08-01' =  {
  name: openAiApiAudienceNamedValue
  parent: apimService
  properties: {
    displayName: openAiApiAudienceNamedValue
    secret: true
    value: audience
  }
}

resource openaiApiPolicy 'Microsoft.ApiManagement/service/apis/policies@2022-08-01' =  {
  name: 'policy'
  parent: apimOpenaiApi
  properties: {
    value: loadTextContent('./policies/api_policy.xml')
    format: 'rawxml'
  }
  dependsOn: [
    openAiBackends
    apiopenAiApiClientNamedValue
    apiopenAiApiEntraNamedValue
    apimOpenaiApiAudienceiNamedValue
    apiopenAiApiTenantNamedValue
  ]
}

resource apimLogger 'Microsoft.ApiManagement/service/loggers@2021-12-01-preview' = {
  name: 'appinsights-logger'
  parent: apimService
  properties: {
    credentials: {
      instrumentationKey: applicationInsights.properties.InstrumentationKey
    }
    description: 'Logger to Azure Application Insights'
    isBuffered: false
    loggerType: 'applicationInsights'
    resourceId: applicationInsights.id
  }
}

resource apimUser 'Microsoft.ApiManagement/service/users@2020-06-01-preview' = {
  parent: apimService
  name: 'myUser'
  properties: {
    firstName: 'My'
    lastName: 'User'
    email: 'myuser@example.com'
    state: 'active'
  }
}

resource apimSubscription 'Microsoft.ApiManagement/service/subscriptions@2020-06-01-preview' = {
  parent: apimService
  name: 'mySubscription'
  properties: {
    displayName: 'My Subscription'
    state: 'active'
    allowTracing: true
    scope: '/apis/${apimOpenaiApi.name}'
  }
}

@description('The name of the deployed API Management service.')
output apimName string = apimService.name

@description('The path for the OpenAI API in the deployed API Management service.')
output apimOpenaiApiPath string = apimOpenaiApi.properties.path

@description('Gateway URL for the deployed API Management resource.')
output apimGatewayUrl string = apimService.properties.gatewayUrl
