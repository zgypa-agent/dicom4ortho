import Foundation
import Testing
import DICOMCore
import DICOMKit
import DICOM4Ortho

@Test func photographConstructionEditingAndSerializationAreSeparate() throws {
    let metadata = PhotographMetadata(imageType: "EV01")
    let original = try OrthodonticPhotograph(
        rgb8: Data([255, 0, 0]), width: 1, height: 1, metadata: metadata)
    #expect(original.dataSet.string(for: .sopInstanceUID) == metadata.sopInstanceUID)
    var edited = original
    edited.dataSet.setString("updated-id", for: .patientID, vr: .LO)
    let newUID = "1.2.826.0.1.3680043.10.543.123"
    edited.dataSet.setString(newUID, for: .sopInstanceUID, vr: .UI)
    #expect(original.dataSet.string(for: .patientID) == "")
    #expect(original.dataSet.string(for: .sopInstanceUID) == metadata.sopInstanceUID)
    let first = try edited.dicomData()
    let second = try edited.dicomData()
    #expect(first == second)
    let file = try DICOMFile.read(from: first)
    #expect(file.dataSet.string(for: .patientID) == "updated-id")
    #expect(file.sopInstanceUID == newUID)
    #expect(file.fileMetaInformation.string(for: .mediaStorageSOPInstanceUID) == newUID)
}

@Test func photographSaveMatchesInMemorySerialization() throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let url = directory.appendingPathComponent("photograph.dcm")
    let photo = try OrthodonticPhotograph(
        rgb8: Data([255, 0, 0]), width: 1, height: 1, metadata: .init(imageType: "EV01"))
    #expect(!FileManager.default.fileExists(atPath: url.path))
    try photo.save(to: url)
    #expect(try Data(contentsOf: url) == photo.dicomData())
    var edited = photo
    edited.dataSet.setString("edited", for: .patientID, vr: .LO)
    try edited.save(to: url)
    #expect(try DICOMFile.read(from: Data(contentsOf: url)).dataSet.string(for: .patientID) == "edited")
    #expect(throws: (any Error).self) {
        try photo.save(to: directory.appendingPathComponent("missing/file.dcm"))
    }
    #expect(throws: CocoaError(.fileWriteUnsupportedScheme)) {
        try photo.save(to: #require(URL(string: "https://example.invalid/photograph.dcm")))
    }
}

@Test func photographRejectsInvalidEditedIdentityBeforeSaving() throws {
    var photo = try OrthodonticPhotograph(
        rgb8: Data([255, 0, 0]), width: 1, height: 1, metadata: .init(imageType: "EV01"))
    photo.dataSet.setString("not-a-uid", for: .sopInstanceUID, vr: .UI)
    #expect(throws: MaterializationError.invalidUID("not-a-uid")) { try photo.dicomData() }
    photo.dataSet.setString(photo.dataSet.string(for: .studyInstanceUID)!, for: .sopInstanceUID, vr: .UI)
    #expect(throws: MaterializationError.invalidUID("Study, series and instance UIDs must differ")) {
        try photo.dicomData()
    }
}
