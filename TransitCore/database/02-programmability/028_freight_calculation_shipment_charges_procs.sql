/*
  Purpose:      Phase 3 (F4) programmability. Regenerates billing.RateCards
                read/insert for the new Basis/MinimumChargeableWeightKg/
                extra-rate columns, billing.InvoiceLineType (TVP - drop and
                recreate, can't ALTER) and billing.usp_InsertInvoice for
                ShipmentChargeId, and billing.usp_GetInvoiceById to project
                it. Adds billing.ShipmentCharges CRUD, a new
                usp_GetApplicableRateCards for the "most specific card wins"
                match (ranking itself happens in C# - see
                FreightCalculator/RateCardMatcher - matching the existing
                usp_GetUninvoicedShipments comment that this business logic
                belongs outside T-SQL), ops.TripStopVisits upsert/read for
                detention time tracking, and usp_InsertInvoiceFromCharges to
                build an invoice directly from a set of ShipmentCharges.
  Author:       TransitCore rebuild
  Date:         2026-10-02
  Dependencies: 01-schema/017_freight_calculation_shipment_charges_schema.sql
*/
SET QUOTED_IDENTIFIER ON;
GO
SET NOCOUNT ON;
GO

-- ========== billing.RateCards: regenerated read/insert ==========

IF OBJECT_ID('billing.usp_GetRateCards', 'P') IS NOT NULL
    DROP PROCEDURE billing.usp_GetRateCards;
GO

CREATE PROCEDURE billing.usp_GetRateCards
    @CustomerId INT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        SELECT
            r.Id, r.CustomerId, c.Name AS CustomerName,
            r.OriginCityId, oc.Name AS OriginCityName,
            r.DestinationCityId, dc.Name AS DestinationCityName,
            r.RatePerKg, r.RatePerKm, r.Basis, r.RatePerTrip, r.RatePerTon, r.RatePerPackage,
            r.MinimumChargeableWeightKg, r.LoadingRatePerEvent, r.UnloadingRatePerEvent,
            r.DetentionFreeHours, r.DetentionRatePerHour, r.HaltingRatePerDay,
            r.EffectiveFrom, r.EffectiveTo
        FROM billing.RateCards r
        LEFT JOIN billing.Customers c ON c.Id = r.CustomerId
        LEFT JOIN lookup.Cities oc ON oc.Id = r.OriginCityId
        LEFT JOIN lookup.Cities dc ON dc.Id = r.DestinationCityId
        WHERE r.IsDeleted = 0
          AND (@CustomerId IS NULL OR r.CustomerId = @CustomerId OR r.CustomerId IS NULL)
        ORDER BY r.EffectiveFrom DESC;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END
GO

IF OBJECT_ID('billing.usp_InsertRateCard', 'P') IS NOT NULL
    DROP PROCEDURE billing.usp_InsertRateCard;
GO

CREATE PROCEDURE billing.usp_InsertRateCard
    @CustomerId                INT = NULL,
    @OriginCityId              INT = NULL,
    @DestinationCityId         INT = NULL,
    @RatePerKg                 DECIMAL(18,2) = 0,
    @RatePerKm                 DECIMAL(18,2) = 0,
    @Basis                     NVARCHAR(20) = 'PerKm',
    @RatePerTrip                DECIMAL(18,2) = NULL,
    @RatePerTon                 DECIMAL(18,2) = NULL,
    @RatePerPackage             DECIMAL(18,2) = NULL,
    @MinimumChargeableWeightKg  DECIMAL(18,2) = NULL,
    @LoadingRatePerEvent        DECIMAL(18,2) = NULL,
    @UnloadingRatePerEvent      DECIMAL(18,2) = NULL,
    @DetentionFreeHours         DECIMAL(18,2) = NULL,
    @DetentionRatePerHour       DECIMAL(18,2) = NULL,
    @HaltingRatePerDay          DECIMAL(18,2) = NULL,
    @EffectiveFrom              DATE,
    @EffectiveTo                DATE = NULL,
    @CreatedBy                  NVARCHAR(256)
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        INSERT INTO billing.RateCards
            (CustomerId, OriginCityId, DestinationCityId, RatePerKg, RatePerKm, Basis, RatePerTrip, RatePerTon,
             RatePerPackage, MinimumChargeableWeightKg, LoadingRatePerEvent, UnloadingRatePerEvent,
             DetentionFreeHours, DetentionRatePerHour, HaltingRatePerDay, EffectiveFrom, EffectiveTo, CreatedBy)
        VALUES
            (@CustomerId, @OriginCityId, @DestinationCityId, @RatePerKg, @RatePerKm, @Basis, @RatePerTrip, @RatePerTon,
             @RatePerPackage, @MinimumChargeableWeightKg, @LoadingRatePerEvent, @UnloadingRatePerEvent,
             @DetentionFreeHours, @DetentionRatePerHour, @HaltingRatePerDay, @EffectiveFrom, @EffectiveTo, @CreatedBy);

        SELECT CAST(SCOPE_IDENTITY() AS INT) AS NewId;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END
