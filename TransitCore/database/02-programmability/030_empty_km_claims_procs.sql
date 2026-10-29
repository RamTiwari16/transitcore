/*
  Purpose:      Programmability for Phase 5 (F6 + F7) - see
                019_empty_km_claims_schema.sql for the schema this backs.
                Also regenerates every existing proc that computes an
                invoice's outstanding balance so it accounts for the new
                billing.Invoices.DeductionAmount column (a settled claim
                reduces what's still owed exactly like a Payment does).
                usp_GetRevenueByPeriod is deliberately NOT touched - its
                "TotalCollected" means cash actually received, and a
                deduction is a write-off of the receivable, not a receipt.
  Author:       TransitCore rebuild
  Date:         2026-10-09
  Dependencies: 019_empty_km_claims_schema.sql, 011_claim_status_seed.sql
                (lookup.StatusCodes 'Claim' category)
*/
SET QUOTED_IDENTIFIER ON;
GO
SET NOCOUNT ON;
GO

-- ========== F6: ops.Trips - loaded / empty km ==========

IF OBJECT_ID('ops.usp_UpdateTripKm', 'P') IS NOT NULL
    DROP PROCEDURE ops.usp_UpdateTripKm;
GO

CREATE PROCEDURE ops.usp_UpdateTripKm
    @TripId      INT,
    @LoadedKm    DECIMAL(18,2),
    @EmptyKm     DECIMAL(18,2),
    @ModifiedBy  NVARCHAR(256),
    @Success     BIT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        UPDATE ops.Trips
        SET LoadedKm = @LoadedKm, EmptyKm = @EmptyKm, ModifiedBy = @ModifiedBy, ModifiedAt = SYSUTCDATETIME()
        WHERE Id = @TripId AND IsDeleted = 0;

        SET @Success = CASE WHEN @@ROWCOUNT > 0 THEN 1 ELSE 0 END;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END
GO

-- Own trips only - a hired trip has no VehicleId to attribute empty-km to,
-- and the vendor (not TransitCore) bears its running-cost economics anyway.
IF OBJECT_ID('fleet.usp_GetEmptyKmReport', 'P') IS NOT NULL
    DROP PROCEDURE fleet.usp_GetEmptyKmReport;
GO

CREATE PROCEDURE fleet.usp_GetEmptyKmReport
    @FromDate DATE,
    @ToDate   DATE
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        SELECT
            v.Id AS VehicleId, v.RegistrationNo,
            SUM(t.LoadedKm) AS TotalLoadedKm,
            SUM(t.EmptyKm) AS TotalEmptyKm,
            SUM(t.LoadedKm) + SUM(t.EmptyKm) AS TotalKm,
            CASE WHEN SUM(t.LoadedKm) + SUM(t.EmptyKm) > 0
                 THEN SUM(t.EmptyKm) * 100.0 / (SUM(t.LoadedKm) + SUM(t.EmptyKm))
                 ELSE 0 END AS EmptyKmPercent,
            COUNT(*) AS TripCount
        FROM ops.Trips t
        INNER JOIN fleet.Vehicles v ON v.Id = t.VehicleId
        WHERE t.IsDeleted = 0
          AND t.OwnershipType = 'Own'
          AND t.LoadedKm IS NOT NULL AND t.EmptyKm IS NOT NULL
          AND CAST(ISNULL(t.ActualDeparture, t.ScheduledDeparture) AS DATE) BETWEEN @FromDate AND @ToDate
        GROUP BY v.Id, v.RegistrationNo
        ORDER BY EmptyKmPercent DESC;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END
GO

-- For each active own-fleet vehicle: its latest not-yet-finished trip's
-- expected end (ActualArrival if recorded, else ScheduledArrival), or
-- already-available if it has none. "Latest" so a vehicle queued for
-- several upcoming trips reports free only after the last of them.
IF OBJECT_ID('fleet.usp_GetVehiclesBecomingAvailable', 'P') IS NOT NULL
    DROP PROCEDURE fleet.usp_GetVehiclesBecomingAvailable;
GO

CREATE PROCEDURE fleet.usp_GetVehiclesBecomingAvailable
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        ;WITH ActiveTrip AS (
            SELECT
                t.VehicleId,
                r.Name AS RouteName,
                ISNULL(t.ActualArrival, t.ScheduledArrival) AS ExpectedFreeAt,
                ROW_NUMBER() OVER (PARTITION BY t.VehicleId ORDER BY ISNULL(t.ActualArrival, t.ScheduledArrival) DESC) AS rn
            FROM ops.Trips t
            INNER JOIN ops.Routes r ON r.Id = t.RouteId
            INNER JOIN lookup.StatusCodes sc ON sc.Id = t.StatusId
            WHERE t.IsDeleted = 0
              AND t.OwnershipType = 'Own'
              AND t.VehicleId IS NOT NULL
              AND sc.Code NOT IN ('COMPLETED', 'CANCELLED')
        )
        SELECT
            v.Id AS VehicleId, v.RegistrationNo, vt.Name AS VehicleTypeName,
            CASE WHEN at.VehicleId IS NULL THEN 1 ELSE 0 END AS IsAvailableNow,
            at.ExpectedFreeAt, at.RouteName AS CurrentTripRoute
        FROM fleet.Vehicles v
        INNER JOIN fleet.VehicleTypes vt ON vt.Id = v.VehicleTypeId
        INNER JOIN lookup.StatusCodes vsc ON vsc.Id = v.StatusId
        LEFT JOIN ActiveTrip at ON at.VehicleId = v.Id AND at.rn = 1
        WHERE v.IsDeleted = 0 AND vsc.Code = 'ACTIVE'
        ORDER BY IsAvailableNow DESC, at.ExpectedFreeAt ASC;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END
