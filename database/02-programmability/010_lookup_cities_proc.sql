/*
  Purpose:      City list for origin/destination dropdowns (Shipments,
                Routes, Customer addresses).
  Author:       TransitCore rebuild
  Date:         2026-09-11
  Dependencies: 005_lookup_extended.sql
*/
SET NOCOUNT ON;
GO

IF OBJECT_ID('lookup.usp_GetCities', 'P') IS NOT NULL
    DROP PROCEDURE lookup.usp_GetCities;
GO

CREATE PROCEDURE lookup.usp_GetCities
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        SELECT ci.Id, ci.Name, ci.CountryId, co.Name AS CountryName
        FROM lookup.Cities ci
        INNER JOIN lookup.Countries co ON co.Id = ci.CountryId
        WHERE ci.IsDeleted = 0
        ORDER BY ci.Name;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END
GO