GO

-- Candidate rate cards for a shipment - compatible (Customer/Origin/Dest
-- NULL-or-matching) AND effective as of the given date. Ranking ("most
-- specific wins") happens in C# (RateCardMatcher), not here.
IF OBJECT_ID('billing.usp_GetApplicableRateCards', 'P') IS NOT NULL
    DROP PROCEDURE billing.usp_GetApplicableRateCards;
GO

CREATE PROCEDURE billing.usp_GetApplicableRateCards
    @CustomerId          INT,
    @OriginCityId        INT,
    @DestinationCityId   INT,
    @AsOfDate            DATE
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        SELECT
            r.Id, r.CustomerId, c.Name AS CustomerName,
            r.OriginCityId, oc.Name AS OriginCityName,
            r.DestinationCityId, dc.Name AS DestinationCityName,
            r.RatePerKg, r.RatePerKm, r.Basis, r.RatePerTrip, r.RatePerTon, r.RatePerPackage,
            r.MinimumChargeableWeightKg, r.LoadingRatePerEvent, r.UnloadingRatePerEvent,
            r.DetentionFreeHours, r.DetentionRatePerHour, r.HaltingRatePerDay,
            r.EffectiveFrom, r.EffectiveTo
        FROM billing.RateCards r
        LEFT JOIN billing.Customers c ON c.Id = r.CustomerId
        LEFT JOIN lookup.Cities oc ON oc.Id = r.OriginCityId
        LEFT JOIN lookup.Cities dc ON dc.Id = r.DestinationCityId
        WHERE r.IsDeleted = 0
          AND (r.CustomerId IS NULL OR r.CustomerId = @CustomerId)
          AND (r.OriginCityId IS NULL OR r.OriginCityId = @OriginCityId)
          AND (r.DestinationCityId IS NULL OR r.DestinationCityId = @DestinationCityId)
          AND r.EffectiveFrom <= @AsOfDate
          AND (r.EffectiveTo IS NULL OR r.EffectiveTo >= @AsOfDate);
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END
GO

-- ========== billing.ShipmentCharges ==========

IF OBJECT_ID('billing.usp_GetShipmentCharges', 'P') IS NOT NULL
    DROP PROCEDURE billing.usp_GetShipmentCharges;
GO

CREATE PROCEDURE billing.usp_GetShipmentCharges
    @ShipmentId INT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        SELECT
            sc.Id, sc.ShipmentId, sc.ChargeType, sc.Amount, sc.Description,
            sc.IsOverridden, sc.OverrideReason,
            CASE WHEN il.Id IS NOT NULL THEN 1 ELSE 0 END AS IsInvoiced,
            sc.CreatedAt, sc.CreatedBy
        FROM billing.ShipmentCharges sc
        LEFT JOIN billing.InvoiceLines il ON il.ShipmentChargeId = sc.Id AND il.IsDeleted = 0
        WHERE sc.ShipmentId = @ShipmentId AND sc.IsDeleted = 0
        ORDER BY sc.CreatedAt;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END
GO

IF OBJECT_ID('billing.usp_InsertShipmentCharge', 'P') IS NOT NULL
    DROP PROCEDURE billing.usp_InsertShipmentCharge;
GO

CREATE PROCEDURE billing.usp_InsertShipmentCharge
    @ShipmentId      INT,
    @ChargeType      NVARCHAR(20),
    @Amount          DECIMAL(18,2),
    @Description     NVARCHAR(300) = NULL,
    @IsOverridden    BIT = 0,
    @OverrideReason  NVARCHAR(500) = NULL,
    @CreatedBy       NVARCHAR(256),
    @Success         BIT OUTPUT,
    @ErrorMessage    NVARCHAR(500) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        SET @Success = 0;
        SET @ErrorMessage = NULL;

        IF NOT EXISTS (SELECT 1 FROM ops.Shipments WHERE Id = @ShipmentId AND IsDeleted = 0)
        BEGIN
            SET @ErrorMessage = 'Shipment not found';
            RETURN;
        END

        IF @ChargeType = 'Other' AND @Description IS NULL
        BEGIN
            SET @ErrorMessage = 'A description is required for an Other charge';
            RETURN;
        END

        IF @IsOverridden = 1 AND @OverrideReason IS NULL
        BEGIN
            SET @ErrorMessage = 'A reason is required when overriding a charge amount';
            RETURN;
        END

        INSERT INTO billing.ShipmentCharges (ShipmentId, ChargeType, Amount, Description, IsOverridden, OverrideReason, CreatedBy)
        VALUES (@ShipmentId, @ChargeType, @Amount, @Description, @IsOverridden, @OverrideReason, @CreatedBy);

        SET @Success = 1;
        SELECT CAST(SCOPE_IDENTITY() AS INT) AS NewId;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END
GO

IF OBJECT_ID('billing.usp_DeleteShipmentCharge', 'P') IS NOT NULL
    DROP PROCEDURE billing.usp_DeleteShipmentCharge;
GO

CREATE PROCEDURE billing.usp_DeleteShipmentCharge
    @Id           INT,
    @ModifiedBy   NVARCHAR(256),
    @Success      BIT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        -- UPDATE ... FROM with an aliased target (not a bare UPDATE
        -- billing.ShipmentCharges) so the correlated subquery's "Id" can't
        -- be misread as InvoiceLines.Id (its own PK column) instead of
        -- ShipmentCharges.Id - caught by testing this against a genuinely
        -- invoiced charge, not by inspection; the unqualified form silently
        -- let an invoiced charge be deleted.
        UPDATE sc
        SET IsDeleted = 1, ModifiedBy = @ModifiedBy, ModifiedAt = SYSUTCDATETIME()
        FROM billing.ShipmentCharges sc
        WHERE sc.Id = @Id AND sc.IsDeleted = 0
          -- Never remove a charge that's already been billed on a real
          -- invoice line - same "never touch a billed/financial record"
          -- spirit as the rest of this codebase.
          AND NOT EXISTS (SELECT 1 FROM billing.InvoiceLines il WHERE il.ShipmentChargeId = sc.Id AND il.IsDeleted = 0);

        SET @Success = CASE WHEN @@ROWCOUNT > 0 THEN 1 ELSE 0 END;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END
GO

-- ========== ops.TripStopVisits: arrival / departure per stop ==========

IF OBJECT_ID('ops.usp_GetTripStopVisits', 'P') IS NOT NULL
    DROP PROCEDURE ops.usp_GetTripStopVisits;
GO

CREATE PROCEDURE ops.usp_GetTripStopVisits
    @TripId INT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        SELECT
            tsv.Id, tsv.TripId, tsv.StopType, tsv.RouteStopId,
            CASE tsv.StopType
                WHEN 'Origin' THEN oc.Name
                WHEN 'Destination' THEN dc.Name
                ELSE rsc.Name
            END AS StopCityName,
            tsv.ArrivedAt, tsv.DepartedAt,
            CASE WHEN tsv.ArrivedAt IS NOT NULL AND tsv.DepartedAt IS NOT NULL
                 THEN DATEDIFF(MINUTE, tsv.ArrivedAt, tsv.DepartedAt) / 60.0
                 ELSE NULL
            END AS DwellHours
        FROM ops.TripStopVisits tsv
        INNER JOIN ops.Trips t ON t.Id = tsv.TripId
        INNER JOIN ops.Routes r ON r.Id = t.RouteId
        INNER JOIN lookup.Cities oc ON oc.Id = r.OriginCityId
        INNER JOIN lookup.Cities dc ON dc.Id = r.DestinationCityId
        LEFT JOIN ops.RouteStops rs ON rs.Id = tsv.RouteStopId
        LEFT JOIN lookup.Cities rsc ON rsc.Id = rs.CityId
        WHERE tsv.TripId = @TripId AND tsv.IsDeleted = 0
        ORDER BY (CASE tsv.StopType WHEN 'Origin' THEN 0 WHEN 'IntermediateStop' THEN 1 ELSE 2 END) * 100000 + ISNULL(rs.StopOrder, 0);
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END
GO

IF OBJECT_ID('ops.usp_UpsertTripStopVisit', 'P') IS NOT NULL
    DROP PROCEDURE ops.usp_UpsertTripStopVisit;
GO

CREATE PROCEDURE ops.usp_UpsertTripStopVisit
    @TripId        INT,
    @StopType      NVARCHAR(20),
    @RouteStopId   INT = NULL,
    @ArrivedAt     DATETIME2(3) = NULL,
    @DepartedAt    DATETIME2(3) = NULL,
    @CreatedBy     NVARCHAR(256)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    BEGIN TRY
        BEGIN TRANSACTION;

        IF NOT EXISTS (
            SELECT 1 FROM ops.TripStopVisits
            WHERE TripId = @TripId AND StopType = @StopType
              AND ((RouteStopId = @RouteStopId) OR (RouteStopId IS NULL AND @RouteStopId IS NULL))
              AND IsDeleted = 0
        )
            INSERT INTO ops.TripStopVisits (TripId, StopType, RouteStopId, ArrivedAt, DepartedAt, CreatedBy)
            VALUES (@TripId, @StopType, @RouteStopId, @ArrivedAt, @DepartedAt, @CreatedBy);
        ELSE
            UPDATE ops.TripStopVisits
            SET ArrivedAt = ISNULL(@ArrivedAt, ArrivedAt),
                DepartedAt = ISNULL(@DepartedAt, DepartedAt),
                ModifiedBy = @CreatedBy,
                ModifiedAt = SYSUTCDATETIME()
            WHERE TripId = @TripId AND StopType = @StopType
              AND ((RouteStopId = @RouteStopId) OR (RouteStopId IS NULL AND @RouteStopId IS NULL))
              AND IsDeleted = 0;

        COMMIT TRANSACTION;

        SELECT Id, ArrivedAt, DepartedAt
        FROM ops.TripStopVisits
        WHERE TripId = @TripId AND StopType = @StopType
          AND ((RouteStopId = @RouteStopId) OR (RouteStopId IS NULL AND @RouteStopId IS NULL))
          AND IsDeleted = 0;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0
            ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END
GO

-- ========== billing.InvoiceLineType (TVP): ShipmentChargeId ==========

IF OBJECT_ID('billing.usp_InsertInvoice', 'P') IS NOT NULL
    DROP PROCEDURE billing.usp_InsertInvoice;
GO

IF EXISTS (SELECT 1 FROM sys.types WHERE name = 'InvoiceLineType' AND schema_id = SCHEMA_ID('billing'))
    DROP TYPE billing.InvoiceLineType;
GO

CREATE TYPE billing.InvoiceLineType AS TABLE
(
    ShipmentId        INT           NULL,
    ShipmentChargeId  INT           NULL,
    Description       NVARCHAR(300) NOT NULL,
    Quantity          DECIMAL(18,2) NOT NULL,
    UnitPrice         DECIMAL(18,2) NOT NULL,
    LineTotal         DECIMAL(18,2) NOT NULL
);
GO

CREATE PROCEDURE billing.usp_InsertInvoice
    @InvoiceNo       NVARCHAR(50),
    @CustomerId      INT,
    @InvoiceDate     DATE,
    @DueDate         DATE,
    @DiscountAmount  DECIMAL(18,2) = 0,
    @TaxAmount       DECIMAL(18,2),
    @StatusId        INT,
    @CreatedBy       NVARCHAR(256),
    @Lines           billing.InvoiceLineType READONLY
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        DECLARE @Subtotal DECIMAL(18,2) = (SELECT ISNULL(SUM(LineTotal), 0) FROM @Lines);
        DECLARE @Total DECIMAL(18,2) = @Subtotal - @DiscountAmount + @TaxAmount;

        INSERT INTO billing.Invoices
            (InvoiceNo, CustomerId, InvoiceDate, DueDate, Subtotal, DiscountAmount, TaxAmount, TotalAmount, StatusId, CreatedBy)
        VALUES
            (@InvoiceNo, @CustomerId, @InvoiceDate, @DueDate, @Subtotal, @DiscountAmount, @TaxAmount, @Total, @StatusId, @CreatedBy);

        DECLARE @NewInvoiceId INT = SCOPE_IDENTITY();

        INSERT INTO billing.InvoiceLines (InvoiceId, ShipmentId, ShipmentChargeId, Description, Quantity, UnitPrice, LineTotal, CreatedBy)
        SELECT @NewInvoiceId, ShipmentId, ShipmentChargeId, Description, Quantity, UnitPrice, LineTotal, @CreatedBy
        FROM @Lines;

        COMMIT TRANSACTION;

        SELECT @NewInvoiceId AS InvoiceId;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0
            ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END
GO

-- Builds an invoice directly from a set of ShipmentCharges - one InvoiceLine
-- per charge, all charges must belong to the same customer (via their
-- shipment's BillingParty/CustomerId) and not already be invoiced.
IF OBJECT_ID('billing.usp_InsertInvoiceFromCharges', 'P') IS NOT NULL
    DROP PROCEDURE billing.usp_InsertInvoiceFromCharges;
GO

CREATE PROCEDURE billing.usp_InsertInvoiceFromCharges
    @InvoiceNo         NVARCHAR(50),
    @CustomerId        INT,
    @InvoiceDate       DATE,
    @DueDate           DATE,
    @DiscountAmount    DECIMAL(18,2) = 0,
    @TaxAmount         DECIMAL(18,2),
    @StatusId          INT,
    @ShipmentChargeIds auth.IntList_TVP READONLY,
    @CreatedBy         NVARCHAR(256),
    @Success           BIT OUTPUT,
    @ErrorMessage      NVARCHAR(500) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRY
        SET @Success = 0;
        SET @ErrorMessage = NULL;

        IF NOT EXISTS (SELECT 1 FROM @ShipmentChargeIds)
        BEGIN
            SET @ErrorMessage = 'At least one charge is required';
            RETURN;
        END

        IF EXISTS (
            SELECT 1 FROM billing.ShipmentCharges sc
            INNER JOIN ops.Shipments sh ON sh.Id = sc.ShipmentId
            WHERE sc.Id IN (SELECT Id FROM @ShipmentChargeIds)
              AND (sc.IsDeleted = 1 OR sh.CustomerId <> @CustomerId)
        )
        BEGIN
            SET @ErrorMessage = 'One or more charges were not found or do not belong to this customer';
            RETURN;
        END

        IF EXISTS (
            SELECT 1 FROM billing.InvoiceLines il
            WHERE il.ShipmentChargeId IN (SELECT Id FROM @ShipmentChargeIds) AND il.IsDeleted = 0
        )
        BEGIN
            SET @ErrorMessage = 'One or more charges are already on an invoice';
            RETURN;
        END

        BEGIN TRANSACTION;

        DECLARE @Subtotal DECIMAL(18,2) = (
            SELECT ISNULL(SUM(sc.Amount), 0) FROM billing.ShipmentCharges sc WHERE sc.Id IN (SELECT Id FROM @ShipmentChargeIds)
        );
        DECLARE @Total DECIMAL(18,2) = @Subtotal - @DiscountAmount + @TaxAmount;

        INSERT INTO billing.Invoices
            (InvoiceNo, CustomerId, InvoiceDate, DueDate, Subtotal, DiscountAmount, TaxAmount, TotalAmount, StatusId, CreatedBy)
        VALUES
            (@InvoiceNo, @CustomerId, @InvoiceDate, @DueDate, @Subtotal, @DiscountAmount, @TaxAmount, @Total, @StatusId, @CreatedBy);

        DECLARE @NewInvoiceId INT = SCOPE_IDENTITY();

        INSERT INTO billing.InvoiceLines (InvoiceId, ShipmentId, ShipmentChargeId, Description, Quantity, UnitPrice, LineTotal, CreatedBy)
        SELECT @NewInvoiceId, sc.ShipmentId, sc.Id,
               CONCAT(sc.ChargeType, CASE WHEN sc.Description IS NOT NULL THEN CONCAT(' - ', sc.Description) ELSE '' END),
               1, sc.Amount, sc.Amount, @CreatedBy
        FROM billing.ShipmentCharges sc
        WHERE sc.Id IN (SELECT Id FROM @ShipmentChargeIds);

        COMMIT TRANSACTION;

        SET @Success = 1;
        SELECT @NewInvoiceId AS InvoiceId;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0
            ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END
GO

-- ========== billing.usp_GetUninvoicedShipments: package count for PerPackage basis ==========
-- Packages comes from the shipment's own ConsignmentNote (Phase 1) - a real
-- staff-entered figure, not derived from ShipmentItems row count, which
-- would conflate "line items" with "packages" (a line item's Quantity can
-- be in any unit of measure, not necessarily packages).

IF OBJECT_ID('billing.usp_GetUninvoicedShipments', 'P') IS NOT NULL
    DROP PROCEDURE billing.usp_GetUninvoicedShipments;
GO

CREATE PROCEDURE billing.usp_GetUninvoicedShipments
    @CustomerId  INT,
    @FromDate    DATE,
    @ToDate      DATE
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        SELECT
            sh.Id, sh.TrackingNo, sh.OriginCityId, oc.Name AS OriginCityName,
            sh.DestinationCityId, dc.Name AS DestinationCityName,
            sh.ShipmentDate,
            ISNULL((SELECT SUM(si.WeightKg) FROM ops.ShipmentItems si WHERE si.ShipmentId = sh.Id AND si.IsDeleted = 0), 0) AS TotalWeightKg,
            r.DistanceKm AS RouteDistanceKm,
            cn.Packages AS TotalPackages
        FROM ops.Shipments sh
        INNER JOIN lookup.Cities oc ON oc.Id = sh.OriginCityId
        INNER JOIN lookup.Cities dc ON dc.Id = sh.DestinationCityId
        LEFT JOIN ops.Trips t ON t.Id = sh.TripId AND t.IsDeleted = 0
        LEFT JOIN ops.Routes r ON r.Id = t.RouteId
        LEFT JOIN ops.ConsignmentNotes cn ON cn.ShipmentId = sh.Id
        WHERE sh.CustomerId = @CustomerId
          AND sh.IsDeleted = 0
          AND sh.ShipmentDate BETWEEN @FromDate AND @ToDate
          AND sh.FreightPaymentTypeId IN (SELECT Id FROM lookup.StatusCodes WHERE Category = 'FreightPaymentType' AND Code = 'TOBEBILLED')
          AND NOT EXISTS (
              SELECT 1 FROM billing.InvoiceLines il
              WHERE il.ShipmentId = sh.Id AND il.IsDeleted = 0
          )
        ORDER BY sh.ShipmentDate ASC;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END
GO

-- ========== billing.usp_GetInvoiceById: project ShipmentChargeId ==========

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
            ISNULL(p.PaidAmount, 0) AS PaidAmount
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
