/** Default "search across every field" predicate shared by both list-state
 * composables below - good enough for flat DTOs with primitive fields, which
 * is everything the list screens render today. Pass a custom predicate to
 * either composable if a screen needs smarter matching. */
export function defaultMatchesFilter<T>(row: T, filterText: string): boolean {
  return Object.values(row as Record<string, unknown>).some((value) =>
    String(value ?? '').toLowerCase().includes(filterText),
  );
}
