@description('You need to create an App Registration in AD to use for backend auth as Bicep can\'t do it. Specify the Application (client) ID here')
param appRegistrationClientId string

@description('The \'Expose an API\' Application ID Uri - usually api://something')
param applicationIDUri string

param appServiceName string

resource appService 'Microsoft.Web/sites@2022-09-01' existing = {
  name: appServiceName
}


resource auth 'Microsoft.Web/sites/config@2022-09-01' = {
  parent: appService
  name: 'authsettingsV2'
  properties: {
    globalValidation: {
      requireAuthentication: true
      unauthenticatedClientAction: 'Return401'
    }
    identityProviders: {
      azureActiveDirectory: {
        registration: {
          clientId: appRegistrationClientId
          openIdIssuer: 'https://sts.windows.net/${tenant().tenantId}/v2.0'
        }
        enabled: true
        login: {
          disableWWWAuthenticate: true
        }
        validation: {
          allowedAudiences: [
            applicationIDUri
          ]
        }
      }
    }
  }
}
