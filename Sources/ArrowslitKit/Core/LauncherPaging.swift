/// Splits the launcher's features into DynamicLedge pages: five columns, two rows per page.
public enum LauncherPaging {
    public static let columns = 5
    public static let rows = 2

    public static func pages<Item>(
        _ items: [Item],
        columns: Int = LauncherPaging.columns,
        rows: Int = LauncherPaging.rows
    ) -> [[Item]] {
        let perPage = max(1, columns * rows)
        guard !items.isEmpty else { return [] }
        return stride(from: 0, to: items.count, by: perPage).map { start in
            Array(items[start..<min(start + perPage, items.count)])
        }
    }
}
