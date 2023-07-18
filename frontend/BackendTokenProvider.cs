using Azure.Identity;

internal class BackendTokenProvider
{
    private static Azure.Core.AccessToken? token;
    private static readonly SemaphoreSlim locker = new(1,1);

    private readonly string scope;
    public BackendTokenProvider(IConfiguration configuration)
    {
        ArgumentNullException.ThrowIfNull(configuration, nameof(configuration));
        scope = configuration.GetValue<string>("BackendAuthScope") ?? String.Empty;
        ArgumentException.ThrowIfNullOrEmpty(scope, nameof(scope));     
    }

    public async Task<string> GetTokenAsync()
    {
        if (NeedNewToken)
        {
            await locker.WaitAsync();
            try
            {
                if (NeedNewToken)
                {
                    var creds = new DefaultAzureCredential();
                    token = await creds.GetTokenAsync(new Azure.Core.TokenRequestContext(new string[] { scope }));
                }
            }
            finally
            {
                locker.Release();
            }
        }

        if (token == null) {
            throw new InvalidOperationException("Somehow token is null");
        }

        return token.Value.Token;
    }

    private static bool NeedNewToken => token is null || token.Value.ExpiresOn < DateTimeOffset.Now.AddMinutes(-5);
}