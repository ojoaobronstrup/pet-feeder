using System.Net.Http.Json;
using System.Security.Cryptography;
using System.Text;
using System.Text.Json;
using Npgsql;

var builder = WebApplication.CreateBuilder(args);
builder.Services.AddHttpClient();
builder.Services.AddSingleton<FeederStore>();
builder.Services.AddHostedService<Scheduler>();
builder.Services.AddCors(options => options.AddDefaultPolicy(policy => policy.AllowAnyOrigin().AllowAnyHeader().AllowAnyMethod()));
var app = builder.Build();
var verifiedTokens = new System.Collections.Concurrent.ConcurrentDictionary<string, DateTimeOffset>();
// The prototype can be reached from a local Flutter web build. Deploy behind HTTPS.
app.UseCors();

async Task<bool> GoogleUser(HttpContext context, IHttpClientFactory clients, IConfiguration configuration)
{
    var clientId = configuration["Google:ClientId"];
    var allowedEmail = configuration["Google:AllowedEmail"];
    var logger = context.RequestServices.GetRequiredService<ILoggerFactory>().CreateLogger("GoogleAuth");
    var authorization = context.Request.Headers.Authorization.ToString();
    if (string.IsNullOrWhiteSpace(clientId) || string.IsNullOrWhiteSpace(allowedEmail))
    {
        logger.LogError("Google auth is not configured. Set Google__ClientId and Google__AllowedEmail before starting the API.");
        return false;
    }
    if (!authorization.StartsWith("Bearer ", StringComparison.OrdinalIgnoreCase))
    {
        logger.LogWarning("Google auth request did not include a Bearer token.");
        return false;
    }
    var token = authorization[7..].Trim();
    if (token.Length == 0 || token.Length > 8192)
    {
        logger.LogWarning("Google auth request included an empty or oversized token.");
        return false;
    }
    var cacheKey = Convert.ToHexString(SHA256.HashData(Encoding.UTF8.GetBytes(token)));
    if (verifiedTokens.TryGetValue(cacheKey, out var until) && until > DateTimeOffset.UtcNow) return true;
    try
    {
        using var response = await clients.CreateClient().GetAsync("https://oauth2.googleapis.com/tokeninfo?id_token=" + Uri.EscapeDataString(token), context.RequestAborted);
        if (!response.IsSuccessStatusCode)
        {
            logger.LogWarning("Google rejected the ID token with status {StatusCode}.", (int)response.StatusCode);
            return false;
        }
        using var data = await JsonDocument.ParseAsync(await response.Content.ReadAsStreamAsync(context.RequestAborted), cancellationToken: context.RequestAborted);
        var root = data.RootElement;
        long expiry = 0;
        var hasEmail = root.TryGetProperty("email", out var email);
        var hasVerified = root.TryGetProperty("email_verified", out var verified);
        var hasAudience = root.TryGetProperty("aud", out var aud);
        var hasIssuer = root.TryGetProperty("iss", out var issuer);
        var hasExpiry = root.TryGetProperty("exp", out var exp) && long.TryParse(exp.ToString(), out expiry);
        var validEmail = hasEmail && string.Equals(email.GetString(), allowedEmail, StringComparison.OrdinalIgnoreCase);
        var validVerified = hasVerified && string.Equals(verified.ToString(), "true", StringComparison.OrdinalIgnoreCase);
        var validAudience = hasAudience && aud.GetString() == clientId;
        var validIssuer = hasIssuer && (issuer.GetString() == "https://accounts.google.com" || issuer.GetString() == "accounts.google.com");
        var validExpiry = hasExpiry && expiry > DateTimeOffset.UtcNow.ToUnixTimeSeconds();
        var valid = validEmail && validVerified && validAudience && validIssuer && validExpiry;
        if (!valid)
        {
            logger.LogWarning("Google ID token validation failed. EmailAllowed={EmailAllowed}, EmailVerified={EmailVerified}, AudienceMatchesApi={AudienceMatchesApi}, IssuerValid={IssuerValid}, TokenNotExpired={TokenNotExpired}. Expected audience is API's Google:ClientId; no token or email values are logged.", validEmail, validVerified, validAudience, validIssuer, validExpiry);
        }
        if (valid) {
            if (verifiedTokens.Count >= 128) verifiedTokens.Clear();
            verifiedTokens[cacheKey] = DateTimeOffset.FromUnixTimeSeconds(expiry) < DateTimeOffset.UtcNow.AddSeconds(30) ? DateTimeOffset.FromUnixTimeSeconds(expiry) : DateTimeOffset.UtcNow.AddSeconds(30);
        }
        return valid;
    }
    catch (Exception e) when (e is HttpRequestException or TaskCanceledException or JsonException)
    {
        logger.LogWarning("Google ID token validation could not complete: {ExceptionType}.", e.GetType().Name);
        return false;
    }
}

