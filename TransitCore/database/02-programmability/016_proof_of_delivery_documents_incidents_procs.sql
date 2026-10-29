/*
  Purpose:      Phase 3 (Ops depth) - proof of delivery (+ photos), trip
                document uploads, and trip incident/delay reports.
  Author:       TransitCore rebuild
  Date:         2026-09-16
  Dependencies: 01-schema/012_ops_phase3_schema.sql
*/
-- Procs keep the QUOTED_IDENTIFIER setting they were created with; tables with filtered indexes reject writes from procs created with it OFF.
SET QUOTED_IDENTIFIER ON;
GO

-- ========== ops.ProofOfDelivery ==========

IF OBJECT_ID('ops.usp_GetProofOfDelivery', 'P') IS NOT NULL
    DROP PROCEDURE ops.usp_GetProofOfDelivery;
GO

CREATE PROCEDURE ops.usp_GetProofOfDelivery
    @TripId INT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        SELECT Id, TripId, ReceiverName, ReceiverPhone, DeliveredAt, Notes, SignatureFilePath
        FROM ops.ProofOfDelivery
        WHERE TripId = @TripId;

        SELECT p.Id, p.ProofOfDeliveryId, p.FilePath, p.UploadedAt
        FROM ops.ProofOfDeliveryPhotos p
        INNER JOIN ops.ProofOfDelivery pod ON pod.Id = p.ProofOfDeliveryId
        WHERE pod.TripId = @TripId
        ORDER BY p.UploadedAt ASC;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END
GO

IF OBJECT_ID('ops.usp_InsertProofOfDelivery', 'P') IS NOT NULL
    DROP PROCEDURE ops.usp_InsertProofOfDelivery;
GO

CREATE PROCEDURE ops.usp_InsertProofOfDelivery
    @TripId              INT,
    @ReceiverName        NVARCHAR(200),
    @ReceiverPhone       NVARCHAR(30) = NULL,
    @DeliveredAt         DATETIME2(3),
    @Notes               NVARCHAR(500) = NULL,
    @SignatureFilePath   NVARCHAR(400) = NULL,
    @CreatedBy           NVARCHAR(256)
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        INSERT INTO ops.ProofOfDelivery (TripId, ReceiverName, ReceiverPhone, DeliveredAt, Notes, SignatureFilePath, CreatedBy)
        VALUES (@TripId, @ReceiverName, @ReceiverPhone, @DeliveredAt, @Notes, @SignatureFilePath, @CreatedBy);

        SELECT CAST(SCOPE_IDENTITY() AS INT) AS NewId;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END
GO

IF OBJECT_ID('ops.usp_InsertProofOfDeliveryPhoto', 'P') IS NOT NULL
    DROP PROCEDURE ops.usp_InsertProofOfDeliveryPhoto;
GO

CREATE PROCEDURE ops.usp_InsertProofOfDeliveryPhoto
    @ProofOfDeliveryId  INT,
    @FilePath           NVARCHAR(400)
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        INSERT INTO ops.ProofOfDeliveryPhotos (ProofOfDeliveryId, FilePath)
        VALUES (@ProofOfDeliveryId, @FilePath);

        SELECT CAST(SCOPE_IDENTITY() AS INT) AS NewId;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END
GO

-- ========== ops.TripDocuments ==========

IF OBJECT_ID('ops.usp_GetTripDocuments', 'P') IS NOT NULL
    DROP PROCEDURE ops.usp_GetTripDocuments;
GO

CREATE PROCEDURE ops.usp_GetTripDocuments
    @TripId INT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        SELECT Id, TripId, DocumentType, FileName, FilePath, UploadedAt
        FROM ops.TripDocuments
        WHERE TripId = @TripId AND IsDeleted = 0
        ORDER BY UploadedAt DESC;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END
GO

IF OBJECT_ID('ops.usp_InsertTripDocument', 'P') IS NOT NULL
    DROP PROCEDURE ops.usp_InsertTripDocument;
GO

CREATE PROCEDURE ops.usp_InsertTripDocument
    @TripId        INT,
    @DocumentType  NVARCHAR(100),
    @FileName      NVARCHAR(260),
    @FilePath      NVARCHAR(400),
    @UploadedBy    NVARCHAR(256)
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        INSERT INTO ops.TripDocuments (TripId, DocumentType, FileName, FilePath, UploadedBy)
        VALUES (@TripId, @DocumentType, @FileName, @FilePath, @UploadedBy);

        SELECT CAST(SCOPE_IDENTITY() AS INT) AS NewId;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END
GO

IF OBJECT_ID('ops.usp_DeleteTripDocument', 'P') IS NOT NULL
    DROP PROCEDURE ops.usp_DeleteTripDocument;
GO

CREATE PROCEDURE ops.usp_DeleteTripDocument
    @DocumentId  INT,
    @Success     BIT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        UPDATE ops.TripDocuments
        SET IsDeleted = 1
        WHERE Id = @DocumentId AND IsDeleted = 0;

        SET @Success = CASE WHEN @@ROWCOUNT > 0 THEN 1 ELSE 0 END;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END
GO

-- ========== ops.TripIncidents ==========

IF OBJECT_ID('ops.usp_GetTripIncidents', 'P') IS NOT NULL
    DROP PROCEDURE ops.usp_GetTripIncidents;
GO

CREATE PROCEDURE ops.usp_GetTripIncidents
    @TripId INT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        SELECT Id, TripId, IncidentType, Description, ReportedAt, ReportedBy
        FROM ops.TripIncidents
        WHERE TripId = @TripId AND IsDeleted = 0
        ORDER BY ReportedAt DESC;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END
GO

IF OBJECT_ID('ops.usp_InsertTripIncident', 'P') IS NOT NULL
    DROP PROCEDURE ops.usp_InsertTripIncident;
GO

CREATE PROCEDURE ops.usp_InsertTripIncident
    @TripId        INT,
    @IncidentType  NVARCHAR(50),
    @Description   NVARCHAR(1000),
    @ReportedBy    NVARCHAR(256)
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        INSERT INTO ops.TripIncidents (TripId, IncidentType, Description, ReportedBy)
        VALUES (@TripId, @IncidentType, @Description, @ReportedBy);

        SELECT CAST(SCOPE_IDENTITY() AS INT) AS NewId;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END
GO

IF OBJECT_ID('ops.usp_DeleteTripIncident', 'P') IS NOT NULL
    DROP PROCEDURE ops.usp_DeleteTripIncident;
GO

CREATE PROCEDURE ops.usp_DeleteTripIncident
    @IncidentId  INT,
    @Success     BIT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        UPDATE ops.TripIncidents
        SET IsDeleted = 1
        WHERE Id = @IncidentId AND IsDeleted = 0;

        SET @Success = CASE WHEN @@ROWCOUNT > 0 THEN 1 ELSE 0 END;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END
GO
