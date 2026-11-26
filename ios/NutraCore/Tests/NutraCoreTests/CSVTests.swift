import XCTest
@testable import NutraCore

final class CSVTests: XCTestCase {
  func testPlainFieldsAreLeftAlone() {
    XCTAssertEqual(CSV.field("Banana"), "Banana")
    XCTAssertEqual(CSV.field("105.5"), "105.5")
  }

  func testCommasQuotesAndNewlinesAreQuoted() {
    XCTAssertEqual(CSV.field("Bananas, raw"), "\"Bananas, raw\"")
    XCTAssertEqual(CSV.field("12\" sub"), "\"12\"\" sub\"")
    XCTAssertEqual(CSV.field("two\nlines"), "\"two\nlines\"")
  }

  func testTextNeutralisesFormulas() {
    XCTAssertEqual(CSV.text("=HYPERLINK(\"http://x\")"), "'=HYPERLINK(\"http://x\")")
    XCTAssertEqual(CSV.text("+cmd"), "'+cmd")
    XCTAssertEqual(CSV.text("-1 tbsp"), "'-1 tbsp")
    XCTAssertEqual(CSV.text("@sum"), "'@sum")
    XCTAssertEqual(CSV.text("Oatmeal"), "Oatmeal")
    XCTAssertEqual(CSV.text(""), "")
  }

  func testDocument() {
    let doc = CSV.document(header: ["date", "food"], rows: [["2026-11-24", "Oats, rolled"], ["2026-11-24", "Tea"]])
    XCTAssertEqual(doc, "date,food\r\n2026-11-24,\"Oats, rolled\"\r\n2026-11-24,Tea\r\n")
  }
}
