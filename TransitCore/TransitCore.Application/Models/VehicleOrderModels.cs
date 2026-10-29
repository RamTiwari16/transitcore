namespace TransitCore.Application.Models;

public class VehicleOrderMappingRow
{
    public string VehicleNo { get; set; } = string.Empty;
    public string OrderNo { get; set; } = string.Empty;
    public DateOnly UploadDate { get; set; }
    public string CreatedByEmail { get; set; } = string.Empty;
}

public class VehicleOrderMappingDto
{
    public int Id { get; set; }
    public string VehicleNo { get; set; } = string.Empty;
    public string OrderNo { get; set; } = string.Empty;
    public DateOnly UploadDate { get; set; }
    public string CreatedByEmail { get; set; } = string.Empty;
    public DateTime CreatedAt { get; set; }
}

public class DateRangeRequest
{
    public DateOnly FromDate { get; set; }
    public DateOnly ToDate { get; set; }
}

public class BulkUploadResult
{
    public int TotalRecords { get; set; }
    public string UploadedBy { get; set; } = string.Empty;
    public DateOnly UploadDate { get; set; }
}
