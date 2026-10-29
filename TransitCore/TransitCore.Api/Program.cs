using System.Diagnostics;
using System.Text;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.IdentityModel.Tokens;
using Microsoft.OpenApi.Models;
using TransitCore.Api.ErrorHandling;
using TransitCore.Api.Startup;
using TransitCore.Application.Jwt;
using TransitCore.Infrastructure.DependencyInjection;

var builder = WebApplication.CreateBuilder(args);

// Must exist before builder.Build() - IWebHostEnvironment.WebRootFileProvider
// is resolved once at host build time, and if wwwroot doesn't exist yet at
// that point, UseStaticFiles() below serves 404s forever even after
// LocalFileStorageService creates the folder on first upload (the file
// provider doesn't retroactively notice a directory that didn't exist when
// it was constructed).
Directory.CreateDirectory(Path.Combine(builder.Environment.ContentRootPath, "wwwroot"));

builder.Services.AddControllers();

builder.Services.AddExceptionHandler<ApiExceptionHandler>();
builder.Services.AddProblemDetails();

builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen(c =>
{
    c.SwaggerDoc("v1", new OpenApiInfo
    {
        Title = "TransitCore API",
        Version = "v1"
    });

    c.AddSecurityDefinition("Bearer", new OpenApiSecurityScheme
    {
        Name = "Authorization",
        Type = SecuritySchemeType.Http,
        Scheme = "bearer",
        BearerFormat = "JWT",
        In = ParameterLocation.Header,
        Description = "Paste JWT Token Only"
    });

    c.AddSecurityRequirement(new OpenApiSecurityRequirement
    {
        {
            new OpenApiSecurityScheme
            {
                Reference = new OpenApiReference
                {
                    Type = ReferenceType.SecurityScheme,
                    Id = "Bearer"
                }
            },
            Array.Empty<string>()
        }
    });
});

builder.Services.AddCors(options =>
{
    options.AddPolicy("AllowAll", policy =>
    {
        policy.AllowAnyOrigin().AllowAnyMethod().AllowAnyHeader();
    });
});

// Infrastructure: SqlDataAccess, repositories, password hasher, JWT token generator.
builder.Services.AddInfrastructure(builder.Configuration, builder.Environment.ContentRootPath);

// JWT bearer scheme wiring stays here (the composition root), not in
// Application/Infrastructure, so those layers stay free of ASP.NET Core
// hosting dependencies.
var jwtOptions = builder.Configuration.GetSection(JwtOptions.SectionName).Get<JwtOptions>() ?? new JwtOptions();

builder.Services.AddAuthentication(JwtBearerDefaults.AuthenticationScheme)
    .AddJwtBearer(options =>
    {
        options.TokenValidationParameters = new TokenValidationParameters
        {
            ValidateIssuer = true,
            ValidateAudience = true,
            ValidateLifetime = true,
            ValidateIssuerSigningKey = true,
            ValidIssuer = jwtOptions.Issuer,
            ValidAudience = jwtOptions.Audience,
            IssuerSigningKey = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(jwtOptions.Key))
        };
    });

builder.Services.AddAuthorization();

var app = builder.Build();

// Standalone single-file exe scenario only (see win-x64-standalone.pubxml)
// - a normal `dotnet run`/IIS/container deployment is always Development
// or an explicitly-set environment, never the bare "Production" default a
// double-clicked exe with no ASPNETCORE_ENVIRONMENT set falls back to.
// First launch ever: creates and seeds TransitCoreDb on the local
// LocalDB instance. Every launch after that is a fast no-op existence
// check - see DatabaseBootstrapper.
if (!app.Environment.IsDevelopment())
{
    var connectionString = app.Configuration.GetConnectionString("TransitCoreDb")
        ?? throw new InvalidOperationException("ConnectionStrings:TransitCoreDb is not configured.");
    await DatabaseBootstrapper.EnsureCreatedAsync(connectionString, app.Logger);
}

app.UseExceptionHandler();

app.UseSwagger();
app.UseSwaggerUI();

// Skipped in Development: the dev frontend deliberately targets the HTTP
// endpoint (no trusted local dev cert set up - see PLAN.md). Redirecting to
// HTTPS here would run before UseCors below, so every request would bounce
// to https://localhost:7195 with no CORS headers on the redirect response -
// the browser reports that as a CORS failure even though the policy is wide open.
if (!app.Environment.IsDevelopment())
{
    app.UseHttpsRedirection();
}

app.UseCors("AllowAll");

// Serves uploaded proof-of-delivery photos/signatures and trip documents
// from wwwroot/uploads (see LocalFileStorageService) - needs no
// authentication of its own since the paths are opaque GUIDs, same trust
// model as an S3/blob URL would have.
app.UseStaticFiles();

app.UseAuthentication();
app.UseAuthorization();

app.MapControllers();

// Any request that isn't an API route or a real static file (e.g. a
// client-side Angular route like /ops/trips/5, opened directly or
// refreshed) falls back to index.html so the Angular router can take over.
// Harmless no-op in Development, where wwwroot has no index.html because
// the Angular dev server (ng serve) serves the SPA separately on its own port.
app.MapFallbackToFile("index.html");

if (!app.Environment.IsDevelopment())
{
    // Best-effort - launching the desktop's default browser is a
    // convenience for the standalone single-user exe, not something the
    // server's own correctness depends on. If it fails (no desktop
    // session, unusual environment, etc.) the server still runs fine and
    // the URL is right there in the console output.
    app.Lifetime.ApplicationStarted.Register(() =>
    {
        var url = app.Urls.FirstOrDefault();
        if (url is null)
            return;

        try
        {
            Process.Start(new ProcessStartInfo(url) { UseShellExecute = true });
        }
        catch (Exception ex)
        {
            app.Logger.LogWarning(ex, "Could not auto-open the browser. Open {Url} manually.", url);
        }
    });
}

app.Run();
