namespace TransitCore.Application.Models;

public class CountryDto
{
    public int Id { get; set; }
    public string Code { get; set; } = string.Empty;
    public string Name { get; set; } = string.Empty;
}

// ---- Regions ----

public class CreateRegionRequest
{
    public string Name { get; set; } = string.Empty;
}

public class UpdateRegionRequest
{
    public int Id { get; set; }
    public string Name { get; set; } = string.Empty;
}

// ---- Branches ----

public class CreateBranchRequest
{
    public string Name { get; set; } = string.Empty;
    public string Code { get; set; } = string.Empty;
    public int RegionId { get; set; }
}

public class UpdateBranchRequest
{
    public int Id { get; set; }
    public string Name { get; set; } = string.Empty;
    public string Code { get; set; } = string.Empty;
    public int RegionId { get; set; }
}

// ---- Designations ----

public class CreateDesignationRequest
{
    public string Code { get; set; } = string.Empty;
    public string Name { get; set; } = string.Empty;
}

public class UpdateDesignationRequest
{
    public int Id { get; set; }
    public string Code { get; set; } = string.Empty;
    public string Name { get; set; } = string.Empty;
}

// ---- WorkingDesignations ----

public class CreateWorkingDesignationRequest
{
    public string Name { get; set; } = string.Empty;
}

public class UpdateWorkingDesignationRequest
{
    public int Id { get; set; }
    public string Name { get; set; } = string.Empty;
}

// ---- Countries ----

public class CreateCountryRequest
{
    public string Code { get; set; } = string.Empty;
    public string Name { get; set; } = string.Empty;
}

public class UpdateCountryRequest
{
    public int Id { get; set; }
    public string Code { get; set; } = string.Empty;
    public string Name { get; set; } = string.Empty;
}

// ---- Cities ----

public class CreateCityRequest
{
    public string Name { get; set; } = string.Empty;
    public int CountryId { get; set; }
}

public class UpdateCityRequest
{
    public int Id { get; set; }
    public string Name { get; set; } = string.Empty;
    public int CountryId { get; set; }
}

// ---- StatusCodes ----

public class CreateStatusCodeRequest
{
    public string Category { get; set; } = string.Empty;
    public string Code { get; set; } = string.Empty;
    public string Name { get; set; } = string.Empty;
    public int SortOrder { get; set; }
}

public class UpdateStatusCodeRequest
{
    public int Id { get; set; }
    public string Category { get; set; } = string.Empty;
    public string Code { get; set; } = string.Empty;
    public string Name { get; set; } = string.Empty;
    public int SortOrder { get; set; }
}

// ---- UnitsOfMeasure ----

public class CreateUnitOfMeasureRequest
{
    public string Code { get; set; } = string.Empty;
    public string Name { get; set; } = string.Empty;
}

public class UpdateUnitOfMeasureRequest
{
    public int Id { get; set; }
    public string Code { get; set; } = string.Empty;
    public string Name { get; set; } = string.Empty;
}
