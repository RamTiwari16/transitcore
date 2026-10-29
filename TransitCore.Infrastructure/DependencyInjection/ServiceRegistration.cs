using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using TransitCore.Application.Interfaces;
using TransitCore.Application.Jwt;
using TransitCore.Infrastructure.Ado;
using TransitCore.Infrastructure.Files;
using TransitCore.Infrastructure.Jwt;
using TransitCore.Infrastructure.Pdf;
using TransitCore.Infrastructure.Security;

namespace TransitCore.Infrastructure.DependencyInjection;

public static class ServiceRegistration
{
    public static IServiceCollection AddInfrastructure(this IServiceCollection services, IConfiguration configuration, string contentRootPath)
    {
        services.AddScoped(_ => new SqlDataAccess(configuration, "TransitCoreDb"));

        var jwtOptions = configuration.GetSection(JwtOptions.SectionName).Get<JwtOptions>() ?? new JwtOptions();
        services.AddSingleton(jwtOptions);

        services.AddSingleton<IPasswordHasher, PasswordHasher>();
        services.AddSingleton<IJwtTokenGenerator, JwtTokenGenerator>();
        services.AddSingleton<IInvoicePdfGenerator, InvoicePdfGenerator>();
        services.AddSingleton<IConsignmentNotePdfGenerator, ConsignmentNotePdfGenerator>();
        services.AddSingleton<IFileStorageService>(_ => new LocalFileStorageService(contentRootPath));

        // Auto-registers every *Repository class (this assembly) against the
        // Application-layer interface it implements — same convention the
        // reference codebase used.
        services.Scan(scan => scan
            .FromAssemblies(typeof(ServiceRegistration).Assembly)
            .AddClasses(classes => classes.Where(type => type.Name.EndsWith("Repository")))
            .AsImplementedInterfaces()
            .WithScopedLifetime());

        return services;
    }
}
