/*
  Purpose:      Phase 1 (F1 + F2) programmability. Regenerates
                ops.usp_InsertShipment to accept consignor/consignee/freight-
                payment-type fields and to atomically reserve a consignment-
                note number and insert the ops.ConsignmentNotes row in the
                SAME transaction as the shipment insert (so a failed save
                never leaves an orphaned sequence gap). Regenerates
                ops.usp_GetShipments/usp_GetShipmentById/usp_UpdateShipment
                for the new columns, billing.usp_InsertPayment to accept a
                Shipment target instead of only an Invoice, and
                billing.usp_GetUninvoicedShipments to only return
                ToBeBilled shipments. Adds consignment-note read/cancel procs
                and the primary-branch procs the numbering depends on.
  Author:       TransitCore rebuild
  Date:         2026-09-24
  Dependencies: 01-schema/014_freight_parties_consignment_notes_schema.sql
*/
SET NOCOUNT ON;
GO

-- ops.Shipments has a filtered unique index (TrackingNo WHERE NOT NULL,
-- see 012_ops_phase3_schema.sql). SQL Server bakes the session's
-- QUOTED_IDENTIFIER setting into a procedure at CREATE time and uses that
-- forever after, regardless of the caller's own session setting - so every
-- proc in this file that touches ops.Shipments (or is created in the same
-- batch stream as one that does) needs this ON, not just the CREATE INDEX
-- statement itself. run-all.sql's single chained session already has this
-- ON from 012 onward; this file sets it explicitly too since it may also be
-- run standalone.
SET QUOTED_IDENTIFIER ON;
GO

-- ========== auth: primary branch ==========

IF OBJECT_ID('auth.usp_GetPrimaryBranchId', 'P') IS NOT NULL
    DROP PROCEDURE auth.usp_GetPrimaryBranchId;
GO

CREATE PROCEDURE auth.usp_GetPrimaryBranchId
    @UserId INT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        SELECT BranchId FROM auth.UserBranches WHERE UserId = @UserId AND IsPrimary = 1;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END
GO

IF OBJECT_ID('auth.usp_SetPrimaryBranch', 'P') IS NOT NULL
    DROP PROCEDURE auth.usp_SetPrimaryBranch;
GO

CREATE PROCEDURE auth.usp_SetPrimaryBranch
    @UserId    INT,
    @BranchId  INT,
    @Success   BIT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    BEGIN TRY
        BEGIN TRANSACTION;

        -- The user must already be assigned to this branch (via the
        -- existing BranchIds list on usp_InsertUser/usp_UpdateUser) - this
        -- proc only designates which of their existing branches is primary,
        -- it doesn't grant a new branch assignment.
        IF NOT EXISTS (SELECT 1 FROM auth.UserBranches WHERE UserId = @UserId AND BranchId = @BranchId)
        BEGIN
            SET @Success = 0;
        END
        ELSE
        BEGIN
            UPDATE auth.UserBranches SET IsPrimary = 0 WHERE UserId = @UserId AND IsPrimary = 1;
            UPDATE auth.UserBranches SET IsPrimary = 1 WHERE UserId = @UserId AND BranchId = @BranchId;
            SET @Success = 1;
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

-- ========== ops.usp_InsertShipment: parties, payment type, CN generation ==========

IF OBJECT_ID('ops.usp_InsertShipment', 'P') IS NOT NULL
    DROP PROCEDURE ops.usp_InsertShipment;
GO

