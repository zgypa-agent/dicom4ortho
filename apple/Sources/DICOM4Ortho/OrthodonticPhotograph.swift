import Foundation
import DICOMCore
import DICOMKit

/// Errors specific to the orthodontic profile, before serialization is attempted.
public enum MaterializationError: Error, Equatable {
    case unknownImageType(String)
    case directionRequired(String)
    case unknownDirection(String)
    case invalidPixelData
    case invalidUID(String)
    case invalidTerminology(String)
}

/// Patient and instance context for a photograph. Empty Type 2 values remain empty.
public struct PhotographMetadata: Sendable {
    public var patientID = ""
    public var patientFamilyName = ""
    public var patientGivenName = ""
    public var patientBirthDate = ""
    public var patientSex = ""
    public var studyInstanceUID: String
    public var seriesInstanceUID: String
    public var sopInstanceUID: String
    public var imageType: String
    public var directionKeyword: String?

    /// Generate instance identity once so repeated serialization retains it.
    public init(imageType: String) {
        self.imageType = imageType
        studyInstanceUID = UIDGenerator.generateStudyInstanceUID().value
        seriesInstanceUID = UIDGenerator.generateSeriesInstanceUID().value
        sopInstanceUID = UIDGenerator.generateSOPInstanceUID().value
    }
}

/// Single-frame visible-light photograph materialization. No network behavior.
public struct OrthodonticPhotograph: Sendable {
    private let terminology: Terminology

    public init() throws {
        terminology = try .bundled()
    }

    /// Materialize interleaved RGB8 samples into a Part 10 VL Photographic instance.
    /// The input contains exactly three bytes per pixel, with no row padding or alpha.
    public func materializeRGB8(
        pixels: Data, width: Int, height: Int, metadata: PhotographMetadata
    ) throws -> Data {
        guard width > 0, height > 0, width <= 65535, height <= 65535 else {
            throw MaterializationError.invalidPixelData
        }
        let (area, overflow) = width.multipliedReportingOverflow(by: height)
        let (byteCount, byteOverflow) = area.multipliedReportingOverflow(by: 3)
        guard !overflow, !byteOverflow, pixels.count == byteCount else {
            throw MaterializationError.invalidPixelData
        }
        var dataset = try makeMetadata(metadata)
        dataset.setUInt16(UInt16(height), for: .rows)
        dataset.setUInt16(UInt16(width), for: .columns)
        dataset.setUInt16(3, for: .samplesPerPixel)
        dataset.setUInt16(0, for: .planarConfiguration)
        dataset.setUInt16(8, for: .bitsAllocated)
        dataset.setUInt16(8, for: .bitsStored)
        dataset.setUInt16(7, for: .highBit)
        dataset.setUInt16(0, for: .pixelRepresentation)
        dataset.setString("RGB", for: .photometricInterpretation, vr: .CS)
        dataset.setString("00", for: .lossyImageCompression, vr: .CS)
        dataset[.pixelData] = .data(tag: .pixelData, vr: .OB, data: pixels)
        return try DICOMFile.create(dataSet: dataset).write()
    }

