namespace TransitCore.Application.Models;

public class ConsignmentNoteDto
{
    public int Id { get; set; }
    public int ShipmentId { get; set; }
    public string CnNumber { get; set; } = string.Empty;
    public int BranchId { get; set; }
    public string BranchName { get; set; } = string.Empty;
    public DateOnly CnDate { get; set; }
    public int? Packages { get; set; }
    public decimal? ActualWeightKg { get; set; }
    public decimal? ChargedWeightKg { get; set; }
    public decimal? DeclaredValue { get; set; }
    public decimal? FreightAmount { get; set; }
    public string? Remarks { get; set; }
    public int StatusId { get; set; }
    public string StatusName { get; set; } = string.Empty;
    public string? CancelReason { get; set; }
    public DateTime? CancelledAt { get; set; }
    public string? CancelledBy { get; set; }

    public string? EwayBillNo { get; set; }
    public DateOnly? EwayBillGeneratedDate { get; set; }
    public DateOnly? EwayBillValidUntil { get; set; }

    public string? TrackingNo { get; set; }
    public int OriginCityId { get; set; }
    public string OriginCityName { get; set; } = string.Empty;
    public int DestinationCityId { get; set; }
    public string DestinationCityName { get; set; } = string.Empty;
    public DateOnly ShipmentDate { get; set; }
    public int FreightPaymentTypeId { get; set; }
    public string FreightPaymentTypeName { get; set; } = string.Empty;

    public int BillingPartyCustomerId { get; set; }
    public string BillingPartyName { get; set; } = string.Empty;
    public int? ConsignorCustomerId { get; set; }
    public string? ConsignorCustomerName { get; set; }
    public string? ConsignorName { get; set; }
    public string? ConsignorAddress { get; set; }
    public string? ConsignorPhone { get; set; }
    public int? ConsigneeCustomerId { get; set; }
    public string? ConsigneeCustomerName { get; set; }
    public string? ConsigneeName { get; set; }
    public string? ConsigneeAddress { get; set; }
    public string? ConsigneePhone { get; set; }

    public int? TripId { get; set; }
    public int? VehicleId { get; set; }
    public string? VehicleRegistrationNo { get; set; }
    public int? DriverId { get; set; }
    public string? DriverName { get; set; }
}

public class ConsignmentNoteDetailDto : ConsignmentNoteDto
{
    public IReadOnlyList<ShipmentItemDto> Items { get; set; } = Array.Empty<ShipmentItemDto>();
}

public class CancelConsignmentNoteRequest
{
    public int ShipmentId { get; set; }
    public string CancelReason { get; set; } = string.Empty;
}
