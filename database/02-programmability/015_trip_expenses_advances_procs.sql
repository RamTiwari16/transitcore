/*
  Purpose:      Phase 3 (Ops depth) - trip expenses/advances CRUD and a cost
                summary (advances given vs expenses spent, both cash flows
                against the trip - not a revenue P&L, see schema file
                comment for why). Feeds the later driver-settlement feature.
  Author:       TransitCore rebuild
  Date:         2026-09-16
  Dependencies: 01-schema/012_ops_phase3_schema.sql
*/
-- Procs keep the QUOTED_IDENTIFIER setting they were created with; tables with filtered indexes reject writes from procs created with it OFF.
SET QUOTED_IDENTIFIER ON;
GO

-- ========== ops.TripExpenses ==========

IF OBJECT_ID('ops.usp_GetTripExpenses', 'P') IS NOT NULL
    DROP PROCEDURE ops.usp_GetTripExpenses;
GO

CREATE PROCEDURE ops.usp_GetTripExpenses
    @TripId INT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        SELECT Id, TripId, ExpenseType, Amount, ExpenseDate, Notes
        FROM ops.TripExpenses
        WHERE TripId = @TripId AND IsDeleted = 0
        ORDER BY ExpenseDate DESC;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END
GO

IF OBJECT_ID('ops.usp_InsertTripExpense', 'P') IS NOT NULL
    DROP PROCEDURE ops.usp_InsertTripExpense;
GO

CREATE PROCEDURE ops.usp_InsertTripExpense
    @TripId       INT,
    @ExpenseType  NVARCHAR(50),
    @Amount       DECIMAL(18,2),
    @ExpenseDate  DATE,
    @Notes        NVARCHAR(500) = NULL,
    @CreatedBy    NVARCHAR(256)
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        INSERT INTO ops.TripExpenses (TripId, ExpenseType, Amount, ExpenseDate, Notes, CreatedBy)
        VALUES (@TripId, @ExpenseType, @Amount, @ExpenseDate, @Notes, @CreatedBy);

        SELECT CAST(SCOPE_IDENTITY() AS INT) AS NewId;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END
GO

IF OBJECT_ID('ops.usp_DeleteTripExpense', 'P') IS NOT NULL
    DROP PROCEDURE ops.usp_DeleteTripExpense;
GO

CREATE PROCEDURE ops.usp_DeleteTripExpense
    @ExpenseId   INT,
    @ModifiedBy  NVARCHAR(256),
    @Success     BIT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        UPDATE ops.TripExpenses
        SET IsDeleted = 1, ModifiedBy = @ModifiedBy, ModifiedAt = SYSUTCDATETIME()
        WHERE Id = @ExpenseId AND IsDeleted = 0;

        SET @Success = CASE WHEN @@ROWCOUNT > 0 THEN 1 ELSE 0 END;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END
GO

-- ========== ops.TripAdvances ==========

IF OBJECT_ID('ops.usp_GetTripAdvances', 'P') IS NOT NULL
    DROP PROCEDURE ops.usp_GetTripAdvances;
GO

CREATE PROCEDURE ops.usp_GetTripAdvances
    @TripId INT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        SELECT Id, TripId, Amount, AdvanceDate, Notes
        FROM ops.TripAdvances
        WHERE TripId = @TripId AND IsDeleted = 0
        ORDER BY AdvanceDate DESC;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END
GO

IF OBJECT_ID('ops.usp_InsertTripAdvance', 'P') IS NOT NULL
    DROP PROCEDURE ops.usp_InsertTripAdvance;
GO

CREATE PROCEDURE ops.usp_InsertTripAdvance
    @TripId       INT,
    @Amount       DECIMAL(18,2),
    @AdvanceDate  DATE,
    @Notes        NVARCHAR(500) = NULL,
    @CreatedBy    NVARCHAR(256)
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        INSERT INTO ops.TripAdvances (TripId, Amount, AdvanceDate, Notes, CreatedBy)
        VALUES (@TripId, @Amount, @AdvanceDate, @Notes, @CreatedBy);

        SELECT CAST(SCOPE_IDENTITY() AS INT) AS NewId;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END
GO

IF OBJECT_ID('ops.usp_DeleteTripAdvance', 'P') IS NOT NULL
    DROP PROCEDURE ops.usp_DeleteTripAdvance;
GO

CREATE PROCEDURE ops.usp_DeleteTripAdvance
    @AdvanceId   INT,
    @ModifiedBy  NVARCHAR(256),
    @Success     BIT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        UPDATE ops.TripAdvances
        SET IsDeleted = 1, ModifiedBy = @ModifiedBy, ModifiedAt = SYSUTCDATETIME()
        WHERE Id = @AdvanceId AND IsDeleted = 0;

        SET @Success = CASE WHEN @@ROWCOUNT > 0 THEN 1 ELSE 0 END;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END
GO

-- ========== Cost summary ==========

IF OBJECT_ID('ops.usp_GetTripCostSummary', 'P') IS NOT NULL
    DROP PROCEDURE ops.usp_GetTripCostSummary;
GO

CREATE PROCEDURE ops.usp_GetTripCostSummary
    @TripId INT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        SELECT
            @TripId AS TripId,
            ISNULL((SELECT SUM(Amount) FROM ops.TripExpenses WHERE TripId = @TripId AND IsDeleted = 0), 0) AS TotalExpenses,
            ISNULL((SELECT SUM(Amount) FROM ops.TripAdvances WHERE TripId = @TripId AND IsDeleted = 0), 0) AS TotalAdvances;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END
GO
