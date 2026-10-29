namespace TransitCore.Application.Services;

// India's financial year runs 1 April - 31 March. Pure, dependency-free so
// it's directly unit-testable - the one piece of the consignment-note
// numbering scheme genuinely worth testing in isolation (the April cutover
// is easy to get off-by-one on). The reserved sequence number and the final
// {BRANCH}/{FY}/{SEQ}-style string assembly happen in
// ops.usp_InsertShipment itself, not here - see that proc's header comment
// for why (atomicity: SqlDataAccess opens a fresh connection per call, so
// "reserve then insert" can only be made all-or-nothing by keeping both
// steps inside one stored procedure's transaction).
public static class FinancialYearCalculator
{
    // Returns a 4-digit code for the financial year containing `date`, e.g.
    // 2026-06-15 (June, after the April cutover) -> "2627" (FY2026-27);
    // 2026-02-10 (February, before the April cutover) -> "2526" (FY2025-26).
    public static string GetCode(DateOnly date)
    {
        var startYear = date.Month >= 4 ? date.Year : date.Year - 1;
        var endYear = startYear + 1;
        return $"{startYear % 100:D2}{endYear % 100:D2}";
    }
}
