using Npgsql;

static class DatabaseConfiguration
{
    public static string ConnectionString(IConfiguration configuration, string contentRoot)
    {
        var explicitConnection = configuration.GetConnectionString("Postgres");
        if (!string.IsNullOrWhiteSpace(explicitConnection)) return explicitConnection;

        var values = ReadEnvFile(Path.Combine(contentRoot, ".env"));
        string? Get(string name) => Environment.GetEnvironmentVariable(name) ?? values.GetValueOrDefault(name);
        var user = Get("DB_USER");
        var password = Get("DB_PASSWORD");
        var database = Get("DB_NAME");
        if (string.IsNullOrWhiteSpace(user) || string.IsNullOrEmpty(password) || string.IsNullOrWhiteSpace(database))
            throw new InvalidOperationException("Configure DB_USER, DB_PASSWORD and DB_NAME in api/.env or environment variables.");

        var portText = Get("DB_PORT") ?? "5432";
        if (!int.TryParse(portText, out var port) || port is < 1 or > 65535)
            throw new InvalidOperationException("DB_PORT must be a valid TCP port.");

        return new NpgsqlConnectionStringBuilder
        {
            Host = Get("DB_HOST") ?? "localhost",
            Port = port,
            Database = database,
            Username = user,
            Password = password
        }.ConnectionString;
    }

    static Dictionary<string, string> ReadEnvFile(string path)
    {
        var result = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase);
        if (!File.Exists(path)) return result;
        foreach (var rawLine in File.ReadLines(path))
        {
            var line = rawLine.Trim();
            if (line.Length == 0 || line.StartsWith('#')) continue;
            if (line.StartsWith("export ", StringComparison.Ordinal)) line = line[7..].TrimStart();
            var separator = line.IndexOf('=');
            if (separator <= 0) throw new FormatException("Invalid entry in api/.env.");
            var key = line[..separator].Trim();
            var value = line[(separator + 1)..].Trim();
            if (value.StartsWith('"') || value.StartsWith('\''))
            {
                if (value.Length < 2 || value[^1] != value[0]) throw new FormatException("Invalid quoted value in api/.env.");
                value = value[1..^1];
            }
            result[key] = value;
        }
        return result;
    }
}