GO

-- ========== Regenerated: usp_GetTrips/usp_GetTripById now project LoadedKm/EmptyKm ==========

IF OBJECT_ID('ops.usp_GetTrips', 'P') IS NOT NULL
    DROP PROCEDURE ops.usp_GetTrips;
GO

CREATE PROCEDURE ops.usp_GetTrips
    @FromDate   DATETIME2(3) = NULL,
    @ToDate     DATETIME2(3) = NULL,
    @StatusId   INT = NULL,
    @VehicleId  INT = NULL,
    @DriverId   INT = NULL,
    @RouteId    INT = NULL,
    @PageNumber INT = 1,
    @PageSize   INT = 25
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        SELECT
            t.Id, t.RouteId, r.Name AS RouteName,
            t.VehicleId, v.RegistrationNo,
            t.DriverId, d.FullName AS DriverName,
            t.ScheduledDeparture, t.ScheduledArrival, t.ActualDeparture, t.ActualArrival,
            t.StatusId, sc.Name AS StatusName,
            t.OwnershipType, t.VendorId, vd.Name AS VendorName,
            t.HiredVehicleNo, t.HiredDriverName, t.HiredDriverPhone, t.VendorFreightAmount,
            t.LoadedKm, t.EmptyKm,
            COUNT(*) OVER() AS TotalCount
        FROM ops.Trips t
        INNER JOIN ops.Routes r ON r.Id = t.RouteId
        LEFT JOIN fleet.Vehicles v ON v.Id = t.VehicleId
        LEFT JOIN fleet.Drivers d ON d.Id = t.DriverId
        LEFT JOIN billing.Vendors vd ON vd.Id = t.VendorId
        INNER JOIN lookup.StatusCodes sc ON sc.Id = t.StatusId
        WHERE t.IsDeleted = 0
          AND (@FromDate IS NULL OR t.ScheduledDeparture >= @FromDate)
          AND (@ToDate IS NULL OR t.ScheduledDeparture <= @ToDate)
          AND (@StatusId IS NULL OR t.StatusId = @StatusId)
          AND (@VehicleId IS NULL OR t.VehicleId = @VehicleId)
          AND (@DriverId IS NULL OR t.DriverId = @DriverId)
          AND (@RouteId IS NULL OR t.RouteId = @RouteId)
        ORDER BY t.ScheduledDeparture DESC
        OFFSET (@PageNumber - 1) * @PageSize ROWS
        FETCH NEXT @PageSize ROWS ONLY;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END
GO

IF OBJECT_ID('ops.usp_GetTripById', 'P') IS NOT NULL
    DROP PROCEDURE ops.usp_GetTripById;
GO

CREATE PROCEDURE ops.usp_GetTripById
    @TripId INT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        SELECT
            t.Id, t.RouteId, r.Name AS RouteName,
            t.VehicleId, v.RegistrationNo,
            t.DriverId, d.FullName AS DriverName,
            t.ScheduledDeparture, t.ScheduledArrival, t.ActualDeparture, t.ActualArrival,
            t.StatusId, sc.Name AS StatusName,
            t.OwnershipType, t.VendorId, vd.Name AS VendorName,
            t.HiredVehicleNo, t.HiredDriverName, t.HiredDriverPhone, t.VendorFreightAmount,
            t.LoadedKm, t.EmptyKm
        FROM ops.Trips t
        INNER JOIN ops.Routes r ON r.Id = t.RouteId
        LEFT JOIN fleet.Vehicles v ON v.Id = t.VehicleId
        LEFT JOIN fleet.Drivers d ON d.Id = t.DriverId
        LEFT JOIN billing.Vendors vd ON vd.Id = t.VendorId
        INNER JOIN lookup.StatusCodes sc ON sc.Id = t.StatusId
        WHERE t.Id = @TripId AND t.IsDeleted = 0;

        SELECT h.Id, h.StatusId, sc.Name AS StatusName, h.ChangedAt, h.Notes
        FROM ops.TripStatusHistory h
        INNER JOIN lookup.StatusCodes sc ON sc.Id = h.StatusId
        WHERE h.TripId = @TripId
        ORDER BY h.ChangedAt;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END
GO

-- ========== F7: per-item delivery reconciliation ==========

IF OBJECT_ID('ops.usp_GetShipmentItemDeliveries', 'P') IS NOT NULL
    DROP PROCEDURE ops.usp_GetShipmentItemDeliveries;
GO

