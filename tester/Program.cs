// See https://aka.ms/new-console-template for more information
using System.Net.Http.Headers;
using Azure.Identity;

Console.WriteLine("Hello, World!");

const string target = "https://fl-s2s-backend.azurewebsites.net/";

var client = new HttpClient();

var creds = new DefaultAzureCredential();

var scope = "api://9545255d-92dd-4cbb-af51-976a4acaa1df/.default";
Console.WriteLine(scope);

var token = await creds.GetTokenAsync(new Azure.Core.TokenRequestContext(new string[] { scope }));

Console.WriteLine($"Token request: {token.Token}");

client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token.Token);

var result = await client.GetAsync(target);

result.EnsureSuccessStatusCode();

var body = await result.Content.ReadAsStringAsync();

Console.WriteLine(body);