app.MapGet("/api/feeder", async (HttpContext ctx, IHttpClientFactory clients, IConfiguration config, FeederStore store) =>
    await GoogleUser(ctx, clients, config) ? Results.Ok(store.Snapshot()) : Results.Unauthorized());
app.MapPut("/api/feeder/power", async (PowerRequest request, HttpContext ctx, IHttpClientFactory clients, IConfiguration config, FeederStore store) =>
{
    if (!await GoogleUser(ctx, clients, config)) return Results.Unauthorized();
    return store.SetPower(request.Active) ? Results.Ok(store.Snapshot()) : Results.Conflict(new { error = "Alimentador offline ou ocupado" });
});
app.MapPost("/api/feeder/feed", async (HttpContext ctx, IHttpClientFactory clients, IConfiguration config, FeederStore store) =>
{
    if (!await GoogleUser(ctx, clients, config)) return Results.Unauthorized();
    return store.Feed() ? Results.Ok(store.Snapshot()) : Results.Conflict(new { error = "Alimentador offline ou ocupado." });
});
app.MapGet("/api/feeder/history", async (DateTimeOffset? from, DateTimeOffset? to, string? origin, string? status, HttpContext ctx, IHttpClientFactory clients, IConfiguration config, FeederStore store) =>
{
    if (!await GoogleUser(ctx, clients, config)) return Results.Unauthorized();
    if (from.HasValue && to.HasValue && from > to) return Results.BadRequest(new { error = "Intervalo inválido." });
    return Results.Ok(store.History(from, to, origin, status));
});
app.MapGet("/api/feeder/schedules", async (HttpContext ctx, IHttpClientFactory clients, IConfiguration config, FeederStore store) =>
    await GoogleUser(ctx, clients, config) ? Results.Ok(store.Schedules()) : Results.Unauthorized());
app.MapPost("/api/feeder/schedules", async (ScheduleRequest request, HttpContext ctx, IHttpClientFactory clients, IConfiguration config, FeederStore store) =>
{
    if (!await GoogleUser(ctx, clients, config)) return Results.Unauthorized();
    if (request.ScheduledAt <= DateTimeOffset.UtcNow.AddSeconds(5)) return Results.BadRequest(new { error = "Escolha um horário futuro." });
    var schedule = store.AddSchedule(request.ScheduledAt);
    return schedule is null ? Results.Conflict(new { error = "Já existe um agendamento neste horário." }) : Results.Ok(schedule);
});
app.MapDelete("/api/feeder/schedules/{id:guid}", async (Guid id, HttpContext ctx, IHttpClientFactory clients, IConfiguration config, FeederStore store) =>
{
    if (!await GoogleUser(ctx, clients, config)) return Results.Unauthorized();
    return store.Cancel(id) ? Results.NoContent() : Results.NotFound();
});
app.MapPost("/api/device/poll", (PollRequest request, HttpContext ctx, IConfiguration config, FeederStore store) =>
{
    var expected = config["Device:ApiKey"];
    var header = ctx.Request.Headers.Authorization.ToString();
    var supplied = header.StartsWith("Bearer ", StringComparison.OrdinalIgnoreCase) ? header[7..] : "";
    if (string.IsNullOrWhiteSpace(expected) || !CryptographicOperations.FixedTimeEquals(Encoding.UTF8.GetBytes(expected), Encoding.UTF8.GetBytes(supplied))) return Results.Unauthorized();
    return Results.Ok(store.Poll(request));
});
app.Run();

record PowerRequest(bool Active);
record ScheduleRequest(DateTimeOffset ScheduledAt);
record PollRequest(bool Active, long? AppliedRevision);
record DeviceResponse(bool Active, long Revision, int PulseMs);
record FeederSnapshot(bool Online, bool? Active, bool DesiredActive, DateTimeOffset? LastSeenAt);
class FeedingSchedule { public Guid Id { get; set; } = Guid.NewGuid(); public DateTimeOffset ScheduledAt { get; set; } public string Status { get; set; } = "pending"; public long? Revision { get; set; } }
class HistoryEvent { public Guid Id { get; set; } = Guid.NewGuid(); public DateTimeOffset OccurredAt { get; set; } = DateTimeOffset.UtcNow; public string Origin { get; set; } = "manual"; public string Status { get; set; } = "requested"; public bool Active { get; set; } public DateTimeOffset? ScheduledAt { get; set; } public long? Revision { get; set; } }
class StoredState { public List<FeedingSchedule> Schedules { get; set; } = []; public long Revision { get; set; } public List<HistoryEvent> History { get; set; } = []; }