CREATE PROCEDURE ops.usp_GetShipmentItemDeliveries
    @ShipmentId INT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        SELECT
            si.Id AS ShipmentItemId, si.Description, si.Quantity, uom.Code AS UnitOfMeasureCode,
            si.WeightKg, si.VolumeCbm,
            sid.Id AS DeliveryId, sid.DeliveredQty, sid.ShortQty, sid.DamagedQty, sid.Remarks, sid.CreatedAt AS RecordedAt
        FROM ops.ShipmentItems si
        INNER JOIN lookup.UnitsOfMeasure uom ON uom.Id = si.UnitOfMeasureId
        LEFT JOIN ops.ShipmentItemDeliveries sid ON sid.ShipmentItemId = si.Id AND sid.IsDeleted = 0
        WHERE si.ShipmentId = @ShipmentId AND si.IsDeleted = 0
        ORDER BY si.Id;

        SELECT p.Id, p.ShipmentItemDeliveryId, p.FilePath, p.UploadedAt
        FROM ops.ShipmentItemDeliveryPhotos p
        INNER JOIN ops.ShipmentItemDeliveries sid ON sid.Id = p.ShipmentItemDeliveryId
        INNER JOIN ops.ShipmentItems si ON si.Id = sid.ShipmentItemId
        WHERE si.ShipmentId = @ShipmentId
        ORDER BY p.UploadedAt ASC;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END
GO

IF OBJECT_ID('ops.usp_InsertShipmentItemDelivery', 'P') IS NOT NULL
    DROP PROCEDURE ops.usp_InsertShipmentItemDelivery;
GO

CREATE PROCEDURE ops.usp_InsertShipmentItemDelivery
    @ShipmentItemId  INT,
    @DeliveredQty    DECIMAL(18,2),
    @ShortQty        DECIMAL(18,2) = 0,
    @DamagedQty      DECIMAL(18,2) = 0,
    @Remarks         NVARCHAR(500) = NULL,
    @CreatedBy       NVARCHAR(256)
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        INSERT INTO ops.ShipmentItemDeliveries (ShipmentItemId, DeliveredQty, ShortQty, DamagedQty, Remarks, CreatedBy)
        VALUES (@ShipmentItemId, @DeliveredQty, @ShortQty, @DamagedQty, @Remarks, @CreatedBy);

        SELECT CAST(SCOPE_IDENTITY() AS INT) AS NewId;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END
GO

IF OBJECT_ID('ops.usp_UpdateShipmentItemDelivery', 'P') IS NOT NULL
    DROP PROCEDURE ops.usp_UpdateShipmentItemDelivery;
GO

CREATE PROCEDURE ops.usp_UpdateShipmentItemDelivery
    @DeliveryId    INT,
    @DeliveredQty  DECIMAL(18,2),
    @ShortQty      DECIMAL(18,2) = 0,
    @DamagedQty    DECIMAL(18,2) = 0,
    @Remarks       NVARCHAR(500) = NULL,
    @ModifiedBy    NVARCHAR(256),
    @Success       BIT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        UPDATE ops.ShipmentItemDeliveries
        SET DeliveredQty = @DeliveredQty, ShortQty = @ShortQty, DamagedQty = @DamagedQty, Remarks = @Remarks,
            ModifiedBy = @ModifiedBy, ModifiedAt = SYSUTCDATETIME()
        WHERE Id = @DeliveryId AND IsDeleted = 0;

        SET @Success = CASE WHEN @@ROWCOUNT > 0 THEN 1 ELSE 0 END;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END
GO

IF OBJECT_ID('ops.usp_InsertShipmentItemDeliveryPhoto', 'P') IS NOT NULL
    DROP PROCEDURE ops.usp_InsertShipmentItemDeliveryPhoto;
GO

CREATE PROCEDURE ops.usp_InsertShipmentItemDeliveryPhoto
    @ShipmentItemDeliveryId  INT,
    @FilePath                NVARCHAR(400)
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        INSERT INTO ops.ShipmentItemDeliveryPhotos (ShipmentItemDeliveryId, FilePath)
        VALUES (@ShipmentItemDeliveryId, @FilePath);

        SELECT CAST(SCOPE_IDENTITY() AS INT) AS NewId;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END
GO

-- ========== F7: billing.Claims ==========

IF OBJECT_ID('billing.usp_InsertClaim', 'P') IS NOT NULL
    DROP PROCEDURE billing.usp_InsertClaim;
GO

CREATE PROCEDURE billing.usp_InsertClaim
    @ShipmentId     INT,
    @ClaimantName   NVARCHAR(200),
    @ClaimantPhone  NVARCHAR(30) = NULL,
    @AmountClaimed  DECIMAL(18,2),
    @StatusId       INT,
    @Notes          NVARCHAR(500) = NULL,
    @CreatedBy      NVARCHAR(256)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    BEGIN TRY
        BEGIN TRANSACTION;

        INSERT INTO billing.Claims (ShipmentId, ClaimantName, ClaimantPhone, AmountClaimed, StatusId, Notes, CreatedBy)
        VALUES (@ShipmentId, @ClaimantName, @ClaimantPhone, @AmountClaimed, @StatusId, @Notes, @CreatedBy);

        DECLARE @NewId INT = SCOPE_IDENTITY();

        INSERT INTO billing.ClaimStatusHistory (ClaimId, StatusId, Notes, CreatedBy)
        VALUES (@NewId, @StatusId, 'Claim raised', @CreatedBy);

        COMMIT TRANSACTION;
        SELECT @NewId AS NewId;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0
            ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END
