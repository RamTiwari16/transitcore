namespace TransitCore.Application.Models;

public class RequiredComplianceDocumentTypeDto
{
    public int Id { get; set; }
    public string DocumentType { get; set; } = string.Empty;
    public bool IsActive { get; set; }
}

public class CreateRequiredComplianceDocumentTypeRequest
{
    public string DocumentType { get; set; } = string.Empty;
}

public class UpdateRequiredComplianceDocumentTypeRequest
{
    public int Id { get; set; }
    public string DocumentType { get; set; } = string.Empty;
    public bool IsActive { get; set; }
}

// Status is Missing/Expired/Valid - purely informational, matching
// TripConflictDto: the DB reports facts, the frontend decides whether to
// warn or block dispatch.
public class TripDispatchComplianceCheckDto
{
    public string CheckType { get; set; } = string.Empty;
    public string Label { get; set; } = string.Empty;
    public string Status { get; set; } = string.Empty;
    public DateOnly? ExpiryDate { get; set; }
}

public class ExpiringEwayBillDto
{
    public int ConsignmentNoteId { get; set; }
    public int ShipmentId { get; set; }
    public string CnNumber { get; set; } = string.Empty;
    public string? TrackingNo { get; set; }
    public string EwayBillNo { get; set; } = string.Empty;
    public DateOnly EwayBillValidUntil { get; set; }
    public int DaysUntilExpiry { get; set; }
}

public class UpdateConsignmentNoteEwayBillRequest
{
    public int ShipmentId { get; set; }
    public string EwayBillNo { get; set; } = string.Empty;
    public DateOnly EwayBillGeneratedDate { get; set; }
    public DateOnly EwayBillValidUntil { get; set; }
}
