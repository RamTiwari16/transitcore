using TransitCore.Application.Services;

namespace TransitCore.Tests.Services;

public class FreightCalculatorTests
{
    [Fact]
    public void CalculateFreight_PerTrip_ReturnsFlatRateRegardlessOfOtherInputs()
    {
        var result = FreightCalculator.CalculateFreight("PerTrip", ratePerTrip: 5000, ratePerTon: 999, ratePerKm: 999, ratePerPackage: 999,
            minimumChargeableWeightKg: null, totalWeightKg: 12345, routeDistanceKm: 6789, totalPackages: 42);

        Assert.Equal(5000, result);
    }

    [Fact]
    public void CalculateFreight_PerTrip_NullRate_ReturnsZero()
    {
        var result = FreightCalculator.CalculateFreight("PerTrip", ratePerTrip: null, ratePerTon: null, ratePerKm: null, ratePerPackage: null,
            minimumChargeableWeightKg: null, totalWeightKg: 100, routeDistanceKm: 100, totalPackages: 1);

        Assert.Equal(0, result);
    }

    [Theory]
    [InlineData(2000, 500, 1000)]  // 2000kg = 2 ton * 500/ton = 1000, no minimum
    [InlineData(500, 500, 250)]    // 500kg = 0.5 ton * 500/ton = 250, no minimum
    public void CalculateFreight_PerTon_NoMinimum_UsesActualWeight(decimal weightKg, decimal ratePerTon, decimal expected)
    {
        var result = FreightCalculator.CalculateFreight("PerTon", ratePerTrip: null, ratePerTon: ratePerTon, ratePerKm: null, ratePerPackage: null,
            minimumChargeableWeightKg: null, totalWeightKg: weightKg, routeDistanceKm: null, totalPackages: 0);

        Assert.Equal(expected, result);
    }

    [Fact]
    public void CalculateFreight_PerTon_BelowMinimum_BillsAtMinimumWeight()
    {
        // 500kg actual, but a 1000kg minimum -> billed as if it were 1 ton.
        var result = FreightCalculator.CalculateFreight("PerTon", ratePerTrip: null, ratePerTon: 500, ratePerKm: null, ratePerPackage: null,
            minimumChargeableWeightKg: 1000, totalWeightKg: 500, routeDistanceKm: null, totalPackages: 0);

        Assert.Equal(500, result);
    }

    [Fact]
    public void CalculateFreight_PerTon_AboveMinimum_BillsAtActualWeight()
    {
        // 1500kg actual, above the 1000kg minimum -> billed on actual weight.
        var result = FreightCalculator.CalculateFreight("PerTon", ratePerTrip: null, ratePerTon: 500, ratePerKm: null, ratePerPackage: null,
            minimumChargeableWeightKg: 1000, totalWeightKg: 1500, routeDistanceKm: null, totalPackages: 0);

        Assert.Equal(750, result);
    }

    [Theory]
    [InlineData(100, 25, 2500)]
    [InlineData(0, 25, 0)]
    public void CalculateFreight_PerKm_MultipliesDistanceByRate(decimal distanceKm, decimal ratePerKm, decimal expected)
    {
        var result = FreightCalculator.CalculateFreight("PerKm", ratePerTrip: null, ratePerTon: null, ratePerKm: ratePerKm, ratePerPackage: null,
            minimumChargeableWeightKg: null, totalWeightKg: 0, routeDistanceKm: distanceKm, totalPackages: 0);

        Assert.Equal(expected, result);
    }

    [Fact]
    public void CalculateFreight_PerKm_NullDistance_ReturnsZero()
    {
        var result = FreightCalculator.CalculateFreight("PerKm", ratePerTrip: null, ratePerTon: null, ratePerKm: 25, ratePerPackage: null,
            minimumChargeableWeightKg: null, totalWeightKg: 0, routeDistanceKm: null, totalPackages: 0);

        Assert.Equal(0, result);
    }

    [Theory]
    [InlineData(10, 50, 500)]
    [InlineData(0, 50, 0)]
    public void CalculateFreight_PerPackage_MultipliesCountByRate(int packages, decimal ratePerPackage, decimal expected)
    {
        var result = FreightCalculator.CalculateFreight("PerPackage", ratePerTrip: null, ratePerTon: null, ratePerKm: null, ratePerPackage: ratePerPackage,
            minimumChargeableWeightKg: null, totalWeightKg: 0, routeDistanceKm: null, totalPackages: packages);

        Assert.Equal(expected, result);
    }

    [Fact]
    public void CalculateFreight_UnknownBasis_ReturnsZero()
    {
        var result = FreightCalculator.CalculateFreight("SomethingElse", 100, 100, 100, 100, null, 100, 100, 10);

        Assert.Equal(0, result);
    }

    [Theory]
    [InlineData(4, 100, "2026-01-01T08:00:00", "2026-01-01T10:00:00", 0)]     // 2h dwell, 4h free -> nothing billable
    [InlineData(4, 100, "2026-01-01T08:00:00", "2026-01-01T12:00:00", 0)]     // exactly 4h -> not over
    [InlineData(4, 100, "2026-01-01T08:00:00", "2026-01-01T13:00:00", 100)]   // 5h dwell, 1h billable * 100
    [InlineData(0, 50, "2026-01-01T08:00:00", "2026-01-01T09:00:00", 50)]     // no free hours, full 1h billed
    public void CalculateDetention_ChargesOnlyHoursBeyondFreeAllowance(decimal freeHours, decimal ratePerHour, string arrived, string departed, decimal expected)
    {
        var result = FreightCalculator.CalculateDetention(freeHours, ratePerHour, DateTime.Parse(arrived), DateTime.Parse(departed));

        Assert.Equal(expected, result);
    }

    [Fact]
    public void CalculateDetention_DepartedBeforeArrived_ReturnsZeroRatherThanNegative()
    {
        var result = FreightCalculator.CalculateDetention(0, 100, DateTime.Parse("2026-01-01T12:00:00"), DateTime.Parse("2026-01-01T08:00:00"));

        Assert.Equal(0, result);
    }

    [Fact]
    public void CalculateDetention_DepartedEqualsArrived_ReturnsZero()
    {
        var same = DateTime.Parse("2026-01-01T08:00:00");
        var result = FreightCalculator.CalculateDetention(0, 100, same, same);

        Assert.Equal(0, result);
    }
}
