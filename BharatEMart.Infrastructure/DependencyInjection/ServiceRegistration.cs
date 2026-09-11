using System;
using System.Collections.Generic;
using System.Linq;
using System.Reflection;
using System.Text;
using Scrutor;
using System.Threading.Tasks;
using Microsoft.Extensions.DependencyInjection;

namespace PortalService.Infrastructure.DependencyInjection
{
    public static class ServiceRegistration
    {
        //public static IServiceCollection AddInfrastructure(this IServiceCollection services)
        //{
        //    // Register repositories here
        //    //services.AddScoped<ITicketRepository, SqlTicketRepository>();
        //    var infrastructureAssembly = typeof(ServiceRegistration).Assembly;

        //    // Register all *Repository classes
        //    services.Scan(scan => scan
        //        .FromAssemblies(infrastructureAssembly)
        //        .AddClasses(classes => classes.Where(type =>
        //            type.Name.EndsWith("Repository") ||
        //            type.Name.EndsWith("Service"))) // Also register services
        //        .AsImplementedInterfaces()
        //        .WithScopedLifetime()
        //    );


        //    // Add more repositories as needed...
        //    return services;
        //}

        public static IServiceCollection AddInfrastructure(this IServiceCollection services)
        {
            var infrastructureAssembly = typeof(ServiceRegistration).Assembly;

            services.Scan(scan => scan
                .FromAssemblies(infrastructureAssembly)
                .AddClasses(classes => classes.Where(type =>
                    (type.Name.EndsWith("Repository") || type.Name.EndsWith("Service"))
                    
                ))
                .AsImplementedInterfaces()
                .WithScopedLifetime()
            );

            return services;
        }
    }


   

}