GO

IF OBJECT_ID('billing.usp_GetClaims', 'P') IS NOT NULL
    DROP PROCEDURE billing.usp_GetClaims;
GO

CREATE PROCEDURE billing.usp_GetClaims
    @ShipmentId  INT = NULL,
    @StatusId    INT = NULL,
    @FromDate    DATE = NULL,
    @ToDate      DATE = NULL,
    @PageNumber  INT = 1,
    @PageSize    INT = 25
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        SELECT
            c.Id, c.ShipmentId, s.TrackingNo,
            c.ClaimantName, c.ClaimantPhone, c.AmountClaimed,
            c.StatusId, sc.Name AS StatusName,
            c.SettledAmount, c.SettlementMethod, c.Notes, c.CreatedAt,
            COUNT(*) OVER() AS TotalCount
        FROM billing.Claims c
        INNER JOIN ops.Shipments s ON s.Id = c.ShipmentId
        INNER JOIN lookup.StatusCodes sc ON sc.Id = c.StatusId
        WHERE c.IsDeleted = 0
          AND (@ShipmentId IS NULL OR c.ShipmentId = @ShipmentId)
          AND (@StatusId IS NULL OR c.StatusId = @StatusId)
          AND (@FromDate IS NULL OR CAST(c.CreatedAt AS DATE) >= @FromDate)
          AND (@ToDate IS NULL OR CAST(c.CreatedAt AS DATE) <= @ToDate)
        ORDER BY c.CreatedAt DESC
        OFFSET (@PageNumber - 1) * @PageSize ROWS
        FETCH NEXT @PageSize ROWS ONLY;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END
GO

IF OBJECT_ID('billing.usp_GetClaimById', 'P') IS NOT NULL
    DROP PROCEDURE billing.usp_GetClaimById;
GO

CREATE PROCEDURE billing.usp_GetClaimById
    @ClaimId INT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        SELECT
            c.Id, c.ShipmentId, s.TrackingNo,
            c.ClaimantName, c.ClaimantPhone, c.AmountClaimed,
            c.StatusId, sc.Name AS StatusName,
            c.SettledAmount, c.SettlementMethod, c.Notes, c.CreatedAt
        FROM billing.Claims c
        INNER JOIN ops.Shipments s ON s.Id = c.ShipmentId
        INNER JOIN lookup.StatusCodes sc ON sc.Id = c.StatusId
        WHERE c.Id = @ClaimId AND c.IsDeleted = 0;

        SELECT h.Id, h.StatusId, sc.Name AS StatusName, h.ChangedAt, h.Notes
        FROM billing.ClaimStatusHistory h
        INNER JOIN lookup.StatusCodes sc ON sc.Id = h.StatusId
        WHERE h.ClaimId = @ClaimId
        ORDER BY h.ChangedAt;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END
GO

IF OBJECT_ID('billing.usp_UpdateClaim', 'P') IS NOT NULL
    DROP PROCEDURE billing.usp_UpdateClaim;
GO

CREATE PROCEDURE billing.usp_UpdateClaim
    @ClaimId        INT,
    @ClaimantName   NVARCHAR(200),
    @ClaimantPhone  NVARCHAR(30) = NULL,
    @AmountClaimed  DECIMAL(18,2),
    @Notes          NVARCHAR(500) = NULL,
    @ModifiedBy     NVARCHAR(256),
    @Success        BIT OUTPUT,
    @ErrorMessage   NVARCHAR(500) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        SET @Success = 0;
        SET @ErrorMessage = NULL;

        IF EXISTS (
            SELECT 1 FROM billing.Claims c
            INNER JOIN lookup.StatusCodes sc ON sc.Id = c.StatusId
            WHERE c.Id = @ClaimId AND c.IsDeleted = 0 AND sc.Code IN ('SETTLED', 'REJECTED')
        )
        BEGIN
            SET @ErrorMessage = 'Cannot edit a claim that has already been settled or rejected.';
            RETURN;
        END

        UPDATE billing.Claims
        SET ClaimantName = @ClaimantName, ClaimantPhone = @ClaimantPhone, AmountClaimed = @AmountClaimed,
            Notes = @Notes, ModifiedBy = @ModifiedBy, ModifiedAt = SYSUTCDATETIME()
        WHERE Id = @ClaimId AND IsDeleted = 0;

        SET @Success = CASE WHEN @@ROWCOUNT > 0 THEN 1 ELSE 0 END;
        IF @Success = 0 AND @ErrorMessage IS NULL
            SET @ErrorMessage = 'Claim not found.';
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END
GO

