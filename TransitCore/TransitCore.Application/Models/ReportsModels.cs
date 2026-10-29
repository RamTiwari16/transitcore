namespace TransitCore.Application.Models;

public class RevenueByPeriodDto
{
    public string PeriodLabel { get; set; } = string.Empty;
    public decimal TotalInvoiced { get; set; }
    public decimal TotalCollected { get; set; }
}

public class DriverSettlementSummaryDto
{
    public int DriverId { get; set; }
    public string FullName { get; set; } = string.Empty;
    public decimal TotalAdvances { get; set; }
    public decimal TotalExpenses { get; set; }
    public decimal Balance { get; set; }
}

public class FleetUtilisationTrendDto
{
    public string PeriodLabel { get; set; } = string.Empty;
    public decimal UtilisationPercent { get; set; }
}

public class ShipmentVolumeTrendDto
{
    public string PeriodLabel { get; set; } = string.Empty;
    public int ShipmentCount { get; set; }
}

public class EmptyKmReportDto
{
    public int VehicleId { get; set; }
    public string RegistrationNo { get; set; } = string.Empty;
    public decimal TotalLoadedKm { get; set; }
    public decimal TotalEmptyKm { get; set; }
    public decimal TotalKm { get; set; }
    public decimal EmptyKmPercent { get; set; }
    public int TripCount { get; set; }
}

public class VehicleAvailabilityDto
{
    public int VehicleId { get; set; }
    public string RegistrationNo { get; set; } = string.Empty;
    public string VehicleTypeName { get; set; } = string.Empty;
    public bool IsAvailableNow { get; set; }
    public DateTime? ExpectedFreeAt { get; set; }
    public string? CurrentTripRoute { get; set; }
}
