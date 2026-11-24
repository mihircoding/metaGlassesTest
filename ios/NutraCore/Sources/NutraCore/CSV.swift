import Foundation

/// RFC 4180 CSV: fields with a comma, quote or line break are quoted, and quotes inside are doubled.
public enum CSV {
    public static func field(_ value: String) -> String {
        guard value.contains(where: { $0 == "," || $0 == "\"" || $0 == "\n" || $0 == "\r" }) else { return value }
        return "\"" + value.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }

    /// User-typed text for a cell: a leading =, +, -, @, tab or CR would make a spreadsheet run it as a
    /// formula (CSV injection), so such values get a leading apostrophe. Not for numeric columns.
    public static func text(_ value: String) -> String {
        guard let first = value.first, "=+-@\t\r".contains(first) else { return value }
        return "'" + value
    }

    /// A header row and the data rows, joined with CRLF as spreadsheets expect.
    public static func document(header: [String], rows: [[String]]) -> String {
        ([header] + rows).map { $0.map(field).joined(separator: ",") }.joined(separator: "\r\n") + "\r\n"
    }
}
