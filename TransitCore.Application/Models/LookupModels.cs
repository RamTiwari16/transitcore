namespace TransitCore.Application.Models;

public class RegionDto
{
    public int Id { get; set; }
    public string Name { get; set; } = string.Empty;
}

public class BranchDto
{
    public int Id { get; set; }
    public string Name { get; set; } = string.Empty;
    public int RegionId { get; set; }
    public string RegionName { get; set; } = string.Empty;
}

public class CityDto
{
    public int Id { get; set; }
    public string Name { get; set; } = string.Empty;
    public int CountryId { get; set; }
    public string CountryName { get; set; } = string.Empty;
}

public class DesignationDto
{
    public int Id { get; set; }
    public string Code { get; set; } = string.Empty;
    public string Name { get; set; } = string.Empty;
}

public class UnitOfMeasureDto
{
    public int Id { get; set; }
    public string Code { get; set; } = string.Empty;
    public string Name { get; set; } = string.Empty;
}

public class WorkingDesignationDto
{
    public int Id { get; set; }
    public string Name { get; set; } = string.Empty;
}
