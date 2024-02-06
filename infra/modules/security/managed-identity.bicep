param name string
param location string = resourceGroup().location
param tags object = {}

var cognitiveServicesUserRoleDefinitionId = resourceId('Microsoft.Authorization/roleDefinitions', 'a97b65f3-24c7-4388-baec-2e87135dc908')

resource managedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2018-11-30' = {
  name: name
  location: location
  tags: union(tags, { 'azd-service-name': name })
}

// Assign the Cognitive Services User role to the user-defined managed identity used by workloads
resource cognitiveServicesUserRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(managedIdentity.id, cognitiveServicesUserRoleDefinitionId)
  scope: resourceGroup()
  properties: {
    roleDefinitionId: cognitiveServicesUserRoleDefinitionId
    principalId: managedIdentity.properties.principalId
    principalType: 'ServicePrincipal'
  }
}

output managedIdentityName string = managedIdentity.name