-- Non-settlement transitions only (e.g. Raised -> UnderInvestigation, or a
-- straight Rejected with no money movement). Settling goes through
-- usp_SettleClaim instead, since only that path knows how to apply the
-- InvoiceDeduction/VendorRecovery side effect atomically with the status
-- change.
IF OBJECT_ID('billing.usp_UpdateClaimStatus', 'P') IS NOT NULL
    DROP PROCEDURE billing.usp_UpdateClaimStatus;
GO

CREATE PROCEDURE billing.usp_UpdateClaimStatus
    @ClaimId       INT,
    @StatusId      INT,
    @Notes         NVARCHAR(500) = NULL,
    @ModifiedBy    NVARCHAR(256),
    @Success       BIT OUTPUT,
    @ErrorMessage  NVARCHAR(500) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    BEGIN TRY
        SET @Success = 0;
        SET @ErrorMessage = NULL;

        IF EXISTS (SELECT 1 FROM lookup.StatusCodes WHERE Id = @StatusId AND Category = 'Claim' AND Code = 'SETTLED')
        BEGIN
            SET @ErrorMessage = 'Use the settle action to mark a claim as settled.';
            RETURN;
        END

        IF EXISTS (
            SELECT 1 FROM billing.Claims c
            INNER JOIN lookup.StatusCodes sc ON sc.Id = c.StatusId
            WHERE c.Id = @ClaimId AND c.IsDeleted = 0 AND sc.Code IN ('SETTLED', 'REJECTED')
        )
        BEGIN
            SET @ErrorMessage = 'This claim is already closed.';
            RETURN;
        END

        BEGIN TRANSACTION;

        UPDATE billing.Claims
        SET StatusId = @StatusId, ModifiedBy = @ModifiedBy, ModifiedAt = SYSUTCDATETIME()
        WHERE Id = @ClaimId AND IsDeleted = 0;

        SET @Success = CASE WHEN @@ROWCOUNT > 0 THEN 1 ELSE 0 END;

        IF @Success = 1
            INSERT INTO billing.ClaimStatusHistory (ClaimId, StatusId, Notes, CreatedBy)
            VALUES (@ClaimId, @StatusId, @Notes, @ModifiedBy);
        ELSE
            SET @ErrorMessage = 'Claim not found.';

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0
            ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END
GO

-- Settles a claim and applies its money-movement side effect atomically:
--   InvoiceDeduction -> billing.Invoices.DeductionAmount goes up on the
--     shipment's (most recent) invoice, then that invoice's status is
--     re-evaluated with the same Paid/Partially-Paid rule usp_InsertPayment
--     uses, just with Payments+DeductionAmount standing in for Payments alone.
--   VendorRecovery -> a new ops.VendorDeductions row against the shipment's
--     trip vendor, reusing the F5 vendor-ledger mechanism as-is.
--   CreditNote / Insurance / DriverRecovery -> recorded as the method only;
--     nothing else in the system currently needs to react to these.
IF OBJECT_ID('billing.usp_SettleClaim', 'P') IS NOT NULL
    DROP PROCEDURE billing.usp_SettleClaim;
GO

