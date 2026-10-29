using TransitCore.Application.Services;

namespace TransitCore.Tests.Services;

public class FinancialYearCalculatorTests
{
    [Theory]
    // The April 1 cutover itself, both sides.
    [InlineData(2026, 4, 1, "2627")]
    [InlineData(2026, 3, 31, "2526")]
    // Ordinary dates on either side of the cutover.
    [InlineData(2026, 6, 15, "2627")]
    [InlineData(2026, 1, 15, "2526")]
    [InlineData(2026, 12, 31, "2627")]
    // Century rollover of the two-digit year components.
    [InlineData(2000, 4, 1, "0001")]
    [InlineData(1999, 4, 1, "9900")]
    // Leap day, before the cutover.
    [InlineData(2028, 2, 29, "2728")]
    public void GetCode_ReturnsExpectedFinancialYear(int year, int month, int day, string expected)
    {
        var result = FinancialYearCalculator.GetCode(new DateOnly(year, month, day));

        Assert.Equal(expected, result);
    }
}
