using Microsoft.OpenApi.Models;
using Swashbuckle.AspNetCore.SwaggerGen;

using PortalService.Core.Jwt;
using PortalService.Infrastructure.ADO;
using PortalService.Infrastructure.DependencyInjection;

var builder = WebApplication.CreateBuilder(args);


// Controllers
builder.Services.AddControllers();


// Swagger
builder.Services.AddEndpointsApiExplorer();

builder.Services.AddSwaggerGen(c =>
{
    c.SwaggerDoc("v1", new OpenApiInfo
    {
        Title = "BharatEMart API",
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


// CORS
builder.Services.AddCors(options =>
{
    options.AddPolicy("AllowAll", policy =>
    {
        policy
            .AllowAnyOrigin()
            .AllowAnyMethod()
            .AllowAnyHeader();
    });
});


// DB Context
builder.Services.AddTransient<DbContext>(sp =>
{
    var config = sp.GetRequiredService<IConfiguration>();

    return new DbContext(config, "BharatEMart");
});


// JWT Authentication
builder.Services.AddJwtAuthentication(builder.Configuration);


// Authorization
builder.Services.AddAuthorization();


// Infrastructure Services
builder.Services.AddInfrastructure();


var app = builder.Build();


// Swagger
app.UseSwagger();

app.UseSwaggerUI();


// HTTPS
app.UseHttpsRedirection();


// CORS
app.UseCors("AllowAll");


// Authentication
app.UseAuthentication();


// Authorization
app.UseAuthorization();


// Controllers
app.MapControllers();

app.Run();