CREATE PROCEDURE billing.usp_SettleClaim
    @ClaimId           INT,
    @SettledAmount     DECIMAL(18,2),
    @SettlementMethod  NVARCHAR(30),
    @Notes             NVARCHAR(500) = NULL,
    @ModifiedBy        NVARCHAR(256),
    @Success           BIT OUTPUT,
    @ErrorMessage      NVARCHAR(500) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRY
        SET @Success = 0;
        SET @ErrorMessage = NULL;

        DECLARE @ShipmentId INT, @CurrentStatusCode NVARCHAR(50);
        SELECT @ShipmentId = c.ShipmentId, @CurrentStatusCode = sc.Code
        FROM billing.Claims c
        INNER JOIN lookup.StatusCodes sc ON sc.Id = c.StatusId
        WHERE c.Id = @ClaimId AND c.IsDeleted = 0;

        IF @ShipmentId IS NULL
        BEGIN
            SET @ErrorMessage = 'Claim not found.';
            RETURN;
        END

        IF @CurrentStatusCode IN ('SETTLED', 'REJECTED')
        BEGIN
            SET @ErrorMessage = 'This claim is already closed.';
            RETURN;
        END

        DECLARE @TripId INT, @OwnershipType NVARCHAR(10), @VendorId INT;
        IF @SettlementMethod = 'VendorRecovery'
        BEGIN
            SELECT @TripId = s.TripId FROM ops.Shipments s WHERE s.Id = @ShipmentId;
            IF @TripId IS NOT NULL
                SELECT @OwnershipType = OwnershipType, @VendorId = VendorId FROM ops.Trips WHERE Id = @TripId;

            IF @OwnershipType IS NULL OR @OwnershipType <> 'Hired' OR @VendorId IS NULL
            BEGIN
                SET @ErrorMessage = 'VendorRecovery requires the shipment to be on a hired trip with a vendor.';
                RETURN;
            END
        END

        DECLARE @InvoiceId INT;
        IF @SettlementMethod = 'InvoiceDeduction'
        BEGIN
            SELECT TOP 1 @InvoiceId = il.InvoiceId
            FROM billing.InvoiceLines il
            INNER JOIN billing.Invoices i ON i.Id = il.InvoiceId
            WHERE il.ShipmentId = @ShipmentId AND il.IsDeleted = 0 AND i.IsDeleted = 0
            ORDER BY i.InvoiceDate DESC, il.InvoiceId DESC;

            IF @InvoiceId IS NULL
            BEGIN
                SET @ErrorMessage = 'No invoice found for this shipment - cannot deduct.';
                RETURN;
            END
        END

        DECLARE @SettledStatusId INT = (SELECT Id FROM lookup.StatusCodes WHERE Category = 'Claim' AND Code = 'SETTLED');

        BEGIN TRANSACTION;

        UPDATE billing.Claims
        SET StatusId = @SettledStatusId, SettledAmount = @SettledAmount, SettlementMethod = @SettlementMethod,
            Notes = ISNULL(@Notes, Notes), ModifiedBy = @ModifiedBy, ModifiedAt = SYSUTCDATETIME()
        WHERE Id = @ClaimId AND IsDeleted = 0;

        INSERT INTO billing.ClaimStatusHistory (ClaimId, StatusId, Notes, CreatedBy)
        VALUES (@ClaimId, @SettledStatusId, ISNULL(@Notes, 'Claim settled via ' + @SettlementMethod), @ModifiedBy);

        IF @SettlementMethod = 'InvoiceDeduction'
        BEGIN
            UPDATE billing.Invoices
            SET DeductionAmount = DeductionAmount + @SettledAmount
            WHERE Id = @InvoiceId;

            DECLARE @TotalAmount DECIMAL(18,2), @TotalPaid DECIMAL(18,2), @DeductionTotal DECIMAL(18,2);
            SELECT @TotalAmount = TotalAmount, @DeductionTotal = DeductionAmount FROM billing.Invoices WHERE Id = @InvoiceId;
            SELECT @TotalPaid = ISNULL(SUM(Amount), 0) FROM billing.Payments WHERE InvoiceId = @InvoiceId AND IsDeleted = 0;

            DECLARE @NewStatusName NVARCHAR(50) = CASE
                WHEN @TotalPaid + @DeductionTotal >= @TotalAmount THEN 'Paid'
                WHEN @TotalPaid + @DeductionTotal > 0 THEN 'Partially Paid'
                ELSE NULL
            END;

            IF @NewStatusName IS NOT NULL
            BEGIN
                UPDATE i
                SET i.StatusId = sc.Id, i.ModifiedBy = @ModifiedBy, i.ModifiedAt = SYSUTCDATETIME()
                FROM billing.Invoices i
                INNER JOIN lookup.StatusCodes sc ON sc.Category = 'Invoice' AND sc.Name = @NewStatusName
                WHERE i.Id = @InvoiceId
                  AND i.StatusId NOT IN (SELECT Id FROM lookup.StatusCodes WHERE Category = 'Invoice' AND Name = 'Void');
            END
        END
        ELSE IF @SettlementMethod = 'VendorRecovery'
        BEGIN
            INSERT INTO ops.VendorDeductions (TripId, VendorId, Amount, Reason, DeductionDate, CreatedBy)
            VALUES (@TripId, @VendorId, @SettledAmount, 'Recovery for Claim #' + CAST(@ClaimId AS VARCHAR(10)), CAST(SYSUTCDATETIME() AS DATE), @ModifiedBy);
        END

        SET @Success = 1;
        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0
            ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END
GO

-- ========== DeductionAmount ripple: every invoice-balance read/write ==========

IF OBJECT_ID('billing.usp_GetCustomerOutstandingBalance', 'P') IS NOT NULL
    DROP PROCEDURE billing.usp_GetCustomerOutstandingBalance;
GO

CREATE PROCEDURE billing.usp_GetCustomerOutstandingBalance
    @CustomerId INT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        SELECT
            @CustomerId AS CustomerId,
            ISNULL(SUM(i.TotalAmount - ISNULL(p.PaidAmount, 0) - i.DeductionAmount), 0) AS OutstandingBalance
        FROM billing.Invoices i
        INNER JOIN lookup.StatusCodes sc ON sc.Id = i.StatusId
        OUTER APPLY (
            SELECT SUM(pay.Amount) AS PaidAmount
            FROM billing.Payments pay
            WHERE pay.InvoiceId = i.Id AND pay.IsDeleted = 0
        ) p
        WHERE i.CustomerId = @CustomerId
          AND i.IsDeleted = 0
          AND sc.Name NOT IN ('Void', 'Paid');
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END
GO

IF OBJECT_ID('billing.usp_GetInvoices', 'P') IS NOT NULL
    DROP PROCEDURE billing.usp_GetInvoices;
GO

