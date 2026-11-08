using MQTTnet;
using MQTTnet.Client;
using MQTTnet.Client.Options;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddOpenApi();

var app = builder.Build();

// Configure the HTTP request pipeline.
if (app.Environment.IsDevelopment())
{
    app.MapOpenApi();
}

app.UseHttpsRedirection();

app.MapGet("/power/toggle", async (CancellationToken cancellationToken) =>
{
    using var client = new MqttFactory().CreateMqttClient();
    var options = new MqttClientOptionsBuilder()
        .WithTcpServer("broker.emqx.io", 1883)
        .Build();

    await client.ConnectAsync(options, cancellationToken);

    var message = new MqttApplicationMessageBuilder()
        .WithTopic("qnis/teste")
        .WithPayload("teste")
        .Build();

    await client.PublishAsync(message, cancellationToken);
    await client.DisconnectAsync();

    return Results.Ok("Power toggled");
});

app.Run();
