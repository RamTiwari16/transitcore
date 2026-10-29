/*
  Purpose:      Global header search - one combined stored procedure that
                substring-matches across all 8 searchable entities (Trips,
                Vehicles, Drivers, Shipments, Routes, Invoices, Customers,
                Users) and returns a small unified result set, capped per
                entity type. No substring search existed anywhere in this
                database before this file - every prior usp_Get* list proc
                only filters by exact FK/status equality.
  Author:       TransitCore rebuild
  Date:         2026-09-22
  Dependencies: 006_fleet_schema.sql, 008_ops_routes_trips_shipments_schema.sql,
                007_billing_customers_schema.sql, 009_billing_invoicing_schema.sql,
                002_identity_schema.sql, 012_ops_phase3_schema.sql (Shipments.TrackingNo)
*/
-- Procs keep the QUOTED_IDENTIFIER setting they were created with; tables with filtered indexes reject writes from procs created with it OFF.
SET QUOTED_IDENTIFIER ON;
GO
SET NOCOUNT ON;
GO

IF OBJECT_ID('dbo.usp_GlobalSearch', 'P') IS NOT NULL
    DROP PROCEDURE dbo.usp_GlobalSearch;
GO

CREATE PROCEDURE dbo.usp_GlobalSearch
    @SearchTerm NVARCHAR(200)
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        -- Escape existing wildcard characters in the raw search term before
        -- wrapping it in our own '%...%' wildcards, so a literal %, _ or [
        -- typed by the user is matched literally instead of acting as a
        -- LIKE wildcard itself.
        DECLARE @Like NVARCHAR(206) =
            '%' + REPLACE(REPLACE(REPLACE(@SearchTerm, '[', '[[]'), '%', '[%]'), '_', '[_]') + '%';

        -- Each branch is a derived table (not a bare parenthesized SELECT) -
        -- T-SQL only allows ORDER BY on a UNION member's SELECT when it's
        -- wrapped this way; the plain-parenthesized form only permits ORDER
        -- BY as the very last clause of the whole statement. ORDER BY here
        -- decides which 5 rows TOP keeps when a branch has more matches
        -- than that; the outer ORDER BY at the very end decides display
        -- order for the combined result the client groups by EntityType.
        SELECT * FROM (
            SELECT TOP (5) 'Trip' AS EntityType, t.Id AS EntityId, r.Name AS Label,
                   CONCAT(v.RegistrationNo, ' / ', d.FullName) AS SubLabel
            FROM ops.Trips t
            INNER JOIN ops.Routes r ON r.Id = t.RouteId
            INNER JOIN fleet.Vehicles v ON v.Id = t.VehicleId
            INNER JOIN fleet.Drivers d ON d.Id = t.DriverId
            WHERE t.IsDeleted = 0
                  AND (r.Name LIKE @Like ESCAPE '[' OR v.RegistrationNo LIKE @Like ESCAPE '[' OR d.FullName LIKE @Like ESCAPE '[')
            ORDER BY r.Name
        ) AS Trips

        UNION ALL

        SELECT * FROM (
            SELECT TOP (5) 'Vehicle' AS EntityType, v.Id AS EntityId, v.RegistrationNo AS Label, CONCAT(v.Make, ' ', v.Model) AS SubLabel
            FROM fleet.Vehicles v
            WHERE v.IsDeleted = 0
                  AND (v.RegistrationNo LIKE @Like ESCAPE '[' OR v.Make LIKE @Like ESCAPE '[' OR v.Model LIKE @Like ESCAPE '[')
            ORDER BY v.RegistrationNo
        ) AS Vehicles

        UNION ALL

        SELECT * FROM (
            SELECT TOP (5) 'Driver' AS EntityType, d.Id AS EntityId, d.FullName AS Label, ISNULL(d.PhoneNo, d.Email) AS SubLabel
            FROM fleet.Drivers d
            WHERE d.IsDeleted = 0
                  AND (d.FullName LIKE @Like ESCAPE '[' OR d.PhoneNo LIKE @Like ESCAPE '[' OR d.Email LIKE @Like ESCAPE '[')
            ORDER BY d.FullName
        ) AS Drivers

        UNION ALL

        SELECT * FROM (
            SELECT TOP (5) 'Shipment' AS EntityType, s.Id AS EntityId, s.TrackingNo AS Label, c.Name AS SubLabel
            FROM ops.Shipments s
            INNER JOIN billing.Customers c ON c.Id = s.CustomerId
            WHERE s.IsDeleted = 0 AND s.TrackingNo LIKE @Like ESCAPE '['
            ORDER BY s.TrackingNo
        ) AS Shipments

        UNION ALL

        SELECT * FROM (
            SELECT TOP (5) 'Route' AS EntityType, r.Id AS EntityId, r.Name AS Label, CONCAT(oc.Name, ' -> ', dc.Name) AS SubLabel
            FROM ops.Routes r
            INNER JOIN lookup.Cities oc ON oc.Id = r.OriginCityId
            INNER JOIN lookup.Cities dc ON dc.Id = r.DestinationCityId
            WHERE r.IsDeleted = 0 AND r.Name LIKE @Like ESCAPE '['
            ORDER BY r.Name
        ) AS Routes

        UNION ALL

        SELECT * FROM (
            SELECT TOP (5) 'Invoice' AS EntityType, i.Id AS EntityId, i.InvoiceNo AS Label, c.Name AS SubLabel
            FROM billing.Invoices i
            INNER JOIN billing.Customers c ON c.Id = i.CustomerId
            WHERE i.IsDeleted = 0 AND i.InvoiceNo LIKE @Like ESCAPE '['
            ORDER BY i.InvoiceNo
        ) AS Invoices

        UNION ALL

        SELECT * FROM (
            SELECT TOP (5) 'Customer' AS EntityType, c.Id AS EntityId, c.Name AS Label, c.Code AS SubLabel
            FROM billing.Customers c
            WHERE c.IsDeleted = 0 AND (c.Name LIKE @Like ESCAPE '[' OR c.Code LIKE @Like ESCAPE '[')
            ORDER BY c.Name
        ) AS Customers

        UNION ALL

        SELECT * FROM (
            SELECT TOP (5) 'User' AS EntityType, u.Id AS EntityId, u.DisplayName AS Label, u.Email AS SubLabel
            FROM auth.Users u
            WHERE u.IsDeleted = 0
                  AND (u.DisplayName LIKE @Like ESCAPE '[' OR u.Email LIKE @Like ESCAPE '[' OR u.EmpCode LIKE @Like ESCAPE '[')
            ORDER BY u.DisplayName
        ) AS Users

        ORDER BY EntityType, Label;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END
GO
