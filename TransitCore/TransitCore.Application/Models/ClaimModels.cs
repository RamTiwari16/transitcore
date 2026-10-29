namespace TransitCore.Application.Models;

public class ClaimFilterRequest
{
    public int? ShipmentId { get; set; }
    public int? StatusId { get; set; }
    public DateOnly? FromDate { get; set; }
    public DateOnly? ToDate { get; set; }
}

public class ClaimDto
{
    public int Id { get; set; }
    public int ShipmentId { get; set; }
    public string TrackingNo { get; set; } = string.Empty;
    public string ClaimantName { get; set; } = string.Empty;
    public string? ClaimantPhone { get; set; }
    public decimal AmountClaimed { get; set; }
    public int StatusId { get; set; }
    public string StatusName { get; set; } = string.Empty;
    public decimal? SettledAmount { get; set; }
    public string? SettlementMethod { get; set; }
    public string? Notes { get; set; }
    public DateTime CreatedAt { get; set; }
}

public class ClaimStatusHistoryDto
{
    public int Id { get; set; }
    public int StatusId { get; set; }
    public string StatusName { get; set; } = string.Empty;
    public DateTime ChangedAt { get; set; }
    public string? Notes { get; set; }
}

public class ClaimDetailDto : ClaimDto
{
    public IReadOnlyList<ClaimStatusHistoryDto> StatusHistory { get; set; } = Array.Empty<ClaimStatusHistoryDto>();
}

public class CreateClaimRequest
{
    public int ShipmentId { get; set; }
    public string ClaimantName { get; set; } = string.Empty;
    public string? ClaimantPhone { get; set; }
    public decimal AmountClaimed { get; set; }
    public int StatusId { get; set; }
    public string? Notes { get; set; }
}

public class UpdateClaimRequest
{
    public int ClaimId { get; set; }
    public string ClaimantName { get; set; } = string.Empty;
    public string? ClaimantPhone { get; set; }
    public decimal AmountClaimed { get; set; }
    public string? Notes { get; set; }
}

public class UpdateClaimStatusRequest
{
    public int ClaimId { get; set; }
    public int StatusId { get; set; }
    public string? Notes { get; set; }
}

// SettlementMethod must be one of InvoiceDeduction / CreditNote / Insurance /
// DriverRecovery / VendorRecovery - see billing.usp_SettleClaim for what
// each one actually does on settlement.
public class SettleClaimRequest
{
    public int ClaimId { get; set; }
    public decimal SettledAmount { get; set; }
    public string SettlementMethod { get; set; } = string.Empty;
    public string? Notes { get; set; }
}
