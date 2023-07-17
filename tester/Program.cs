// See https://aka.ms/new-console-template for more information
using System.Net.Http.Headers;
using Azure.Identity;

Console.WriteLine("Hello, World!");

const string target = "https://fl-isa-uat-backend-uks-as.azurewebsites.net/";

var client = new HttpClient();

var creds = new DefaultAzureCredential();

var scope = "api://fl-isa-uat-uks-as.azurewebsites.net/.default";
Console.WriteLine(scope);

var token = await creds.GetTokenAsync(new Azure.Core.TokenRequestContext(new string[] { scope }));

Console.WriteLine($"Token request: {token.Token}");

client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token.Token);

var result = await client.GetAsync(target);

result.EnsureSuccessStatusCode();

var body = await result.Content.ReadAsStringAsync();

Console.WriteLine(body);
