using TransitCore.Application.Models;

namespace TransitCore.Tests.Models;

public class TripCostSummaryDtoTests
{
    [Fact]
    public void Profit_OwnTrip_NoVendorFreight_SubtractsOnlyExpenses()
    {
        var dto = new TripCostSummaryDto { CustomerChargesTotal = 10000, VendorFreightAmount = null, TotalExpenses = 2000 };

        Assert.Equal(8000, dto.Profit);
    }

    [Fact]
    public void Profit_HiredTrip_SubtractsBothVendorFreightAndExpenses()
    {
        var dto = new TripCostSummaryDto { CustomerChargesTotal = 10000, VendorFreightAmount = 6000, TotalExpenses = 1000 };

        Assert.Equal(3000, dto.Profit);
    }

    [Fact]
    public void Profit_CanBeNegative_WhenCostsExceedCustomerCharges()
    {
        var dto = new TripCostSummaryDto { CustomerChargesTotal = 5000, VendorFreightAmount = 4000, TotalExpenses = 2000 };

        Assert.Equal(-1000, dto.Profit);
    }

    [Fact]
    public void Profit_NoChargesOrCosts_IsZero()
    {
        var dto = new TripCostSummaryDto();

        Assert.Equal(0, dto.Profit);
    }
}