CREATE PROCEDURE ops.usp_InsertShipment
    @CustomerId           INT,
    @OriginCityId         INT,
    @DestinationCityId    INT,
    @StatusId             INT,
    @ShipmentDate         DATE,
    @FreightPaymentTypeId INT,
    @BranchId             INT,
    @FinancialYearCode    CHAR(4),
    @TripId               INT = NULL,
    @ConsignorCustomerId  INT = NULL,
    @ConsignorName        NVARCHAR(200) = NULL,
    @ConsignorAddress     NVARCHAR(300) = NULL,
    @ConsignorPhone       NVARCHAR(30) = NULL,
    @ConsigneeCustomerId  INT = NULL,
    @ConsigneeName        NVARCHAR(200) = NULL,
    @ConsigneeAddress     NVARCHAR(300) = NULL,
    @ConsigneePhone       NVARCHAR(30) = NULL,
    @CreatedBy            NVARCHAR(256),
    @Items                ops.ShipmentItemType READONLY
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        INSERT INTO ops.Shipments
            (TripId, CustomerId, OriginCityId, DestinationCityId, StatusId, ShipmentDate,
             FreightPaymentTypeId, ConsignorCustomerId, ConsignorName, ConsignorAddress, ConsignorPhone,
             ConsigneeCustomerId, ConsigneeName, ConsigneeAddress, ConsigneePhone, CreatedBy)
        VALUES
            (@TripId, @CustomerId, @OriginCityId, @DestinationCityId, @StatusId, @ShipmentDate,
             @FreightPaymentTypeId, @ConsignorCustomerId, @ConsignorName, @ConsignorAddress, @ConsignorPhone,
             @ConsigneeCustomerId, @ConsigneeName, @ConsigneeAddress, @ConsigneePhone, @CreatedBy);

        DECLARE @NewShipmentId INT = SCOPE_IDENTITY();

        UPDATE ops.Shipments
        SET TrackingNo = 'TRK' + RIGHT('000000' + CAST(@NewShipmentId AS VARCHAR(6)), 6)
        WHERE Id = @NewShipmentId;

        INSERT INTO ops.ShipmentItems (ShipmentId, Description, Quantity, UnitOfMeasureId, WeightKg, CreatedBy)
        SELECT @NewShipmentId, Description, Quantity, UnitOfMeasureId, WeightKg, @CreatedBy
        FROM @Items;

        -- ---- Consignment note: atomic sequence reservation + insert ----
        -- Both happen in this same transaction as the shipment insert above,
        -- so a rollback (e.g. an FK violation on a bad UnitOfMeasureId in
        -- @Items) undoes the sequence increment too - no gaps from failed
        -- saves. UPDLOCK+HOLDLOCK on the counter row serializes concurrent
        -- inserts for the same (Branch, FinancialYear) instead of letting
        -- them race on a read-then-write.
        DECLARE @BranchCode NVARCHAR(10);
        SELECT @BranchCode = Code FROM lookup.Branches WHERE Id = @BranchId;

        IF NOT EXISTS (
            SELECT 1 FROM ops.ConsignmentNoteSequences WITH (UPDLOCK, HOLDLOCK)
            WHERE BranchId = @BranchId AND FinancialYearCode = @FinancialYearCode
        )
            INSERT INTO ops.ConsignmentNoteSequences (BranchId, FinancialYearCode, LastSequence)
            VALUES (@BranchId, @FinancialYearCode, 0);

        DECLARE @NextSeq INT;
        UPDATE ops.ConsignmentNoteSequences WITH (UPDLOCK, HOLDLOCK)
        SET @NextSeq = LastSequence = LastSequence + 1
        WHERE BranchId = @BranchId AND FinancialYearCode = @FinancialYearCode;

        DECLARE @FormatTemplate NVARCHAR(100), @SequencePadding INT;
        SELECT TOP (1) @FormatTemplate = FormatTemplate, @SequencePadding = SequencePadding
        FROM ops.ConsignmentNoteNumberFormats
        WHERE IsDeleted = 0 AND (BranchId = @BranchId OR BranchId IS NULL)
        ORDER BY CASE WHEN BranchId = @BranchId THEN 0 ELSE 1 END;

        DECLARE @CnNumber NVARCHAR(50) = REPLACE(REPLACE(REPLACE(
            @FormatTemplate,
            '{BRANCH}', @BranchCode),
            '{FY}', @FinancialYearCode),
            '{SEQ}', RIGHT(REPLICATE('0', @SequencePadding) + CAST(@NextSeq AS VARCHAR(10)), @SequencePadding));

        DECLARE @BookedStatusId INT = (SELECT Id FROM lookup.StatusCodes WHERE Category = 'Shipment' AND Code = 'BOOKED');

        INSERT INTO ops.ConsignmentNotes (ShipmentId, CnNumber, BranchId, CnDate, StatusId, CreatedBy)
        VALUES (@NewShipmentId, @CnNumber, @BranchId, @ShipmentDate, @BookedStatusId, @CreatedBy);

        COMMIT TRANSACTION;

        SELECT @NewShipmentId AS ShipmentId;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0
            ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END
GO

-- ========== ops.usp_UpdateShipment: parties + payment type editable too ==========

IF OBJECT_ID('ops.usp_UpdateShipment', 'P') IS NOT NULL
    DROP PROCEDURE ops.usp_UpdateShipment;
GO

