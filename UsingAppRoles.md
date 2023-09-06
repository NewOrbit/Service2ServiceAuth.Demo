# Using App Roles


## App Registration and Enterprise Application
The *Back End* needs both an App Registration and an Enterprise Application. The Enterprise Application is also known as a Service Principal. The Enterprise Application for the *backend* is needed to allow you to assign permissions to the App Role to the *frontend*.

Think of it this way: The App Registration is the thing that is really linked to the *backend*. It defines a bunch of things about the *backend*, including App Roles. The backend only really knows about the App Registration. An Enterprise Application is kind-of a representation of that App Registration in a specific Tenant: It allows you to configure what thing users and Manged Identities etc in the Tenant can do with the App Registration. It is the Enterprise Application that allows you to assign permissions to the App Role to the *frontend*.
Yes, it's confusing and I am not really doing a good job of explaining it here.

## Step 1: Create an App Registration and Enterprise Application for the Back End
There is a way to [create an App Registration by embedding Powershell inside a Bicep template](https://reginbald.medium.com/creating-app-registration-with-arm-bicep-b1d48a287abb). However, that comes with its own challenges so I am avoding that approach here.

Instead, you need to run some Powershell to create the App Registration and then copy the ID and the Application ID URI (you can get them later from the portal, don't worry). Alternatively, you can create the App Registration in the portal: In that case, start from the App Service -> Authentication and let Azure do all the heavy lifting.

In any case, the script `infrastructure.appRoles/CreateAppRegistration.ps1` will create the App Registration for you along with the Enterprise Application and the App Role. 

*The script will output a bunch of information. Keep hold of that - you will need it in the next two steps.*

You can also do this manually. Microsoft has a good explanation [here](https://learn.microsoft.com/en-us/azure/active-directory/managed-identities-azure-resources/how-to-assign-app-role-managed-identity-cli).

### Assignment Required
**NOTE**: The script sets "Assignment required" to "true". This means that *only* Users that have been explicitly assigned to the app or Managed Identities that have been assigned at least one App Role will be able to obtain an access token. If you try to obtain an access token as a Managed Identity without an assignment, you will get an "unknown error" (500) from Azure. 

*This allows you to keep things simple: You can use the permission to **any** app role as a binary "access yes/no" without having to change the backend to know about roles! This is a good thing.*

Alternatively, you can change the backend to understand Roles and do something more sophisticated, if you desire.

## Step 2: Create the infrastructure
Run the script `infrastructure.appRoles/CreateInfrastructure.ps1`. This will create the infrastructure for you. 

Look for the "outputs" node in the result: It has the ID of the Managed Identity for the Front End, which you will need in step 3.

## Step 3: Assign the App Role to the Front End
After the Front End has been created, you need to assign the *App Role* to the Front End Managed Identity.


I attempted to do this in PowerShell (see `infrastructure.appRoles/AssignAppRole.ps1`) but either my PowerShell foo is not strong enough (likely) or there is a problem with `az rest` on Windows. So I ended up using Bash instead. If you can figure out the PowerShell, please submit a PR.

The script `infrastructure.appRoles/AssignAppRole.sh` will do this for you. You need to give it three GUIDs obtained from the previous steps.

*Note* After you have done this, you can go to the Enterprise Application in the Azure Portal and *see* the assignment. You can also assign other users to the App and the App Role here. However, you cannot *assign* a Managed Identity here, only view them.
**If Microsoft fixed that one thing, this would be a lot easier!**

## Accessing the Service when using App Roles

Once all the above is done, you can use the following code to access the service:
```csharp
var client = new HttpClient();
var creds = new DefaultAzureCredential();
var token = await creds.GetTokenAsync(new Azure.Core.TokenRequestContext(new string[] { scope }));
client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token.Token);
var backendResponse = await client.GetAsync(backend);

```
*Not production code - don't new up HttpClient!*.
This code will use Managed Identity in Azure and your local user account when testing locally (as long as your have assigned your user! See below). 
It is almost surprisingly easy, once you get to this point.

Note that obtaining a token is an expensive, slow operation. You definitely want to cache the token! 

## Testing locally with App Roles

When testing locally (use the "tester" program) there are few things to note:

1. You need to Assign your User ID to the Enterprise Application. You can do this in the Portal by going to the App Registration, then to "Users and Groups" and selecting "Add User". 
2. When you call `DefaultAzureCredential`, it will use one of several local Azure Identity providers that you may have logged in with. In my case, that is the Azure CLI, but it doesn't have to be. The first time you do this, it will probably tell you that "this has not received Admin consent" and ask you to "login interactively". Once you do that, you may get an error saying that this Client ID has not been authorised for use with this App Service. Take a note of this Client ID and go to the App Registration in the Azure Portal, then to the "Expose an API" page and select "Add a client application".
The Client ID here is an application - in my case the Azure CLI - and not a user ID. It makes sense if you dig into oAuth, but - again - outside the scope of this post. I recommend that you only add this Client ID for testing and remove it in production.