class FeederStore : IDisposable
{
    readonly object gate = new();
    readonly NpgsqlConnection connection;
    bool databaseFailed;
    readonly StoredState state;
    DateTimeOffset? lastSeen;
    bool? active;
    bool desired;
    DateTimeOffset? pulseEnds;
    public FeederStore(IConfiguration configuration, IWebHostEnvironment env)
    {
        var connectionString = DatabaseConfiguration.ConnectionString(configuration, env.ContentRootPath);
        connection = new NpgsqlConnection(connectionString);
        connection.Open();
        using (var cmd = new NpgsqlCommand("SELECT pg_try_advisory_lock(734501829)", connection))
            if (!(bool)cmd.ExecuteScalar()!) throw new InvalidOperationException("Another API instance owns the feeder database.");
        using (var cmd = new NpgsqlCommand("CREATE TABLE IF NOT EXISTS feeder_state (id integer PRIMARY KEY CHECK (id = 1), data jsonb NOT NULL)", connection)) cmd.ExecuteNonQuery();
        using var load = new NpgsqlCommand("SELECT data::text FROM feeder_state WHERE id = 1", connection);
        var json = load.ExecuteScalar() as string;
        if (json is null)
        {
            var path = configuration["Prototype:DataFile"] ?? Path.Combine(env.ContentRootPath, "prototype-data.json");
            state = File.Exists(path) ? JsonSerializer.Deserialize<StoredState>(File.ReadAllText(path)) ?? new() : new();
            // The legacy file has no event timestamps; preserve schedules without inventing history.
        }
        else state = JsonSerializer.Deserialize<StoredState>(json) ?? throw new InvalidOperationException("Invalid feeder state in PostgreSQL.");
        // A reboot cannot establish that an earlier dispatched command reached the device.
        foreach (var item in state.Schedules.Where(s => s.Status == "pending" && s.ScheduledAt <= DateTimeOffset.UtcNow)) { item.Status = "missed"; AddHistory("scheduled", "missed", true, item.ScheduledAt); }
        MarkUnconfirmedManual();
        foreach (var item in state.Schedules.Where(s => s.Status == "dispatched")) { item.Status = "missed"; AddHistory("scheduled", "missed", true, item.ScheduledAt, item.Revision); }
        state.Revision++;
        Save();
    }
    bool Online => lastSeen.HasValue && DateTimeOffset.UtcNow - lastSeen.Value < TimeSpan.FromSeconds(15);
    void MarkUnconfirmedManual()
    {
        var unresolved = state.History.Where(e => e.Origin == "manual" && e.Status == "requested" && !state.History.Any(result => result.Origin == "manual" && (result.Status == "confirmed" || result.Status == "missed") && result.Revision == e.Revision)).ToArray();
        foreach (var item in unresolved) AddHistory("manual", "missed", item.Active, revision: item.Revision);
    }
    void AddHistory(string origin, string status, bool value, DateTimeOffset? scheduledAt = null, long? revision = null) => state.History.Add(new HistoryEvent { Origin = origin, Status = status, Active = value, ScheduledAt = scheduledAt, Revision = revision });
    void CheckDatabase()
    {
        if (databaseFailed) throw new InvalidOperationException("Database connection failed; restart the API after restoring PostgreSQL.");
        try { using var cmd = new NpgsqlCommand("SELECT 1", connection); cmd.ExecuteScalar(); }
        catch { databaseFailed = true; desired = false; pulseEnds = null; throw; }
    }
    void Save()
    {
        try { using var cmd = new NpgsqlCommand("INSERT INTO feeder_state (id, data) VALUES (1, @data::jsonb) ON CONFLICT (id) DO UPDATE SET data = EXCLUDED.data", connection); cmd.Parameters.AddWithValue("data", JsonSerializer.Serialize(state)); cmd.ExecuteNonQuery(); }
        catch { databaseFailed = true; desired = false; pulseEnds = null; throw; }
    }
    public object[] History(DateTimeOffset? from, DateTimeOffset? to, string? origin, string? status) { lock (gate) { CheckDatabase(); return state.History.Where(e => (!from.HasValue || e.OccurredAt >= from) && (!to.HasValue || e.OccurredAt <= to) && (origin is null || e.Origin == origin) && (status is null || e.Status == status)).OrderByDescending(e => e.OccurredAt).Select(e => (object)new { e.Id, e.OccurredAt, e.Origin, e.Status, e.Active, e.ScheduledAt }).ToArray(); } }
    public void Dispose() => connection.Dispose();
    public FeederSnapshot Snapshot() { lock (gate) { CheckDatabase(); return new(Online, Online ? active : null, desired, lastSeen); } }
    public bool SetPower(bool value) { lock (gate) { CheckDatabase(); if (!Online || pulseEnds.HasValue) return false; desired = value; pulseEnds = null; state.Revision++; AddHistory("manual", "requested", value, revision: state.Revision); Save(); return true; } }
    public bool Feed() { lock (gate) { CheckDatabase(); if (!Online || desired || active == true) return false; desired = true; pulseEnds = DateTimeOffset.UtcNow.AddSeconds(10); state.Revision++; AddHistory("manual", "requested", true, revision: state.Revision); Save(); return true; } }
    public object[] Schedules() { lock (gate) { CheckDatabase(); return state.Schedules.Select(s => (object)new { s.Id, s.ScheduledAt, s.Status }).ToArray(); } }
    public object? AddSchedule(DateTimeOffset at) { lock (gate) { CheckDatabase(); if (state.Schedules.Any(s => s.Status == "pending" && Math.Abs((s.ScheduledAt - at).TotalSeconds) < 60)) return null; var s = new FeedingSchedule { ScheduledAt = at.ToUniversalTime() }; state.Schedules.Add(s); AddHistory("scheduled", "requested", true, s.ScheduledAt); Save(); return new { s.Id, s.ScheduledAt, s.Status }; } }
    public bool Cancel(Guid id) { lock (gate) { CheckDatabase(); var s = state.Schedules.FirstOrDefault(s => s.Id == id && s.Status == "pending"); if (s is null) return false; s.Status = "cancelled"; AddHistory("scheduled", "cancelled", true, s.ScheduledAt); Save(); return true; } }
    public DeviceResponse Poll(PollRequest request) { lock (gate) { CheckDatabase(); lastSeen = DateTimeOffset.UtcNow; active = request.Active; var changed = false; if (pulseEnds <= DateTimeOffset.UtcNow) { MarkUnconfirmedManual(); desired = false; pulseEnds = null; state.Revision++; changed = true; } foreach (var s in state.Schedules.Where(s => s.Status == "dispatched" && s.Revision == request.AppliedRevision && request.Active)) { s.Status = "executed"; AddHistory("scheduled", "confirmed", true, s.ScheduledAt, s.Revision); changed = true; } var manual = state.History.LastOrDefault(e => e.Origin == "manual" && e.Status == "requested" && e.Revision == request.AppliedRevision && e.Active == request.Active); if (manual != null && !state.History.Any(e => e.Origin == "manual" && (e.Status == "confirmed" || e.Status == "missed") && e.Revision == manual.Revision)) { AddHistory("manual", "confirmed", manual.Active, revision: manual.Revision); changed = true; } if (changed) Save(); return new(desired, state.Revision, pulseEnds.HasValue ? Math.Max(0, (int)(pulseEnds.Value - DateTimeOffset.UtcNow).TotalMilliseconds) : 0); } }
    public void Tick() { lock (gate) { CheckDatabase(); var now = DateTimeOffset.UtcNow; var changed = false; if (!Online && desired) { MarkUnconfirmedManual(); desired = false; pulseEnds = null; state.Revision++; changed = true; } if (pulseEnds <= now) { MarkUnconfirmedManual(); desired = false; pulseEnds = null; state.Revision++; changed = true; } foreach (var s in state.Schedules.Where(s => s.Status == "pending" && s.ScheduledAt <= now)) { if (!Online || desired || active == true || now - s.ScheduledAt > TimeSpan.FromSeconds(15)) { s.Status = "missed"; AddHistory("scheduled", "missed", true, s.ScheduledAt); } else { desired = true; pulseEnds = now.AddSeconds(10); s.Revision = ++state.Revision; s.Status = "dispatched"; AddHistory("scheduled", "dispatched", true, s.ScheduledAt, s.Revision); } changed = true; } foreach (var s in state.Schedules.Where(s => s.Status == "dispatched" && s.ScheduledAt.AddSeconds(15) < now)) { s.Status = "missed"; AddHistory("scheduled", "missed", true, s.ScheduledAt, s.Revision); changed = true; } if (changed) Save(); } }
}
class Scheduler(FeederStore store, ILogger<Scheduler> logger) : BackgroundService
{
    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        using var timer = new PeriodicTimer(TimeSpan.FromSeconds(1));
        try
        {
            while (await timer.WaitForNextTickAsync(stoppingToken)) store.Tick();
        }
        catch (OperationCanceledException) when (stoppingToken.IsCancellationRequested)
        {
            logger.LogInformation("Scheduler stopped.");
        }
    }
}
