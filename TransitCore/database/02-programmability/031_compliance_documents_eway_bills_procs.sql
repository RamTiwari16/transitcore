/*
  Purpose:      Programmability for Phase 6 (F8) - see
                020_compliance_documents_eway_bills_schema.sql for the schema
                this backs. Covers: required-document-type admin CRUD,
                fleet-wide expiring-compliance-documents report, a
                non-blocking per-trip dispatch compliance check (mirrors
                ops.usp_CheckTripConflicts - the DB reports facts, the
                frontend decides whether to warn/block), e-way bill fields
                on the consignment note, and an expiring-e-way-bills report.
  Author:       TransitCore rebuild
  Date:         2026-09-29
  Dependencies: 020_compliance_documents_eway_bills_schema.sql,
                012_required_compliance_document_types_seed.sql
*/
SET QUOTED_IDENTIFIER ON;
GO
SET NOCOUNT ON;
GO

-- ========== fleet.RequiredComplianceDocumentTypes (admin CRUD) ==========

IF OBJECT_ID('fleet.usp_GetRequiredComplianceDocumentTypes', 'P') IS NOT NULL
    DROP PROCEDURE fleet.usp_GetRequiredComplianceDocumentTypes;
GO

CREATE PROCEDURE fleet.usp_GetRequiredComplianceDocumentTypes
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        SELECT Id, DocumentType, IsActive
        FROM fleet.RequiredComplianceDocumentTypes
        WHERE IsDeleted = 0
        ORDER BY DocumentType;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END
GO

IF OBJECT_ID('fleet.usp_InsertRequiredComplianceDocumentType', 'P') IS NOT NULL
    DROP PROCEDURE fleet.usp_InsertRequiredComplianceDocumentType;
GO

CREATE PROCEDURE fleet.usp_InsertRequiredComplianceDocumentType
    @DocumentType  NVARCHAR(100),
    @CreatedBy     NVARCHAR(256)
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        INSERT INTO fleet.RequiredComplianceDocumentTypes (DocumentType, CreatedBy)
        VALUES (@DocumentType, @CreatedBy);

        SELECT CAST(SCOPE_IDENTITY() AS INT) AS NewId;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END
GO

IF OBJECT_ID('fleet.usp_UpdateRequiredComplianceDocumentType', 'P') IS NOT NULL
    DROP PROCEDURE fleet.usp_UpdateRequiredComplianceDocumentType;
GO

CREATE PROCEDURE fleet.usp_UpdateRequiredComplianceDocumentType
    @Id          INT,
    @DocumentType NVARCHAR(100),
    @IsActive    BIT,
    @ModifiedBy  NVARCHAR(256),
    @Success     BIT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        UPDATE fleet.RequiredComplianceDocumentTypes
        SET DocumentType = @DocumentType, IsActive = @IsActive, ModifiedBy = @ModifiedBy, ModifiedAt = SYSUTCDATETIME()
        WHERE Id = @Id AND IsDeleted = 0;

        SET @Success = CASE WHEN @@ROWCOUNT > 0 THEN 1 ELSE 0 END;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END
GO

IF OBJECT_ID('fleet.usp_DeleteRequiredComplianceDocumentType', 'P') IS NOT NULL
    DROP PROCEDURE fleet.usp_DeleteRequiredComplianceDocumentType;
GO

CREATE PROCEDURE fleet.usp_DeleteRequiredComplianceDocumentType
    @Id          INT,
    @ModifiedBy  NVARCHAR(256),
    @Success     BIT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        UPDATE fleet.RequiredComplianceDocumentTypes
        SET IsDeleted = 1, ModifiedBy = @ModifiedBy, ModifiedAt = SYSUTCDATETIME()
        WHERE Id = @Id AND IsDeleted = 0;

        SET @Success = CASE WHEN @@ROWCOUNT > 0 THEN 1 ELSE 0 END;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END
GO

