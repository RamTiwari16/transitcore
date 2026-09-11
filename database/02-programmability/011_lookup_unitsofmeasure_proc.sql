/*
  Purpose:      Units of measure list, for shipment item quantity units.
  Author:       TransitCore rebuild
  Date:         2026-09-11
  Dependencies: 005_lookup_extended.sql
*/
SET NOCOUNT ON;
GO

IF OBJECT_ID('lookup.usp_GetUnitsOfMeasure', 'P') IS NOT NULL
    DROP PROCEDURE lookup.usp_GetUnitsOfMeasure;
GO

CREATE PROCEDURE lookup.usp_GetUnitsOfMeasure
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        SELECT Id, Code, Name
        FROM lookup.UnitsOfMeasure
        WHERE IsDeleted = 0
        ORDER BY Name;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END
GO
