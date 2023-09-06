# Service to service Authentication with Managed Identity

This is a labour of love. I dream of a day when I can control access to my own APIs in Azure just as easily as I can control access to other Azure resources. I want to be able to say "allow this Managed Identity to access this API" and have it just work. I want to be able to do this declaratively, using Bicep or ARM, and not have to write code to do it. 

We're not quite there, yet, but we're really quite close. In this repository I am showing you two ways to achieve this.

## The Use case

![Diagram showing a front end API connecting to a backend API](usecase.drawio.svg)

The concept is that we have some kind of front-end service that can be accessed by external users or systems. We then have a separate "Back End API" which should *only* be accessed by the Front End service and never by any users or any other service. *This example is obviously simplified. In real-world scenarios there will be more parts and more reasons to do something like this*. 

You should, obviously, also use network isolation to restrict traffic to the Back End. In high-security scenarios, the network isolation is not enough and you will want inter-service authentication *as well*. 

What we are trying to do here is add authentication to the Back End API so we can restrict access to *only* the Front End in the simplest way possible. There are lots of ways we can do this in code, but the aim here is to use as much built-in Azure functionality as possible and make as few code changes as possible.

In the Azure Portal, it is easy to control access to, say, a Storage Account by assigning specific RBAC roles for that Storage Account to a particular Managed Identity. The goal here is to make it just as easy to control access to an API hosted on an App Service.

It's entirely possible to do this, it's just not as smooth as you'd like it to be. You end up having to combine PowerShell or Azure CLI with Bicep. There are ways to integrate those, as well, but it gets hard. It is also not possible to do this entirely in the portal - you have to use some level of scripting or bicep, whichever approach you take, which just raises the barrier to getting started.

## Managed Identity
Azure has the amazing concept of Managed Identity, which allows you to let Azure manage a "user" for each of your Azure services or VMs and use that "user" to access Azure resources.
The way this is implemented means you no longer have to use secrets or passwords to authenticate to, say, a database. Your app can login to the database "as itself" without needing to know a password at all.

Wouldn't it be amazing if you could also use this approach to do service-to-service authentiation between your own services? What if you could specify "allow this web server to access this API" declaratively, in the same way you say "allow this web server to access this storage account".

Well, you can. It's just not as easy as it should be. 
There are two different ways you can achieve this. 

- Using App Roles: You can control access without code changes in the back end. However, with the App Role approach, you can choose to be more fine-grained, by controlling specific actions in code.
- Using the `allowedPrincipals` property: You can only control which Managed Identities can access the service.


For the purposes of this conversation and the code in this repository, we have the following:
- A web called "Back End". We are going to protect this so you need to present an authentication token for it to respond.
- A web app called "Front End". This will call the Backend, using Managed Identity.
- A "Tester" console app you can use locally as an alternative to "Front End", if you like.

This approach will use Azure Managed Identity on the "Front End" service and use App Service Authentication on the "Back End". The benefit of this approach is that you do not need any code at all on the Back End - it's all handled before the request even reaches your code.
You could, instead, implement authentication inside the Back End application. That is an entirely valid approach and the choice between the two methods depends on your particular circumstances.

## The simple approach
[This post](https://awh.net/blog/securing-api-to-api-azure-app-services-using-managed-identity) explains how to set this up using the portal. Some of the specifics have changed, but it's easy enough to follow.
The only thing is the "scope" parameter that will be different. In the example they use "https://your-integrationapi-url.azurewebsites.net/.default". That is no longer the default: If you follow the blog post, once you have set up authentication, following the link from the App Service Authentication to the App Registration. Then go to "Expose an API". At the top you will see something like "api://123". Take that value and append "./default" to end up with something like "api://123./default". 

**However** that approach will allow *any* user or Managed Identity in the tenant to successfully authenticate to your Service. That may be fine, depending on your requirements.

## But I want more
I want two more things:

1. I want to control exactly which Managed Identities can access my Service.
2. I want to set this up using Bicep so it is repeatable.

This repository has everything you need to set this up, including code to test it.

### Limiting which Managed Identities can access my Service
It should be pretty simple to control which users and managed identities can connect to your Service - right? When you look into this, it is rather more complicated. If you let the Azure App Service create the App Service Registration for you, it will have also created an Enterprise Application. When you have such an Enterprise Application, you can control which users can authenticate to the app by setting "Assignment required" to "true" and then "add users" in the Enterprise Application. *Unfortunately* it is not possible to add a Managed Identity to the list of allowed users using the Azure Portal. If you set "Assignment Required", your Front End application will no longer be able to connect. Worse, you will get a 500 error, implying this is an unhandled scenario. 

This is where you have two choices:
- You can create an App Role on the Back End Enterprise Application and give the Front End Application permissions to that App Role. This makes the Managed Identity "assigned" and it can log in again. *This is the approach I recommend - it is the most "canonical" and it has the benefit of allowing you to control access to specific actions in the Back End, if you want to.*.  
Note, also, that normal users can be "assigned" without first creating any App Roles. Managed Identities cannot be assigned without first creating an App Role.  
- Alternatively, you can set "Assignment Required" to *false* and instead use the `allowedPrincipals` property on the App Service Authentication. This allows all AD users to obtain a token, but it will be checked against an allow list in the app service when they try to use the token to access the service.

### I want to set this up using Bicep
To set up Authentication on an App Service using ARM or Bicep, you need to first create an App Registration. This is similar to Option 2 in [Microsoft's docs on how to set this up via the portal](https://learn.microsoft.com/en-us/azure/app-service/configure-authentication-provider-aad?tabs=workforce-tenant#-option-2-use-an-existing-registration-created-separately).

Alas, it is not possible to create an App Registration through ARM/Bicep for some reason so you have to do it manually or use Powershell (this seems to be by design, somehow, because it's a Tenant thing but that doesn't make sense to me, given how it is used).

Detailed steps below.

## Key concepts

### App Registration and Authentication

In order for a an App Service to have "Authentication" (the built-in type) it needs an App Registration created in the Tenant. When you set up Authentication in the portal, an App Registration is automatically created for you. This will also create an Enterprise Application (i.e. an associated Service Principal), set up an API Permission and create a Secret and store this in a config setting on the App Service. Most of this not needed to make inbound auth work. The App Registration is always needed and the Enterprise Application is needed if you want to use App Roles, but not if you use `allowedPrincipals`.

The concept of App Registrations is extremely broad and could probably fill a whole book and I won't attempt to explain it here. Note that I am not describing cross-tenant here. I suspect the App Role approach should be possible to make work cross-tenant, but I have not tried it.

### Managed Identity and Principals
A *Principal* in Azure AD is any kind of "user" in that Azure AD Tenant.
A *Service Principal* is specifically a "user" that is really an application and not a person. 
*Managed Identity* is a kind of Service Principal. They can be "System assigned" or "User Managed", but in either case they are linked to either a specific Azure resource or at least a Resource group. For many purposes they can be treated just like an ordinary user; You can give a Managed Identity Azure RBAC roles and give it access to different things.

There is a *lot* more that can be said to explain all of this, but that is outside the scope of this post. It is a big, complicated, topic and worth learning about but you can get by without knowing it all for the purposes of what we are doing today.



[Using App Roles](./UsingAppRoles.md)

[Using allowedPrincipals](./UsingAllowedPrincipals.md)