    private func makeMetadata(_ metadata: PhotographMetadata) throws -> DataSet {
        for uid in [metadata.studyInstanceUID, metadata.seriesInstanceUID, metadata.sopInstanceUID] {
            guard Self.isValidUID(uid) else { throw MaterializationError.invalidUID(uid) }
        }
        guard Set([metadata.studyInstanceUID, metadata.seriesInstanceUID,
                   metadata.sopInstanceUID]).count == 3 else {
            throw MaterializationError.invalidUID("Study, series and instance UIDs must differ")
        }
        let keyword = metadata.imageType.replacingOccurrences(of: "-", with: "")
        guard let view = terminology.views[keyword] else {
            throw MaterializationError.unknownImageType(keyword)
        }
        var direction = view.view_code
        if let requested = metadata.directionKeyword {
            guard let code = terminology.codes[requested] else {
                throw MaterializationError.unknownDirection(requested)
            }
            direction = code
        }
        if direction == nil && keyword != "IV29" {
            throw MaterializationError.directionRequired(keyword)
        }

        var dataset = DataSet()
        dataset.setString("ISO_IR 192", for: .specificCharacterSet, vr: .CS)
        dataset.setString("1.2.840.10008.5.1.4.1.1.77.1.4", for: .sopClassUID, vr: .UI)
        dataset.setString(metadata.sopInstanceUID, for: .sopInstanceUID, vr: .UI)
        dataset.setString(metadata.studyInstanceUID, for: .studyInstanceUID, vr: .UI)
        dataset.setString(metadata.seriesInstanceUID, for: .seriesInstanceUID, vr: .UI)
        dataset.setString("XC", for: .modality, vr: .CS)
        dataset.setStrings(["ORIGINAL", "PRIMARY"], for: .imageType, vr: .CS)
        dataset.setString(metadata.patientID, for: .patientID, vr: .LO)
        dataset.setString(metadata.patientFamilyName + "^" + metadata.patientGivenName,
                          for: .patientName, vr: .PN)
        dataset.setString(metadata.patientBirthDate, for: .patientBirthDate, vr: .DA)
        dataset.setString(metadata.patientSex, for: .patientSex, vr: .CS)
        dataset.setString("", for: .studyDate, vr: .DA)
        dataset.setString("", for: .studyTime, vr: .TM)
        dataset.setString("", for: .accessionNumber, vr: .SH)
        dataset.setString("", for: .referringPhysicianName, vr: .PN)
        dataset.setString("000", for: .studyID, vr: .SH)
        dataset.setString("000", for: .seriesNumber, vr: .IS)
        dataset.setString("000", for: .instanceNumber, vr: .IS)
        dataset.setString("", for: .manufacturer, vr: .LO)
        dataset.setString("NO", for: .burnedInAnnotation, vr: .CS)
        dataset.setString("NO", for: .qualityControlImage, vr: .CS)
        dataset.setString(view.series_description, for: .seriesDescription, vr: .LO)
        dataset.setString("\(keyword)^\(view.description)".replacingOccurrences(of: "\u{a0}", with: " "),
                          for: .imageComments, vr: .LT)
        dataset.setString(view.image_laterality, for: .imageLaterality, vr: .CS)
        if let orientation = view.patient_orientation {
            dataset.setStrings(orientation, for: .patientOrientation, vr: .CS)
        }
        dataset.setSequence([codeItem(view.anatomic_region,
                                     modifier: view.anatomic_region_modifier,
                                     modifierTag: .anatomicRegionModifierSequence)],
                            for: .anatomicRegionSequence)
        if let primary = view.primary_anatomic_structure {
            dataset.setSequence([codeItem(primary,
                                         modifier: view.primary_anatomic_structure_modifier,
                                         modifierTag: .primaryAnatomicStructureModifierSequence)],
                                for: .primaryAnatomicStructureSequence)
        }
        if !view.devices.isEmpty {
            dataset.setSequence(view.devices.map { codeItem($0) }, for: .deviceSequence)
        }
        if let direction {
            var item = codeDataset(direction)
            if !view.view_modifiers.isEmpty {
                item.setSequence(view.view_modifiers.map { codeItem($0) },
                                 for: .viewModifierCodeSequence)
            }
            dataset.setSequence([SequenceItem(elements: item.tags.compactMap { item[$0] })],
                                for: .viewCodeSequence)
        }
        var context: [SequenceItem] = []
        let groups: [(String, [Terminology.Code])] = [
            ("OrthognathicFunctionalConditions", view.orthognathic_functional_conditions),
            ("FindingByInspection", view.findings_by_inspection),
            ("ObservableEntity", view.observable_entities),
            ("DentalOcclusion", view.dental_occlusion.map { [$0] } ?? [])
        ]
        for (name, values) in groups {
            guard let concept = terminology.codes[name] else {
                throw MaterializationError.invalidTerminology(name)
            }
            for value in values {
                var item = DataSet()
                item.setString("CODE", for: .valueType, vr: .CS)
                item.setSequence([codeItem(concept)], for: .conceptNameCodeSequence)
                item.setSequence([codeItem(value)], for: .conceptCodeSequence)
                context.append(SequenceItem(elements: item.tags.compactMap { item[$0] }))
            }
        }
        dataset.setSequence(context, for: .acquisitionContextSequence)
        return dataset
    }

    private func codeDataset(_ code: Terminology.Code) -> DataSet {
        var dataset = DataSet()
        dataset.setString(code.value, for: .codeValue, vr: .SH)
        dataset.setString(code.scheme, for: .codingSchemeDesignator, vr: .SH)
        dataset.setString(String(code.meaning.prefix(64)), for: .codeMeaning, vr: .LO)
        return dataset
    }

    private func codeItem(
        _ code: Terminology.Code, modifier: Terminology.Code? = nil,
        modifierTag: Tag? = nil
    ) -> SequenceItem {
        var dataset = codeDataset(code)
        if let modifier, let modifierTag {
            dataset.setSequence([codeItem(modifier)], for: modifierTag)
        }
        return SequenceItem(elements: dataset.tags.compactMap { dataset[$0] })
    }

    private static func isValidUID(_ uid: String) -> Bool {
        guard !uid.isEmpty, uid.utf8.count <= 64 else { return false }
        return uid.split(separator: ".", omittingEmptySubsequences: false).allSatisfy {
            !$0.isEmpty && ($0.count == 1 || $0.first != "0")
                && $0.utf8.allSatisfy { $0 >= 48 && $0 <= 57 }
        }
    }
}