CREATE PROCEDURE ops.usp_UpdateShipment
    @ShipmentId           INT,
    @CustomerId           INT,
    @OriginCityId         INT,
    @DestinationCityId    INT,
    @StatusId             INT,
    @ShipmentDate         DATE,
    @FreightPaymentTypeId INT,
    @ConsignorCustomerId  INT = NULL,
    @ConsignorName        NVARCHAR(200) = NULL,
    @ConsignorAddress     NVARCHAR(300) = NULL,
    @ConsignorPhone       NVARCHAR(30) = NULL,
    @ConsigneeCustomerId  INT = NULL,
    @ConsigneeName        NVARCHAR(200) = NULL,
    @ConsigneeAddress     NVARCHAR(300) = NULL,
    @ConsigneePhone       NVARCHAR(30) = NULL,
    @ModifiedBy           NVARCHAR(256),
    @IsUpdated            BIT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        UPDATE ops.Shipments
        SET CustomerId           = @CustomerId,
            OriginCityId         = @OriginCityId,
            DestinationCityId    = @DestinationCityId,
            StatusId             = @StatusId,
            ShipmentDate         = @ShipmentDate,
            FreightPaymentTypeId = @FreightPaymentTypeId,
            ConsignorCustomerId  = @ConsignorCustomerId,
            ConsignorName        = @ConsignorName,
            ConsignorAddress     = @ConsignorAddress,
            ConsignorPhone       = @ConsignorPhone,
            ConsigneeCustomerId  = @ConsigneeCustomerId,
            ConsigneeName        = @ConsigneeName,
            ConsigneeAddress     = @ConsigneeAddress,
            ConsigneePhone       = @ConsigneePhone,
            ModifiedBy           = @ModifiedBy,
            ModifiedAt           = SYSUTCDATETIME()
        WHERE Id = @ShipmentId AND IsDeleted = 0;

        SET @IsUpdated = CASE WHEN @@ROWCOUNT > 0 THEN 1 ELSE 0 END;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END
GO

-- ========== ops.usp_GetShipments / usp_GetShipmentById: new columns ==========

IF OBJECT_ID('ops.usp_GetShipments', 'P') IS NOT NULL
    DROP PROCEDURE ops.usp_GetShipments;
GO

CREATE PROCEDURE ops.usp_GetShipments
    @CustomerId INT = NULL,
    @StatusId   INT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        SELECT
            s.Id, s.TripId, s.CustomerId, c.Name AS CustomerName,
            s.OriginCityId, oc.Name AS OriginCityName,
            s.DestinationCityId, dc.Name AS DestinationCityName,
            s.StatusId, sc.Name AS StatusName, s.ShipmentDate, s.TrackingNo,
            s.FreightPaymentTypeId, fpt.Name AS FreightPaymentTypeName,
            s.ConsignorCustomerId, cc.Name AS ConsignorCustomerName, s.ConsignorName, s.ConsignorAddress, s.ConsignorPhone,
            s.ConsigneeCustomerId, ce.Name AS ConsigneeCustomerName, s.ConsigneeName, s.ConsigneeAddress, s.ConsigneePhone,
            cn.CnNumber
        FROM ops.Shipments s
        INNER JOIN billing.Customers c ON c.Id = s.CustomerId
        INNER JOIN lookup.Cities oc ON oc.Id = s.OriginCityId
        INNER JOIN lookup.Cities dc ON dc.Id = s.DestinationCityId
        INNER JOIN lookup.StatusCodes sc ON sc.Id = s.StatusId
        INNER JOIN lookup.StatusCodes fpt ON fpt.Id = s.FreightPaymentTypeId
        LEFT JOIN billing.Customers cc ON cc.Id = s.ConsignorCustomerId
        LEFT JOIN billing.Customers ce ON ce.Id = s.ConsigneeCustomerId
        LEFT JOIN ops.ConsignmentNotes cn ON cn.ShipmentId = s.Id
        WHERE s.IsDeleted = 0
          AND (@CustomerId IS NULL OR s.CustomerId = @CustomerId)
          AND (@StatusId IS NULL OR s.StatusId = @StatusId)
        ORDER BY s.ShipmentDate DESC;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END
GO

IF OBJECT_ID('ops.usp_GetShipmentById', 'P') IS NOT NULL
    DROP PROCEDURE ops.usp_GetShipmentById;
GO