CREATE PROCEDURE billing.usp_GetInvoices
    @CustomerId INT = NULL,
    @StatusId   INT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        SELECT
            i.Id, i.InvoiceNo, i.CustomerId, c.Name AS CustomerName,
            i.InvoiceDate, i.DueDate, i.Subtotal, i.DiscountAmount, i.TaxAmount, i.TotalAmount,
            i.StatusId, sc.Name AS StatusName,
            ISNULL(p.PaidAmount, 0) AS PaidAmount, i.DeductionAmount
        FROM billing.Invoices i
        INNER JOIN billing.Customers c ON c.Id = i.CustomerId
        INNER JOIN lookup.StatusCodes sc ON sc.Id = i.StatusId
        OUTER APPLY (
            SELECT SUM(pay.Amount) AS PaidAmount
            FROM billing.Payments pay
            WHERE pay.InvoiceId = i.Id AND pay.IsDeleted = 0
        ) p
        WHERE i.IsDeleted = 0
          AND (@CustomerId IS NULL OR i.CustomerId = @CustomerId)
          AND (@StatusId IS NULL OR i.StatusId = @StatusId)
        ORDER BY i.InvoiceDate DESC;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END
GO

IF OBJECT_ID('billing.usp_GetInvoiceById', 'P') IS NOT NULL
    DROP PROCEDURE billing.usp_GetInvoiceById;
GO

CREATE PROCEDURE billing.usp_GetInvoiceById
    @InvoiceId INT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        SELECT
            i.Id, i.InvoiceNo, i.CustomerId, c.Name AS CustomerName,
            i.InvoiceDate, i.DueDate, i.Subtotal, i.DiscountAmount, i.TaxAmount, i.TotalAmount,
            i.StatusId, sc.Name AS StatusName,
            ISNULL(p.PaidAmount, 0) AS PaidAmount, i.DeductionAmount
        FROM billing.Invoices i
        INNER JOIN billing.Customers c ON c.Id = i.CustomerId
        INNER JOIN lookup.StatusCodes sc ON sc.Id = i.StatusId
        OUTER APPLY (
            SELECT SUM(pay.Amount) AS PaidAmount
            FROM billing.Payments pay
            WHERE pay.InvoiceId = i.Id AND pay.IsDeleted = 0
        ) p
        WHERE i.Id = @InvoiceId AND i.IsDeleted = 0;

        SELECT Id, ShipmentId, ShipmentChargeId, Description, Quantity, UnitPrice, LineTotal
        FROM billing.InvoiceLines
        WHERE InvoiceId = @InvoiceId AND IsDeleted = 0;

        SELECT Id, PaymentDate, Amount, Method, ReferenceNo
        FROM billing.Payments
        WHERE InvoiceId = @InvoiceId AND IsDeleted = 0
        ORDER BY PaymentDate DESC;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END
GO

IF OBJECT_ID('billing.usp_GetInvoiceSummary', 'P') IS NOT NULL
    DROP PROCEDURE billing.usp_GetInvoiceSummary;
GO

CREATE PROCEDURE billing.usp_GetInvoiceSummary
    @FromDate   DATE,
    @ToDate     DATE,
    @CustomerId INT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        SELECT
            COUNT(DISTINCT i.Id) AS InvoiceCount,
            ISNULL(SUM(i.TotalAmount), 0) AS TotalInvoiced,
            ISNULL(SUM(p.PaidAmount), 0) AS TotalPaid,
            ISNULL(SUM(i.TotalAmount), 0) - ISNULL(SUM(p.PaidAmount), 0) - ISNULL(SUM(i.DeductionAmount), 0) AS TotalOutstanding
        FROM billing.Invoices i
        OUTER APPLY (
            SELECT SUM(pay.Amount) AS PaidAmount
            FROM billing.Payments pay
            WHERE pay.InvoiceId = i.Id AND pay.IsDeleted = 0
        ) p
        WHERE i.IsDeleted = 0
          AND i.InvoiceDate BETWEEN @FromDate AND @ToDate
          AND (@CustomerId IS NULL OR i.CustomerId = @CustomerId);
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END
GO

IF OBJECT_ID('billing.usp_GetAgingReport', 'P') IS NOT NULL
    DROP PROCEDURE billing.usp_GetAgingReport;
GO

CREATE PROCEDURE billing.usp_GetAgingReport
    @AsOfDate DATE = NULL
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        DECLARE @Today DATE = ISNULL(@AsOfDate, CAST(SYSUTCDATETIME() AS DATE));

        SELECT
            i.Id, i.InvoiceNo, i.CustomerId, c.Name AS CustomerName,
            i.InvoiceDate, i.DueDate,
            i.TotalAmount - ISNULL(p.PaidAmount, 0) - i.DeductionAmount AS OutstandingAmount,
            DATEDIFF(DAY, i.DueDate, @Today) AS DaysOverdue
        FROM billing.Invoices i
        INNER JOIN billing.Customers c ON c.Id = i.CustomerId
        INNER JOIN lookup.StatusCodes sc ON sc.Id = i.StatusId
        OUTER APPLY (
            SELECT SUM(pay.Amount) AS PaidAmount
            FROM billing.Payments pay
            WHERE pay.InvoiceId = i.Id AND pay.IsDeleted = 0
        ) p
        WHERE i.IsDeleted = 0
          AND sc.Name NOT IN ('Void', 'Paid')
          AND (i.TotalAmount - ISNULL(p.PaidAmount, 0) - i.DeductionAmount) > 0
        ORDER BY DaysOverdue DESC;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END
GO

