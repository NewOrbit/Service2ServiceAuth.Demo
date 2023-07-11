var builder = WebApplication.CreateBuilder(args);
var app = builder.Build();

var config = app.Configuration;

var backend = config.GetValue<string>("BackendUrl"); // "http://localhost:3000/";

var client = new HttpClient(); // Lazy and bad

app.MapGet("/", async () => {
    var backendResponse = await client.GetAsync(backend);
    if (backendResponse.IsSuccessStatusCode)
    {
        var body = await backendResponse.Content.ReadAsStringAsync();
        return body;
    }
    else {
        return $"Backend returned {backendResponse.StatusCode} - {backendResponse.ReasonPhrase}";
    }
});

app.Run();
