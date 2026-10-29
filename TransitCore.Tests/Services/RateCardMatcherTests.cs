using TransitCore.Application.Models;
using TransitCore.Application.Services;

namespace TransitCore.Tests.Services;

public class RateCardMatcherTests
{
    private static RateCardDto Card(int id, int? customerId, int? originCityId, int? destinationCityId, DateOnly effectiveFrom) => new()
    {
        Id = id,
        CustomerId = customerId,
        OriginCityId = originCityId,
        DestinationCityId = destinationCityId,
        EffectiveFrom = effectiveFrom
    };

    [Fact]
    public void SpecificityScore_FullyGenericCard_ScoresZero()
    {
        var card = Card(1, null, null, null, new DateOnly(2026, 1, 1));

        Assert.Equal(0, RateCardMatcher.SpecificityScore(card));
    }

    [Fact]
    public void SpecificityScore_CustomerPlusFullRoute_ScoresHighestOfExamples()
    {
        var customerOnly = Card(1, 10, null, null, new DateOnly(2026, 1, 1));
        var routeOnly = Card(2, null, 20, 30, new DateOnly(2026, 1, 1));
        var customerAndRoute = Card(3, 10, 20, 30, new DateOnly(2026, 1, 1));

        Assert.True(RateCardMatcher.SpecificityScore(customerAndRoute) > RateCardMatcher.SpecificityScore(customerOnly));
        Assert.True(RateCardMatcher.SpecificityScore(customerAndRoute) > RateCardMatcher.SpecificityScore(routeOnly));
        // Customer-pinned beats route-pinned when only one of the two is set.
        Assert.True(RateCardMatcher.SpecificityScore(customerOnly) > RateCardMatcher.SpecificityScore(routeOnly));
    }

    [Fact]
    public void SelectBestMatch_PrefersMostSpecificCard()
    {
        var generic = Card(1, null, null, null, new DateOnly(2026, 1, 1));
        var customerSpecific = Card(2, 10, null, null, new DateOnly(2026, 1, 1));
        var fullySpecific = Card(3, 10, 20, 30, new DateOnly(2026, 1, 1));

        var best = RateCardMatcher.SelectBestMatch(new[] { generic, customerSpecific, fullySpecific });

        Assert.Equal(3, best!.Id);
    }

    [Fact]
    public void SelectBestMatch_TiedSpecificity_PrefersMostRecentlyEffective()
    {
        var older = Card(1, 10, null, null, new DateOnly(2025, 1, 1));
        var newer = Card(2, 10, null, null, new DateOnly(2026, 1, 1));

        var best = RateCardMatcher.SelectBestMatch(new[] { older, newer });

        Assert.Equal(2, best!.Id);
    }

    [Fact]
    public void SelectBestMatch_NoCandidates_ReturnsNull()
    {
        var best = RateCardMatcher.SelectBestMatch(Array.Empty<RateCardDto>());

        Assert.Null(best);
    }
}
