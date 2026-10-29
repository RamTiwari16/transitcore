using TransitCore.Application.Models;

namespace TransitCore.Application.Services;

// "Most specific rate card wins" - the rule the original usp_GetUninvoicedShipments
// comment described but never implemented. Candidates (already filtered to
// compatible + currently-effective cards by billing.usp_GetApplicableRateCards)
// are ranked by how many of Customer/Origin/Destination are pinned rather
// than left generic (NULL); ties broken by the most recently effective card.
public static class RateCardMatcher
{
    public static int SpecificityScore(RateCardDto card) =>
        (card.CustomerId.HasValue ? 4 : 0) +
        (card.OriginCityId.HasValue ? 2 : 0) +
        (card.DestinationCityId.HasValue ? 1 : 0);

    public static RateCardDto? SelectBestMatch(IEnumerable<RateCardDto> candidates) =>
        candidates
            .OrderByDescending(SpecificityScore)
            .ThenByDescending(c => c.EffectiveFrom)
            .FirstOrDefault();
}
