namespace TransitCore.Application.Models;

public class RouteDto
{
    public int Id { get; set; }
    public string Name { get; set; } = string.Empty;
    public int OriginCityId { get; set; }
    public string OriginCityName { get; set; } = string.Empty;
    public int DestinationCityId { get; set; }
    public string DestinationCityName { get; set; } = string.Empty;
    public decimal? DistanceKm { get; set; }
}

public class CreateRouteRequest
{
    public string Name { get; set; } = string.Empty;
    public int OriginCityId { get; set; }
    public int DestinationCityId { get; set; }
    public decimal? DistanceKm { get; set; }
}

public class TripFilterRequest
{
    public DateTime? FromDate { get; set; }
    public DateTime? ToDate { get; set; }
    public int? StatusId { get; set; }
    public int? VehicleId { get; set; }
    public int? DriverId { get; set; }
    public int? RouteId { get; set; }
}

public class TripDto
{
    public int Id { get; set; }
    public int RouteId { get; set; }
    public string RouteName { get; set; } = string.Empty;
    public int VehicleId { get; set; }
    public string RegistrationNo { get; set; } = string.Empty;
    public int DriverId { get; set; }
    public string DriverName { get; set; } = string.Empty;
    public DateTime ScheduledDeparture { get; set; }
    public DateTime ScheduledArrival { get; set; }
    public DateTime? ActualDeparture { get; set; }
    public DateTime? ActualArrival { get; set; }
    public int StatusId { get; set; }
    public string StatusName { get; set; } = string.Empty;
}

public class TripStatusHistoryDto
{
    public int Id { get; set; }
    public int StatusId { get; set; }
    public string StatusName { get; set; } = string.Empty;
    public DateTime ChangedAt { get; set; }
    public string? Notes { get; set; }
}

public class TripDetailDto : TripDto
{
    public IReadOnlyList<TripStatusHistoryDto> StatusHistory { get; set; } = Array.Empty<TripStatusHistoryDto>();
}

public class CreateTripRequest
{
    public int RouteId { get; set; }
    public int VehicleId { get; set; }
    public int DriverId { get; set; }
    public DateTime ScheduledDeparture { get; set; }
    public DateTime ScheduledArrival { get; set; }
    public int StatusId { get; set; }
}

public class UpdateTripStatusRequest
{
    public int TripId { get; set; }
    public int StatusId { get; set; }
    public string? Notes { get; set; }
}

public class ShipmentFilterRequest
{
    public int? CustomerId { get; set; }
    public int? StatusId { get; set; }
}

public class ShipmentDto
{
    public int Id { get; set; }
    public int? TripId { get; set; }
    public int CustomerId { get; set; }
    public string CustomerName { get; set; } = string.Empty;
    public int OriginCityId { get; set; }
    public string OriginCityName { get; set; } = string.Empty;
    public int DestinationCityId { get; set; }
    public string DestinationCityName { get; set; } = string.Empty;
    public int StatusId { get; set; }
    public string StatusName { get; set; } = string.Empty;
    public DateOnly ShipmentDate { get; set; }
}

public class ShipmentItemDto
{
    public int Id { get; set; }
    public string Description { get; set; } = string.Empty;
    public decimal Quantity { get; set; }
    public int UnitOfMeasureId { get; set; }
    public string UnitOfMeasureCode { get; set; } = string.Empty;
    public decimal? WeightKg { get; set; }
}

public class ShipmentDetailDto : ShipmentDto
{
    public IReadOnlyList<ShipmentItemDto> Items { get; set; } = Array.Empty<ShipmentItemDto>();
}

public class CreateShipmentItemRequest
{
    public string Description { get; set; } = string.Empty;
    public decimal Quantity { get; set; }
    public int UnitOfMeasureId { get; set; }
    public decimal? WeightKg { get; set; }
}

public class CreateShipmentRequest
{
    public int CustomerId { get; set; }
    public int OriginCityId { get; set; }
    public int DestinationCityId { get; set; }
    public int StatusId { get; set; }
    public DateOnly ShipmentDate { get; set; }
    public int? TripId { get; set; }
    public List<CreateShipmentItemRequest> Items { get; set; } = new();
}
