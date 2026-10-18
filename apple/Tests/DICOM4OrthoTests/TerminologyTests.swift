import Testing
@testable import DICOM4Ortho

@Test func reviewedTerminologyIsAvailableOffline() throws {
    let terminology = try Terminology.bundled()
    #expect(terminology.codes.count == 83)
    #expect(terminology.imageTypes.count == 73)
    #expect(terminology.sourceLockSHA256.count == 64)
    #expect(terminology.codes["PatientRegistration"]?.value == "184047000")
    #expect(terminology.imageTypes["EV01"] != nil)
}
