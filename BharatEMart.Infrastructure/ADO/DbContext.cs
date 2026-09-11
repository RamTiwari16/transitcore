using Microsoft.Data.SqlClient;
using Microsoft.Extensions.Configuration;
using System;
using System.Collections.Generic;
using System.Data;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using System.Threading.Tasks;
using System.Xml;

namespace PortalService.Infrastructure.ADO
{
    public class DbContext
    {
        private readonly string sqldatasource;

        public DbContext(IConfiguration configuration, string dbName)
        {
            if (string.IsNullOrWhiteSpace(dbName))
                throw new ArgumentException("Database name is required", nameof(dbName));

            sqldatasource = configuration.GetConnectionString(dbName);

            if (string.IsNullOrWhiteSpace(sqldatasource))
                throw new InvalidOperationException($"Connection string for '{dbName}' not found.");
        }

        public string GetConnectionString()
        {
            return sqldatasource;
        }

        public async Task<DataTable> ReturnDtWithProcAsync(string procname, params SqlParameter[] parameters)
        {
            using (SqlConnection conn = new SqlConnection(sqldatasource))
            {
                await conn.OpenAsync();
                using (SqlCommand cmd = new SqlCommand(procname, conn))
                {
                    cmd.CommandType = CommandType.StoredProcedure;
                    cmd.CommandTimeout = 300;
                    if (parameters != null)
                    {
                        cmd.Parameters.AddRange(parameters);
                    }
                    using (SqlDataAdapter adapter = new SqlDataAdapter(cmd))
                    {
                        DataTable dt = new DataTable();
                        adapter.Fill(dt);
                        return dt;
                    }
                }
            }
        }

        public async Task<DataSet> ReturnDsWithProcAsync(string procName, SqlParameter[] parameters)
        {
            using (var conn = new SqlConnection(sqldatasource))
            using (var cmd = new SqlCommand(procName, conn))
            {
                cmd.CommandType = CommandType.StoredProcedure;
                cmd.Parameters.AddRange(parameters);

                var ds = new DataSet();
                var da = new SqlDataAdapter(cmd);

                await conn.OpenAsync();
                da.Fill(ds);
                return ds;
            }
        }


        public async Task<DataTable> ReturnDtWithQueryAsync(string query)
        {
            using (SqlConnection conn = new SqlConnection(sqldatasource))
            {
                await conn.OpenAsync();
                using (SqlCommand cmd = new SqlCommand(query, conn))
                {
                    cmd.CommandType = CommandType.Text;
                    using (SqlDataAdapter adapter = new SqlDataAdapter(cmd))
                    {
                        DataTable dt = new DataTable();
                        adapter.Fill(dt);
                        return dt;
                    }
                }
            }
        }

        public async Task<object> ExecuteScalarWithProcAsync(string procname, params SqlParameter[] parameters)
        {
            using (SqlConnection conn = new SqlConnection(sqldatasource))
            {
                await conn.OpenAsync();
                using (SqlCommand cmd = new SqlCommand(procname, conn))
                {
                    cmd.CommandType = CommandType.StoredProcedure;
                    if (parameters != null)
                    {
                        cmd.Parameters.AddRange(parameters);
                    }
                    return await cmd.ExecuteScalarAsync();
                }
            }
        }

        public async Task<int> ExecuteNonQueryWithProcAsync(string procname, params SqlParameter[] parameters)
        {
            using (SqlConnection conn = new SqlConnection(sqldatasource))
            {
                await conn.OpenAsync();
                using (SqlCommand cmd = new SqlCommand(procname, conn))
                {
                    cmd.CommandType = CommandType.StoredProcedure;
                    if (parameters != null)
                    {
                        cmd.Parameters.AddRange(parameters);
                    }
                    return await cmd.ExecuteNonQueryAsync();
                }
            }
        }

        public async Task<int> ExecuteNonQueryWithQueryAsync(string query, params SqlParameter[] parameters)
        {
            using (SqlConnection conn = new SqlConnection(sqldatasource))
            {
                await conn.OpenAsync();
                using (SqlCommand cmd = new SqlCommand(query, conn))
                {
                    cmd.CommandType = CommandType.Text;
                    if (parameters != null)
                    {
                        cmd.Parameters.AddRange(parameters);
                    }
                    return await cmd.ExecuteNonQueryAsync();
                }
            }
        }

       
    }
}
