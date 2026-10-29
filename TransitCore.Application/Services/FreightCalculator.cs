namespace TransitCore.Application.Services;

// Pure, dependency-free - the actual "how much does this shipment cost"
// business rules, kept out of both the controller and the stored procs so
// they're directly unit-testable. The rate card's Basis/rate columns and a
// shipment's own totals are the only inputs; nothing here touches the
// database.
public static class FreightCalculator
{
    public static decimal CalculateFreight(
        string basis,
        decimal? ratePerTrip,
        decimal? ratePerTon,
        decimal? ratePerKm,
        decimal? ratePerPackage,
        decimal? minimumChargeableWeightKg,
        decimal totalWeightKg,
        decimal? routeDistanceKm,
        int totalPackages)
    {
        return basis switch
        {
            "PerTrip" => ratePerTrip ?? 0,
            // Minimum chargeable weight: a shipment lighter than the rate
            // card's floor is still billed as if it weighed the floor -
            // standard freight practice, protects against a token-weight
            // booking undercutting a real shipment's rate.
            "PerTon" => (Math.Max(totalWeightKg, minimumChargeableWeightKg ?? 0) / 1000m) * (ratePerTon ?? 0),
            "PerKm" => (routeDistanceKm ?? 0) * (ratePerKm ?? 0),
            "PerPackage" => totalPackages * (ratePerPackage ?? 0),
            _ => 0
        };
    }

    // Free hours come from the rate card; only the time beyond that is
    // billable. A departure at or before arrival (bad data, or a visit
    // that's only half-recorded) bills nothing rather than going negative.
    public static decimal CalculateDetention(decimal freeHours, decimal ratePerHour, DateTime arrivedAt, DateTime departedAt)
    {
        if (departedAt <= arrivedAt)
            return 0;

        var totalHours = (decimal)(departedAt - arrivedAt).TotalHours;
        var billableHours = Math.Max(0, totalHours - freeHours);
        return billableHours * ratePerHour;
    }
}
