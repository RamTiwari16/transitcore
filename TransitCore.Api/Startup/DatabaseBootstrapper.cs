using System.Reflection;
using System.Text.RegularExpressions;
using Microsoft.Data.SqlClient;

namespace TransitCore.Api.Startup;

// Runs on EVERY launch of a standalone published exe (never in
// Development - see Program.cs) to make sure TransitCoreDb, on whatever
// local SQL Server / LocalDB instance the connection string points at, is
// fully created and up to date. Deliberately not a "first run only" gate:
// every script under database/ is already written with IF NOT EXISTS /
// MERGE-based idempotency (the established convention throughout this
// codebase, needed anyway so run-all.sql itself can be re-run safely), so
// running all of them unconditionally on every launch is cheap and has two
// real benefits over a one-shot "does the database exist yet" check - (1)
// self-heals if a previous launch was killed mid-setup (verified by
// testing: an interrupted first run left 46 tables/128 procs created but
// zero seed rows, and a naive "DB exists -> skip forever" gate would have
// left it stuck that way permanently), and (2) a later exe version that
// ships new schema files (e.g. a future phase's) picks them up
// automatically on next launch instead of needing its own separate
// migration-versioning scheme.
//
// Executes the exact same files, in the exact same order, that
// database/run-all.sql runs - read from THAT embedded file's `:r` lines
// rather than a second hardcoded list, so a new numbered file added for a
// future phase is picked up automatically the next time someone remembers
// to add it to run-all.sql (which every phase already does).
public static class DatabaseBootstrapper
{
    private static readonly Regex IncludeLinePattern = new(@"^:r\s+\.\\(?<path>.+\.sql)\s*$", RegexOptions.IgnoreCase | RegexOptions.Multiline);
    private static readonly Regex BatchSeparatorPattern = new(@"^\s*GO\s*$", RegexOptions.IgnoreCase | RegexOptions.Multiline);

    public static async Task EnsureCreatedAsync(string connectionString, ILogger logger, CancellationToken cancellationToken = default)
    {
        var builder = new SqlConnectionStringBuilder(connectionString);
        var databaseName = builder.InitialCatalog;

        builder.InitialCatalog = "master";
        await using (var masterConnection = new SqlConnection(builder.ConnectionString))
        {
            await masterConnection.OpenAsync(cancellationToken);

            await using var checkCommand = new SqlCommand("SELECT DB_ID(@name)", masterConnection);
            checkCommand.Parameters.AddWithValue("@name", databaseName);
            var existingId = await checkCommand.ExecuteScalarAsync(cancellationToken);

            if (existingId != DBNull.Value && existingId is not null)
            {
                logger.LogInformation("Database {DatabaseName} exists - verifying it's fully up to date.", databaseName);
            }
            else
            {
                logger.LogInformation("Database {DatabaseName} not found - creating it now.", databaseName);

                await using var createCommand = new SqlCommand($"CREATE DATABASE [{databaseName}]", masterConnection);
                await createCommand.ExecuteNonQueryAsync(cancellationToken);
            }
        }

        var assembly = Assembly.GetExecutingAssembly();
        var runAllScript = ReadEmbeddedResource(assembly, "Database/run-all.sql");

        await using var appConnection = new SqlConnection(connectionString);
        await appConnection.OpenAsync(cancellationToken);

        foreach (Match match in IncludeLinePattern.Matches(runAllScript))
        {
            // ":r .\01-schema\001_lookup_core.sql" -> "01-schema\001_lookup_core.sql"
            // -> logical name "Database/01-schema\001_lookup_core.sql". Kept
            // backslash-separated (not normalized to '/') because that's
            // literally what MSBuild's %(RecursiveDir) produces for the
            // <EmbeddedResource> LogicalName in the .csproj on Windows -
            // confirmed by inspecting the built assembly's actual
            // manifest resource names, not assumed.
            var relativePath = match.Groups["path"].Value;
            var logicalName = $"Database/{relativePath}";

            logger.LogInformation("Running {File}...", relativePath);
            var script = ReadEmbeddedResource(assembly, logicalName);

            foreach (var batch in SplitIntoBatches(script))
            {
                await using var command = new SqlCommand(batch, appConnection) { CommandTimeout = 120 };
                await command.ExecuteNonQueryAsync(cancellationToken);
            }
        }

        logger.LogInformation("Database {DatabaseName} created and initialized.", databaseName);
    }

    private static IEnumerable<string> SplitIntoBatches(string script) =>
        BatchSeparatorPattern.Split(script).Select(b => b.Trim()).Where(b => b.Length > 0);

    private static string ReadEmbeddedResource(Assembly assembly, string logicalName)
    {
        using var stream = assembly.GetManifestResourceStream(logicalName)
            ?? throw new InvalidOperationException($"Embedded SQL resource '{logicalName}' not found - was it excluded from the build?");

        using var reader = new StreamReader(stream);
        return reader.ReadToEnd();
    }
}
