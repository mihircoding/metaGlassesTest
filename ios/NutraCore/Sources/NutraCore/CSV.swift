import Foundation

/// RFC 4180 CSV: fields with a comma, quote or line break are quoted, and quotes inside are doubled.
public enum CSV {
    public static func field(_ value: String) -> String {
        guard value.contains(where: { $0 == "," || $0 == "\"" || $0 == "\n" || $0 == "\r" }) else { return value }
        return "\"" + value.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }

    /// A header row and the data rows, joined with CRLF as spreadsheets expect.
    public static func document(header: [String], rows: [[String]]) -> String {
        ([header] + rows).map { $0.map(field).joined(separator: ",") }.joined(separator: "\r\n") + "\r\n"
    }
}
