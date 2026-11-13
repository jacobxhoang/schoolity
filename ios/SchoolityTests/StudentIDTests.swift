import XCTest
import Vision
@testable import Schoolity

final class StudentIDTests: XCTestCase {
    func testBarcodeDecodesExactStudentNumberIncludingLeadingZeros() throws {
        let number = "00012345"
        let image = try XCTUnwrap(StudentIDBarcode.image(for: number, width: 900, height: 240))
        let request = VNDetectBarcodesRequest()
        // The hosted simulator cannot run the newest Vision inference model.
        // The original CPU decoder still independently verifies Code 128 data.
        request.revision = VNDetectBarcodesRequestRevision1
        request.usesCPUOnly = true
        request.symbologies = [.code128]
        try VNImageRequestHandler(cgImage: image).perform([request])
        XCTAssertEqual(request.results?.first?.payloadStringValue, number)
        XCTAssertLessThanOrEqual(image.width, 900)
    }

    func testUnsupportedValuesAndInsufficientSpaceDoNotMakeMisleadingBarcodes() {
        XCTAssertNil(StudentIDBarcode.image(for: "", width: 900, height: 240))
        XCTAssertNil(StudentIDBarcode.image(for: "12\n34", width: 900, height: 240))
        XCTAssertNil(StudentIDBarcode.image(for: "１２３４", width: 900, height: 240))
        XCTAssertNil(StudentIDBarcode.image(for: "00012345", width: 5, height: 240))
    }

    func testProfileWithoutDistrictIDRemainsDecodable() throws {
        let profile = try JSONDecoder().decode(StudentProfile.self, from: Data(#"{"name":"Sample Student","school":"Sample School","grade":"11"}"#.utf8))
        XCTAssertNil(profile.studentId)
    }
}