-- ========== Per-trip dispatch compliance check (non-blocking) ==========
-- Note: fleet-wide expiring-document alerts already exist
-- (fleet.usp_GetExpiringVehicleDocuments / usp_GetExpiringDriverLicenses,
-- pre-dating this phase) - not duplicated here. What those don't cover is
-- (a) which document types are actually MANDATORY (RequiredComplianceDocumentTypes,
-- above) and (b) a MISSING document (as opposed to an expiring one), both
-- of which this check adds.
-- Own trips only - a Hired trip has no fleet vehicle/driver to check
-- against (same exclusion as F6's empty-km/availability reports). Returns
-- one row per required vehicle document type plus one row for the driver's
-- license; Status is Missing/Expired/Valid. Purely informational - nothing
-- here prevents ops.usp_UpdateTripStatus from running.
IF OBJECT_ID('ops.usp_CheckTripDispatchCompliance', 'P') IS NOT NULL
    DROP PROCEDURE ops.usp_CheckTripDispatchCompliance;
GO

CREATE PROCEDURE ops.usp_CheckTripDispatchCompliance
    @TripId INT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        DECLARE @VehicleId INT, @DriverId INT, @OwnershipType NVARCHAR(10);
        SELECT @VehicleId = VehicleId, @DriverId = DriverId, @OwnershipType = OwnershipType
        FROM ops.Trips WHERE Id = @TripId AND IsDeleted = 0;

        DECLARE @Today DATE = CAST(SYSUTCDATETIME() AS DATE);

        IF @OwnershipType IS NULL OR @OwnershipType <> 'Own' OR @VehicleId IS NULL OR @DriverId IS NULL
        BEGIN
            SELECT
                CAST(NULL AS NVARCHAR(10)) AS CheckType, CAST(NULL AS NVARCHAR(100)) AS Label,
                CAST(NULL AS NVARCHAR(20)) AS Status, CAST(NULL AS DATE) AS ExpiryDate
            WHERE 1 = 0;
            RETURN;
        END

        SELECT
            'Vehicle' AS CheckType,
            rc.DocumentType AS Label,
            CASE
                WHEN vd.Id IS NULL THEN 'Missing'
                WHEN vd.ExpiryDate IS NOT NULL AND vd.ExpiryDate < @Today THEN 'Expired'
                ELSE 'Valid'
            END AS Status,
            vd.ExpiryDate
        FROM fleet.RequiredComplianceDocumentTypes rc
        OUTER APPLY (
            SELECT TOP 1 d.Id, d.ExpiryDate
            FROM fleet.VehicleDocuments d
            WHERE d.VehicleId = @VehicleId AND d.DocumentType = rc.DocumentType AND d.IsDeleted = 0
            ORDER BY d.ExpiryDate DESC
        ) vd
        WHERE rc.IsActive = 1 AND rc.IsDeleted = 0

        UNION ALL

        SELECT
            'Driver' AS CheckType,
            'Driving License' AS Label,
            CASE
                WHEN dl.Id IS NULL THEN 'Missing'
                WHEN dl.ExpiryDate IS NOT NULL AND dl.ExpiryDate < @Today THEN 'Expired'
                ELSE 'Valid'
            END AS Status,
            dl.ExpiryDate
        FROM (SELECT 1 AS Marker) AS OneRow
        OUTER APPLY (
            SELECT TOP 1 l.Id, l.ExpiryDate
            FROM fleet.DriverLicenses l
            WHERE l.DriverId = @DriverId AND l.IsDeleted = 0
            ORDER BY l.ExpiryDate DESC
        ) dl;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END
GO

-- ========== Consignment note: e-way bill ==========

IF OBJECT_ID('ops.usp_GetConsignmentNoteByShipmentId', 'P') IS NOT NULL
    DROP PROCEDURE ops.usp_GetConsignmentNoteByShipmentId;
GO

CREATE PROCEDURE ops.usp_GetConsignmentNoteByShipmentId
    @ShipmentId INT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        SELECT
            cn.Id, cn.ShipmentId, cn.CnNumber, cn.BranchId, b.Name AS BranchName, cn.CnDate,
            cn.Packages, cn.ActualWeightKg, cn.ChargedWeightKg, cn.DeclaredValue, cn.FreightAmount, cn.Remarks,
            cn.StatusId, sc.Name AS StatusName, cn.CancelReason, cn.CancelledAt, cn.CancelledBy,
            cn.EwayBillNo, cn.EwayBillGeneratedDate, cn.EwayBillValidUntil,
            s.TrackingNo, s.OriginCityId, oc.Name AS OriginCityName, s.DestinationCityId, dc.Name AS DestinationCityName,
            s.ShipmentDate, s.FreightPaymentTypeId, fpt.Name AS FreightPaymentTypeName,
            s.CustomerId AS BillingPartyCustomerId, bp.Name AS BillingPartyName,
            s.ConsignorCustomerId, cc.Name AS ConsignorCustomerName, s.ConsignorName, s.ConsignorAddress, s.ConsignorPhone,
            s.ConsigneeCustomerId, ce.Name AS ConsigneeCustomerName, s.ConsigneeName, s.ConsigneeAddress, s.ConsigneePhone,
            s.TripId, t.VehicleId, v.RegistrationNo AS VehicleRegistrationNo, t.DriverId, d.FullName AS DriverName
        FROM ops.ConsignmentNotes cn
        INNER JOIN ops.Shipments s ON s.Id = cn.ShipmentId
        INNER JOIN lookup.Branches b ON b.Id = cn.BranchId
        INNER JOIN lookup.StatusCodes sc ON sc.Id = cn.StatusId
        INNER JOIN lookup.StatusCodes fpt ON fpt.Id = s.FreightPaymentTypeId
        INNER JOIN lookup.Cities oc ON oc.Id = s.OriginCityId
        INNER JOIN lookup.Cities dc ON dc.Id = s.DestinationCityId
        INNER JOIN billing.Customers bp ON bp.Id = s.CustomerId
        LEFT JOIN billing.Customers cc ON cc.Id = s.ConsignorCustomerId
        LEFT JOIN billing.Customers ce ON ce.Id = s.ConsigneeCustomerId
        LEFT JOIN ops.Trips t ON t.Id = s.TripId AND t.IsDeleted = 0
        LEFT JOIN fleet.Vehicles v ON v.Id = t.VehicleId
        LEFT JOIN fleet.Drivers d ON d.Id = t.DriverId
        WHERE cn.ShipmentId = @ShipmentId;

        SELECT si.Id, si.Description, si.Quantity, si.UnitOfMeasureId, uom.Code AS UnitOfMeasureCode, si.WeightKg
        FROM ops.ShipmentItems si
        INNER JOIN lookup.UnitsOfMeasure uom ON uom.Id = si.UnitOfMeasureId
        WHERE si.ShipmentId = @ShipmentId AND si.IsDeleted = 0;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END
GO

IF OBJECT_ID('ops.usp_UpdateConsignmentNoteEwayBill', 'P') IS NOT NULL
    DROP PROCEDURE ops.usp_UpdateConsignmentNoteEwayBill;
GO

CREATE PROCEDURE ops.usp_UpdateConsignmentNoteEwayBill
    @ShipmentId             INT,
    @EwayBillNo             NVARCHAR(50),
    @EwayBillGeneratedDate  DATE,
    @EwayBillValidUntil     DATE,
    @ModifiedBy             NVARCHAR(256),
    @Success                BIT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        UPDATE ops.ConsignmentNotes
        SET EwayBillNo = @EwayBillNo, EwayBillGeneratedDate = @EwayBillGeneratedDate, EwayBillValidUntil = @EwayBillValidUntil,
            ModifiedBy = @ModifiedBy, ModifiedAt = SYSUTCDATETIME()
        WHERE ShipmentId = @ShipmentId AND IsDeleted = 0;

        SET @Success = CASE WHEN @@ROWCOUNT > 0 THEN 1 ELSE 0 END;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END
GO

-- Only for shipments still in flight - a delivered/cancelled shipment's
-- e-way bill going stale has no operational consequence.
IF OBJECT_ID('ops.usp_GetExpiringEwayBills', 'P') IS NOT NULL
    DROP PROCEDURE ops.usp_GetExpiringEwayBills;
GO

CREATE PROCEDURE ops.usp_GetExpiringEwayBills
    @DaysAhead INT = 3
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        DECLARE @Today DATE = CAST(SYSUTCDATETIME() AS DATE);
        DECLARE @CutOff DATE = DATEADD(DAY, @DaysAhead, @Today);

        SELECT
            cn.Id AS ConsignmentNoteId, cn.ShipmentId, cn.CnNumber, s.TrackingNo,
            cn.EwayBillNo, cn.EwayBillValidUntil,
            DATEDIFF(DAY, @Today, cn.EwayBillValidUntil) AS DaysUntilExpiry
        FROM ops.ConsignmentNotes cn
        INNER JOIN ops.Shipments s ON s.Id = cn.ShipmentId
        INNER JOIN lookup.StatusCodes sc ON sc.Id = s.StatusId
        WHERE cn.IsDeleted = 0
          AND cn.EwayBillValidUntil IS NOT NULL AND cn.EwayBillValidUntil <= @CutOff
          AND sc.Code NOT IN ('DELIVERED', 'CANCELLED')
        ORDER BY DaysUntilExpiry ASC;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END
GO
