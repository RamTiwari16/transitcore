/*
  Purpose:      Status codes by category, so the UI can populate status
                dropdowns for Vehicles/Drivers/Trips/Shipments/Invoices
                without hardcoding IDs.
  Author:       TransitCore rebuild
  Date:         2026-09-11
  Dependencies: 005_lookup_extended.sql
*/
-- Procs keep the QUOTED_IDENTIFIER setting they were created with; tables with filtered indexes reject writes from procs created with it OFF.
SET QUOTED_IDENTIFIER ON;
GO
SET NOCOUNT ON;
GO

IF OBJECT_ID('lookup.usp_GetStatusCodes', 'P') IS NOT NULL
    DROP PROCEDURE lookup.usp_GetStatusCodes;
GO

CREATE PROCEDURE lookup.usp_GetStatusCodes
    @Category NVARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        SELECT Id, Category, Code, Name, SortOrder
        FROM lookup.StatusCodes
        WHERE Category = @Category AND IsDeleted = 0
        ORDER BY SortOrder;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END
GO
