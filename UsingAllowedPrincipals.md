# Using allowedPrincipals

The authentication setup for App Service Authentication has a `defaultAuthorizationPolicy` which can have an array of `allowedPrincipals`. You cannot access this is in the Azure Portal though! You have to deploy with ARM/Bicep to get access to this - or do some manual editing using [Azure Resource Explorer](https://resources.azure.com/).

## Creating the App Registration
There is a way to [create an App Registration by embedding Powershell inside a Bicep template](https://reginbald.medium.com/creating-app-registration-with-arm-bicep-b1d48a287abb). However, that comes with its own challenges so I am avoding that approach here.

Instead, you need to run some Powershell to create the App Registration and then copy the ID and the Application ID URI (you can get them later from the portal, don't worry).

The script `infrastructure.allowedPrincipals/CreateAppRegistration.ps1` will create the App Registration for you.
In the end, there is not a lot to it.

1. You need an "Application Identifier URI" - this is used for the Front End to request a token: When the Front End asks Azure for a token, it needs to specify a "Scope". The scope is the `[Application Identifier URI]/.default` - for example `api://1232343124/.default` or `api://mywebsite.something.com/.default`. It is important that the Application Identifier URI is unique within the tenant. You can see the current value on the "Expose an API" page of the App Registration.  
2. In the script, we also ask for the URL for the website. It is not entirely clear if this is actually necessary in this scenario, as we don't support "redirect URLs". 

And that's it. App Registrations have a *lot* of functionality, but this one uses hardly any of it and is very light-weight.

## Setting up Authentication with Bicep
The `infrastructure.allowedPrincipals/main.bicep` file will set up the Authentication on the backend and add some configuration values to the Front End. The key bit is this:

```bicep
resource auth 'Microsoft.Web/sites/config@2022-09-01' = {
  parent: backEnd
  name: 'authsettingsV2'
  properties: {
    globalValidation: {
      requireAuthentication: true
      unauthenticatedClientAction: 'Return401'
    }
    identityProviders: {
      azureActiveDirectory: {
        registration: {
          clientId: backendAuthappRegistrationClientId
          openIdIssuer: 'https://sts.windows.net/${tenant().tenantId}/v2.0'
        }
        enabled: true
        login: {
          disableWWWAuthenticate: true
        }
        validation: {
          allowedAudiences: [
            backendAuthApplicationIDUri
          ]
          defaultAuthorizationPolicy: {
            allowedPrincipals: {
              identities: [
                frontEnd.identity.principalId
              ]
            }
          }
        }
      }
    }
  }
}

```

The `globalValidation` sets it up so all requests must be authenticated and configures it to return 401 (rather than a redirect to a login page) if not authenticated.

The `azureActiveDirectory/registration` needs the ID of the App Registration you created above: It kinda delegates authentication to the App Registration.

The `validation\allowedAudiences` is very important: If you forget it (or it's wrong) you will get 401 errors when trying to connect. If you experiment in the Portal, it is very easy to miss it as you are not asked for it - you have to dig down a level to get to it. It just needs the value of the "Application ID URI" from the "Expose an API" section of the App Registration.

`defaultAuthorizationPolicy\allowedPrincipals` is the reason we are here at all: This is how we can control which Managed Identities can access the service. When this is present, only the users listed here will be allowed access. Others will still be able to obtain a token, but they will receive a 40*3* (not a 401) if they try to access the Back End. You can list multiple Principals here. 


## Accessing the Service when using allowedPrincipals

The purpose of this exercise was to use Managed Identity, so first set up Managed Identity on the Front End. 

Once you have done that, you can use the following code:
```csharp
var client = new HttpClient();
var creds = new DefaultAzureCredential();
var token = await creds.GetTokenAsync(new Azure.Core.TokenRequestContext(new string[] { scope }));
client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token.Token);
var backendResponse = await client.GetAsync(backend);

```
*Not production code - don't new up HttpClient!*.
This code will use Managed Identity in Azure and your local user account when testing locally. 
It is almost surprisingly easy, once you get to this point.

Note that obtaining a token is an expensive, slow operation. You definitely want to cache the token! 

## Testing locally with allowedPrincipals

When testing locally (use the "tester" program) there are few things to note:
1. When you call `DefaultAzureCredential`, it will use one of several local Azure Identity providers that you may have logged in with. In my case, that is the Azure CLI, but it doesn't have to be. The first time you do this, it will probably tell you that "this has not received Admin consent" and ask you to "login interactively". Once you do that, you may get an error saying that this Client ID has not been authorised for use with this App Service. Take a note of this Client ID and go to the App Registration in the Azure Portal, then to the "Expose an API" page and select "Add a client application".
The Client ID here is an application - in my case the Azure CLI - and not a user ID. It makes sense if you dig into oAuth, but - again - outside the scope of this post. I recommend that you only add this Client ID for testing and remove it in production.
2. You need to get your own user's Object ID and add it to `defaultAuthorizationPolicy\allowedPrincipals` - otherwise you will get a 403 when you try to connect. You can get your Object ID via the Azure CLI by running `az ad signed-in-user show`.
