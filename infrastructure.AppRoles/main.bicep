param shortSystemName string = 'XXX'
param environment string = 'uat'
param location string = resourceGroup().location
param dataCentreShort string = 'euw'

@description('You need to create an App Registration in AD to use for backend auth as Bicep can\'t do it. Specify the Application (client) ID here')
param backendAuthappRegistrationClientId string

@description('The \'Expose an API\' Application ID Uri - usually api://something')
param backendAuthApplicationIDUri string

var defaultTags = {
  Environment: 'Experiment'
  Scale: 'Normal'
}

resource appServicePlan 'Microsoft.Web/serverfarms@2022-03-01' = {
  name: '${shortSystemName}-${environment}-${dataCentreShort}-asp'
  location: location
  tags: defaultTags
  sku: {
    name: 'S1'
  }
  kind: 'linux'
  properties: {
    reserved: true
  }
}

resource frontEnd 'Microsoft.Web/sites@2022-09-01' = {
  name: '${shortSystemName}-${environment}-frontend-${dataCentreShort}-as'
  location: location
  kind: 'app'
  properties: {
    serverFarmId: appServicePlan.id
    clientAffinityEnabled: false
    httpsOnly: true
    siteConfig: {
      linuxFxVersion: 'DOTNETCORE|7.0'
      alwaysOn: false
      ftpsState: 'Disabled'
      minTlsVersion: '1.2'
      scmMinTlsVersion: '1.2'
      http20Enabled: true
    }
    publicNetworkAccess: 'Enabled'
    

  }
  identity: {
    type: 'SystemAssigned'
  }
}

resource backEnd 'Microsoft.Web/sites@2022-09-01' = {
  name: '${shortSystemName}-${environment}-backend-${dataCentreShort}-as'
  location: location
  kind: 'app'
  properties: {
    serverFarmId: appServicePlan.id
    clientAffinityEnabled: false
    httpsOnly: true
    siteConfig: {
      linuxFxVersion: 'DOTNETCORE|7.0'
      alwaysOn: false
      ftpsState: 'Disabled'
      minTlsVersion: '1.2'
      scmMinTlsVersion: '1.2'
      http20Enabled: true
    }
    publicNetworkAccess: 'Enabled'
  }
}

module backendAuth 'appServiceAuthentication.bicep' = {
  name: 'backendauth'
  params: {
    applicationIDUri: backendAuthApplicationIDUri
    appRegistrationClientId: backendAuthappRegistrationClientId
    appServiceName: backEnd.name
  }
}

resource frontEndAppSettings 'Microsoft.Web/sites/config@2022-09-01' = {
  name: 'appsettings'
  parent: frontEnd
  properties: {
    BackendUrl: 'https://${backEnd.properties.defaultHostName}'
    BackendAuthScope: '${backendAuthApplicationIDUri}/.default'
    BackendUseAuth: 'true'
  }
}

output frontEndManagedIdentityId string = frontEnd.identity.principalId
