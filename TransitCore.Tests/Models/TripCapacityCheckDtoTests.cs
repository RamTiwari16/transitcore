using TransitCore.Application.Models;

namespace TransitCore.Tests.Models;

public class TripCapacityCheckDtoTests
{
    [Theory]
    [InlineData(1000, 999, false)]  // under capacity
    [InlineData(1000, 1000, false)] // exactly at capacity - not over
    [InlineData(1000, 1001, true)]  // one unit over
    [InlineData(0, 1, true)]        // zero capacity, any load is over
    [InlineData(0, 0, false)]       // zero capacity, nothing assigned - not over
    public void IsOverCapacity_ComparesAssignedWeightAgainstVehicleCapacity(decimal capacityKg, decimal assignedKg, bool expectedOverCapacity)
    {
        var dto = new TripCapacityCheckDto { VehicleCapacityKg = capacityKg, AssignedWeightKg = assignedKg };

        Assert.Equal(expectedOverCapacity, dto.IsOverCapacity);
    }

    [Theory]
    [InlineData(50, 49, false)]
    [InlineData(50, 50, false)]
    [InlineData(50, 50.01, true)]
    [InlineData(0, 0.01, true)]
    [InlineData(0, 0, false)]
    public void IsOverVolumeCapacity_ComparesAssignedVolumeAgainstVehicleCapacity(decimal capacityCbm, decimal assignedCbm, bool expectedOverCapacity)
    {
        var dto = new TripCapacityCheckDto { VehicleCapacityCbm = capacityCbm, AssignedVolumeCbm = assignedCbm };

        Assert.Equal(expectedOverCapacity, dto.IsOverVolumeCapacity);
    }
}
