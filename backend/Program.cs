var builder = WebApplication.CreateBuilder(args);
var app = builder.Build();

app.MapGet("/", () => $"Backend says hi at {DateTime.UtcNow} (UTC)");

app.Run();