CREATE PROCEDURE ops.usp_GetShipmentById
    @ShipmentId INT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        SELECT
            s.Id, s.TripId, s.CustomerId, c.Name AS CustomerName,
            s.OriginCityId, oc.Name AS OriginCityName,
            s.DestinationCityId, dc.Name AS DestinationCityName,
            s.StatusId, sc.Name AS StatusName, s.ShipmentDate, s.TrackingNo,
            s.FreightPaymentTypeId, fpt.Name AS FreightPaymentTypeName,
            s.ConsignorCustomerId, cc.Name AS ConsignorCustomerName, s.ConsignorName, s.ConsignorAddress, s.ConsignorPhone,
            s.ConsigneeCustomerId, ce.Name AS ConsigneeCustomerName, s.ConsigneeName, s.ConsigneeAddress, s.ConsigneePhone,
            cn.CnNumber
        FROM ops.Shipments s
        INNER JOIN billing.Customers c ON c.Id = s.CustomerId
        INNER JOIN lookup.Cities oc ON oc.Id = s.OriginCityId
        INNER JOIN lookup.Cities dc ON dc.Id = s.DestinationCityId
        INNER JOIN lookup.StatusCodes sc ON sc.Id = s.StatusId
        INNER JOIN lookup.StatusCodes fpt ON fpt.Id = s.FreightPaymentTypeId
        LEFT JOIN billing.Customers cc ON cc.Id = s.ConsignorCustomerId
        LEFT JOIN billing.Customers ce ON ce.Id = s.ConsigneeCustomerId
        LEFT JOIN ops.ConsignmentNotes cn ON cn.ShipmentId = s.Id
        WHERE s.Id = @ShipmentId AND s.IsDeleted = 0;

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

-- ========== Consignment note: read + cancel ==========

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

IF OBJECT_ID('ops.usp_CancelConsignmentNote', 'P') IS NOT NULL
    DROP PROCEDURE ops.usp_CancelConsignmentNote;
GO

CREATE PROCEDURE ops.usp_CancelConsignmentNote
    @ShipmentId     INT,
    @CancelReason   NVARCHAR(500),
    @CancelledBy    NVARCHAR(256),
    @Success        BIT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        DECLARE @CancelledStatusId INT = (SELECT Id FROM lookup.StatusCodes WHERE Category = 'Shipment' AND Code = 'CANCELLED');

        UPDATE cn
        SET StatusId = @CancelledStatusId,
            CancelReason = @CancelReason,
            CancelledAt = SYSUTCDATETIME(),
            CancelledBy = @CancelledBy,
            ModifiedBy = @CancelledBy,
            ModifiedAt = SYSUTCDATETIME()
        FROM ops.ConsignmentNotes cn
        WHERE cn.ShipmentId = @ShipmentId
          AND cn.StatusId <> @CancelledStatusId;

        SET @Success = CASE WHEN @@ROWCOUNT > 0 THEN 1 ELSE 0 END;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END
GO

-- ========== billing.usp_InsertPayment: allow a Shipment target ==========

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
            DECLARE @TotalAmount DECIMAL(18,2), @TotalPaid DECIMAL(18,2);
            SELECT @TotalAmount = TotalAmount FROM billing.Invoices WHERE Id = @InvoiceId;
            SELECT @TotalPaid = ISNULL(SUM(Amount), 0) FROM billing.Payments WHERE InvoiceId = @InvoiceId AND IsDeleted = 0;

            DECLARE @NewStatusName NVARCHAR(50) = CASE
                WHEN @TotalPaid >= @TotalAmount THEN 'Paid'
                WHEN @TotalPaid > 0 THEN 'Partially Paid'
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

-- ========== billing.usp_GetUninvoicedShipments: ToBeBilled only ==========

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
            r.DistanceKm AS RouteDistanceKm
        FROM ops.Shipments sh
        INNER JOIN lookup.Cities oc ON oc.Id = sh.OriginCityId
        INNER JOIN lookup.Cities dc ON dc.Id = sh.DestinationCityId
        LEFT JOIN ops.Trips t ON t.Id = sh.TripId AND t.IsDeleted = 0
        LEFT JOIN ops.Routes r ON r.Id = t.RouteId
        WHERE sh.CustomerId = @CustomerId
          AND sh.IsDeleted = 0
          AND sh.ShipmentDate BETWEEN @FromDate AND @ToDate
          -- Only bill shipments actually meant to be billed later - Paid
          -- (collected at booking) and ToPay (collected at delivery) never
          -- flow through the invoice-from-shipments path.
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
