using System.Net.Http.Headers;
using Azure.Identity;

var builder = WebApplication.CreateBuilder(args);
var app = builder.Build();

var config = app.Configuration;

var backend = config.GetValue<string>("BackendUrl"); // "http://localhost:3000/";
var useAuth = config.GetValue<bool>("BackendUseAuth");
var scope = config.GetValue<string>("BackendAuthScope");


var client = new HttpClient(); // Lazy and bad

app.MapGet("/", async () => {
    try
    {
        var client = new HttpClient();
        if (useAuth)
        {
            var creds = new DefaultAzureCredential();
            // var scope = "api://fl-test-20230713-3.azurewebsites.net/.default";
            var token = await creds.GetTokenAsync(new Azure.Core.TokenRequestContext(new string[] { scope }));
            client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token.Token);
        }
        var backendResponse = await client.GetAsync(backend);
        if (backendResponse.IsSuccessStatusCode)
        {
            var body = await backendResponse.Content.ReadAsStringAsync();
            return $"Front end says that useAuth={useAuth} and backend says: {body}";
        }
        else
        {
            return $"Backend returned {backendResponse.StatusCode} - {backendResponse.ReasonPhrase}. UseAuth={useAuth}.";
        }
    }
    catch (Exception ex)
    {
        return ex.Message; // Never do this in prod!!
    }
});

app.Run();