IF OBJECT_ID('billing.usp_InsertPayment', 'P') IS NOT NULL
    DROP PROCEDURE billing.usp_InsertPayment;
GO

CREATE PROCEDURE billing.usp_InsertPayment
    @PaymentDate  DATE,
    @Amount       DECIMAL(18,2),
    @Method       NVARCHAR(50),
    @InvoiceId    INT = NULL,
    @ShipmentId   INT = NULL,
    @ReferenceNo  NVARCHAR(100) = NULL,
    @CreatedBy    NVARCHAR(256)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        INSERT INTO billing.Payments (InvoiceId, ShipmentId, PaymentDate, Amount, Method, ReferenceNo, CreatedBy)
        VALUES (@InvoiceId, @ShipmentId, @PaymentDate, @Amount, @Method, @ReferenceNo, @CreatedBy);

        DECLARE @NewPaymentId INT = SCOPE_IDENTITY();

        -- Invoice status auto-transition only applies to invoice-targeted
        -- payments - a shipment-targeted (ToPay) collection has no invoice
        -- to update.
        IF @InvoiceId IS NOT NULL
        BEGIN
            DECLARE @TotalAmount DECIMAL(18,2), @TotalPaid DECIMAL(18,2), @DeductionAmount DECIMAL(18,2);
            SELECT @TotalAmount = TotalAmount, @DeductionAmount = DeductionAmount FROM billing.Invoices WHERE Id = @InvoiceId;
            SELECT @TotalPaid = ISNULL(SUM(Amount), 0) FROM billing.Payments WHERE InvoiceId = @InvoiceId AND IsDeleted = 0;

            DECLARE @NewStatusName NVARCHAR(50) = CASE
                WHEN @TotalPaid + @DeductionAmount >= @TotalAmount THEN 'Paid'
                WHEN @TotalPaid + @DeductionAmount > 0 THEN 'Partially Paid'
                ELSE NULL
            END;

            IF @NewStatusName IS NOT NULL
            BEGIN
                UPDATE i
                SET i.StatusId = sc.Id, i.ModifiedBy = @CreatedBy, i.ModifiedAt = SYSUTCDATETIME()
                FROM billing.Invoices i
                INNER JOIN lookup.StatusCodes sc ON sc.Category = 'Invoice' AND sc.Name = @NewStatusName
                WHERE i.Id = @InvoiceId
                  AND i.StatusId NOT IN (SELECT Id FROM lookup.StatusCodes WHERE Category = 'Invoice' AND Name = 'Void');
            END
        END

        COMMIT TRANSACTION;

        SELECT @NewPaymentId AS NewId;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0
            ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END
GO

IF OBJECT_ID('billing.usp_DeletePayment', 'P') IS NOT NULL
    DROP PROCEDURE billing.usp_DeletePayment;
GO

CREATE PROCEDURE billing.usp_DeletePayment
    @PaymentId   INT,
    @ModifiedBy  NVARCHAR(256),
    @Success     BIT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        DECLARE @InvoiceId INT;
        SELECT @InvoiceId = InvoiceId FROM billing.Payments WHERE Id = @PaymentId AND IsDeleted = 0;

        UPDATE billing.Payments
        SET IsDeleted = 1, ModifiedBy = @ModifiedBy, ModifiedAt = SYSUTCDATETIME()
        WHERE Id = @PaymentId AND IsDeleted = 0;

        SET @Success = CASE WHEN @@ROWCOUNT > 0 THEN 1 ELSE 0 END;

        -- Re-evaluate status downward too (e.g. a Paid invoice whose only
        -- payment gets removed by mistake should fall back to Sent, not
        -- stay stuck showing Paid) - same three-way rule as on insert.
        IF @Success = 1 AND @InvoiceId IS NOT NULL
        BEGIN
            DECLARE @TotalAmount DECIMAL(18,2), @TotalPaid DECIMAL(18,2), @DeductionAmount DECIMAL(18,2);
            SELECT @TotalAmount = TotalAmount, @DeductionAmount = DeductionAmount FROM billing.Invoices WHERE Id = @InvoiceId;
            SELECT @TotalPaid = ISNULL(SUM(Amount), 0) FROM billing.Payments WHERE InvoiceId = @InvoiceId AND IsDeleted = 0;

            DECLARE @NewStatusName NVARCHAR(50) = CASE
                WHEN @TotalPaid + @DeductionAmount >= @TotalAmount AND @TotalAmount > 0 THEN 'Paid'
                WHEN @TotalPaid + @DeductionAmount > 0 THEN 'Partially Paid'
                ELSE 'Sent'
            END;

            UPDATE i
            SET i.StatusId = sc.Id, i.ModifiedBy = @ModifiedBy, i.ModifiedAt = SYSUTCDATETIME()
            FROM billing.Invoices i
            INNER JOIN lookup.StatusCodes sc ON sc.Category = 'Invoice' AND sc.Name = @NewStatusName
            WHERE i.Id = @InvoiceId
              AND i.StatusId NOT IN (SELECT Id FROM lookup.StatusCodes WHERE Category = 'Invoice' AND Name = 'Void');
        END

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0
            ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END
GO
