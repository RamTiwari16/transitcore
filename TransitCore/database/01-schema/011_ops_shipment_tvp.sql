/*
  Purpose:      Table-valued parameter type for passing shipment items into
                ops.usp_InsertShipment.
  Author:       TransitCore rebuild
  Date:         2026-09-11
  Dependencies: 008_ops_routes_trips_shipments_schema.sql
*/
SET NOCOUNT ON;
GO

IF NOT EXISTS (SELECT 1 FROM sys.types WHERE name = 'ShipmentItemType' AND schema_id = SCHEMA_ID('ops'))
BEGIN
    CREATE TYPE ops.ShipmentItemType AS TABLE
    (
        Description     NVARCHAR(300) NOT NULL,
        Quantity        DECIMAL(18,2) NOT NULL,
        UnitOfMeasureId INT           NOT NULL,
        WeightKg        DECIMAL(18,2) NULL
    );
END
GO
