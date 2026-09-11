/*
  Purpose:      Master script — runs every schema/programmability/seed script
                in dependency order. Requires SQLCMD mode (SSMS: Query menu
                > SQLCMD Mode) because it uses :r include directives.
  Author:       TransitCore rebuild
  Date:         2026-09-11
  Dependencies: TransitCoreDb must already exist (see README.md) and this
                script must be run from the /database folder so the relative
                :r paths resolve.
*/

:setvar SQLCMDMAXVARTYPEWIDTH 0

PRINT '--- 01-schema ---';
:r .\01-schema\001_lookup_core.sql
:r .\01-schema\002_identity_schema.sql
:r .\01-schema\003_identity_tvp.sql
:r .\01-schema\004_ops_schema.sql
:r .\01-schema\005_lookup_extended.sql
:r .\01-schema\006_fleet_schema.sql
:r .\01-schema\007_billing_customers_schema.sql
:r .\01-schema\008_ops_routes_trips_shipments_schema.sql
:r .\01-schema\009_billing_invoicing_schema.sql
:r .\01-schema\010_billing_tvp.sql

PRINT '--- 02-programmability ---';
:r .\02-programmability\001_identity_procs.sql
:r .\02-programmability\002_lookup_procs.sql
:r .\02-programmability\003_identity_user_management_procs.sql
:r .\02-programmability\004_ops_vehicleordermapping_procs.sql
:r .\02-programmability\005_fleet_procs.sql
:r .\02-programmability\006_ops_procs.sql
:r .\02-programmability\007_billing_procs.sql
:r .\02-programmability\008_lookup_statuscodes_proc.sql

PRINT '--- 03-seed ---';
:r .\03-seed\001_lookup_seed.sql
:r .\03-seed\002_identity_seed.sql
:r .\03-seed\003_lookup_extended_seed.sql
:r .\03-seed\004_fleet_seed.sql
:r .\03-seed\005_billing_customers_seed.sql
:r .\03-seed\006_ops_seed.sql
:r .\03-seed\007_billing_invoicing_seed.sql

PRINT '--- done ---';
