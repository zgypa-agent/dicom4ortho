import Foundation
import Testing
import DICOMCore
import DICOMKit
@testable import DICOM4Ortho

@Test func treatmentProgressUsesAcquisitionCalendarDate() throws {
    var metadata = PhotographMetadata(imageType: "EV08")
    metadata.acquisitionDateTime = ISO8601DateFormatter().date(from: "2024-07-31T01:00:00Z")!
    metadata.acquisitionTimeZone = TimeZone(secondsFromGMT: -5 * 3600)!
    metadata.treatmentProgress = TreatmentProgress(
        event: .orthodonticTreatmentStarted,
        eventDate: try ClinicalDate(year: 2024, month: 1, day: 1))
    let photo = try OrthodonticPhotograph(
        rgb8: Data([0, 0, 0]), width: 1, height: 1, metadata: metadata)
    let data = try photo.dicomData()
    let dataset = try DICOMFile.read(from: data).dataSet
    #expect(dataset.string(for: .acquisitionDate) == "20240730")
    #expect(dataset.string(for: .acquisitionDateTime)?.hasSuffix("-0500") == true)
    let context = try #require(dataset.sequence(for: .acquisitionContextSequence))
    let offset = try #require(context.last)
    #expect(offset.string(for: .numericValue) == "211")
    #expect(context[context.count - 2][.conceptCodeSequence]?.sequenceItems?.first?
        .string(for: .codeValue) == "1332161000")
    if let directory = ProcessInfo.processInfo.environment["DICOM4ORTHO_TEST_ARTIFACTS"] {
        let url = URL(fileURLWithPath: directory, isDirectory: true)
            .appendingPathComponent("clinical", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        try data.write(to: url.appendingPathComponent("treatment-progress.dcm"))
    }
}

@Test func zeroDayProgressAndPersonnelRolesArePreserved() throws {
    var metadata = PhotographMetadata(imageType: "EV08")
    metadata.acquisitionTimeZone = TimeZone(secondsFromGMT: 0)!
    metadata.acquisitionDateTime = ISO8601DateFormatter().date(from: "2024-01-01T12:00:00Z")!
    metadata.treatmentProgress = TreatmentProgress(
        event: .patientRegistration, eventDate: try ClinicalDate(year: 2024, month: 1, day: 1))
    metadata.providerFamilyName = "Taylor"
    metadata.providerGivenName = "Morgan"
    metadata.operatorFamilyName = "Jordan"
    metadata.operatorGivenName = "Alex"
    let photo = try OrthodonticPhotograph(
        rgb8: Data([0, 0, 0]), width: 1, height: 1, metadata: metadata)
    let data = try photo.dicomData()
    let dataset = try DICOMFile.read(from: data).dataSet
    #expect(dataset.sequence(for: .acquisitionContextSequence)?.last?
        .string(for: .numericValue) == "0")
    #expect(dataset.string(for: .physiciansOfRecord) == "Taylor^Morgan")
    #expect(dataset.string(for: .operatorsName) == "Jordan^Alex")
    #expect(dataset.string(for: .referringPhysicianName) == "")
}

@Test func rejectsImpossibleDatesMissingAcquisitionAndFutureEvents() throws {
    #expect(throws: MaterializationError.invalidClinicalDate) {
        try ClinicalDate(year: 2024, month: 2, day: 30)
    }
    var metadata = PhotographMetadata(imageType: "EV01")
    metadata.treatmentProgress = TreatmentProgress(
        event: .patientRegistration,
        eventDate: try ClinicalDate(year: 2024, month: 2, day: 1))
    #expect(throws: MaterializationError.acquisitionDateRequired) {
        try OrthodonticPhotograph(
            rgb8: Data([0, 0, 0]), width: 1, height: 1, metadata: metadata)
    }
    metadata.acquisitionDateTime = ISO8601DateFormatter().date(from: "2024-01-01T12:00:00Z")!
    #expect(throws: MaterializationError.treatmentEventAfterAcquisition) {
        try OrthodonticPhotograph(
            rgb8: Data([0, 0, 0]), width: 1, height: 1, metadata: metadata)
    }
}

@Test func normalizesPatientSexLikePython() throws {
    for (value, expected) in [("Male", "M"), ("female", "F"), ("O", "O"),
                              ("other", "O"), ("unknown", ""), ("MF", "")] {
        var metadata = PhotographMetadata(imageType: "EV01")
        metadata.patientSex = value
        let photo = try OrthodonticPhotograph(
            rgb8: Data([0, 0, 0]), width: 1, height: 1, metadata: metadata)
        let data = try photo.dicomData()
        #expect(try DICOMFile.read(from: data).dataSet.string(for: .patientSex) == expected)
    }
}
