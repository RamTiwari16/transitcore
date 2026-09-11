/*
  Purpose:      Table-valued parameter type for passing a set of branch IDs
                into the user insert/update procedures.
  Author:       TransitCore rebuild
  Date:         2026-09-11
  Dependencies: 002_identity_schema.sql
*/
SET NOCOUNT ON;
GO

IF NOT EXISTS (SELECT 1 FROM sys.types WHERE name = 'IntList_TVP' AND schema_id = SCHEMA_ID('identity'))
    CREATE TYPE identity.IntList_TVP AS TABLE (Id INT NOT NULL PRIMARY KEY);
GO
