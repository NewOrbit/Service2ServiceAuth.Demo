using System.Net.Http.Headers;

var builder = WebApplication.CreateBuilder(args);
builder.Services.AddHttpClient();
builder.Services.AddSingleton<BackendTokenProvider>();
var app = builder.Build();

var config = app.Configuration;

var backend = config.GetValue<string>("BackendUrl"); 
var useAuth = config.GetValue<bool>("BackendUseAuth");
var scope = config.GetValue<string>("BackendAuthScope");


var client = new HttpClient(); // Lazy and bad

app.MapGet("/", async (IHttpClientFactory httpClientFactory, BackendTokenProvider tokenProvider) => {
    try
    {
        var client = httpClientFactory.CreateClient();
        if (useAuth)
        {
            var token = await tokenProvider.GetTokenAsync();
            client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token);
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
