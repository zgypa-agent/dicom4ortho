import Foundation
import DICOMCore
import DICOMKit

/// Single-frame visible-light photograph materialization. No network behavior.
///
/// This value combines the orthodontic profile with DICOMKit's writer and codecs.
/// It loads immutable terminology once and can then be reused for many photographs.
/// The public API returns complete DICOM Part 10 bytes, not a dependency-specific
/// dataset. Encoding and clinical mapping remain separate implementation concerns.
public struct OrthodonticPhotograph: Sendable {
    private let terminology: Terminology

    /// Load the bundled reviewed terminology. Throws if the resource is missing or invalid.
    public init() throws {
        terminology = try .bundled()
    }

    /// Materialize interleaved RGB8 samples into a Part 10 VL Photographic instance.
    /// The input contains exactly three bytes per pixel, with no row padding or alpha.
    ///
    /// - Parameters:
    ///   - pixels: Row-major, interleaved red/green/blue samples, eight bits per component.
    ///   - width: Positive column count, at most 65535 (DICOM US).
    ///   - height: Positive row count, at most 65535 (DICOM US).
    ///   - metadata: Explicit clinical context and final instance identity.
    ///   - encoding: Output representation; uncompressed Explicit VR Little Endian by default.
    /// - Returns: Complete Part 10 file bytes, suitable for file or in-memory use.
    /// - Throws: ``MaterializationError`` for invalid supported inputs, or the underlying
    ///   DICOMKit error when a codec cannot encode the requested input.
    ///
    /// No filesystem or network effects occur. Encoding may be CPU/memory intensive;
    /// callers choose their execution context. Lossy encoding is explicitly requested
    /// and records derivation/provenance; a high quality value does not mean lossless.
    public func materializeRGB8(
        pixels: Data, width: Int, height: Int, metadata: PhotographMetadata,
        encoding: PhotographEncoding = .explicitLittleEndian
    ) throws -> Data {
        if let quality = encoding.quality {
            guard quality.isFinite, quality > 0, quality < 1 else {
                throw MaterializationError.invalidCompressionQuality
            }
        }
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
        let native = try DICOMFile.create(dataSet: dataset).write()
        if encoding == .explicitLittleEndian { return native }
        let encoded = try CompressionManager().compressData(
            native, codec: encoding.codec, quality: encoding.quality.map { .custom($0) })
        // The native intermediate is private implementation data, not a previously
        // published DICOM instance. The caller's UID identifies the final creation,
        // not that intermediate; keep it even when the codec marks lossy derivation.
        let file = try DICOMFile.read(from: encoded)
        var finalDataset = file.dataSet
        finalDataset.setString(metadata.sopInstanceUID, for: .sopInstanceUID, vr: .UI)
        return try DICOMFile.create(dataSet: finalDataset,
                                    transferSyntaxUID: encoding.transferSyntaxUID).write()
    }

    func makeMetadata(_ metadata: PhotographMetadata) throws -> DataSet {
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
        var direction = view.viewCode
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
        let sex = ["M": "M", "MALE": "M", "F": "F", "FEMALE": "F", "O": "O", "OTHER": "O"]
        dataset.setString(sex[metadata.patientSex.uppercased()] ?? "", for: .patientSex, vr: .CS)
        if !metadata.providerFamilyName.isEmpty || !metadata.providerGivenName.isEmpty {
            dataset.setString(metadata.providerFamilyName + "^" + metadata.providerGivenName,
                              for: .physiciansOfRecord, vr: .PN)
        }
        if !metadata.operatorFamilyName.isEmpty || !metadata.operatorGivenName.isEmpty {
            dataset.setString(metadata.operatorFamilyName + "^" + metadata.operatorGivenName,
                              for: .operatorsName, vr: .PN)
        }
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
        dataset.setString(view.seriesDescription, for: .seriesDescription, vr: .LO)
        dataset.setString("\(keyword)^\(view.description)".replacingOccurrences(of: "\u{a0}", with: " "),
                          for: .imageComments, vr: .LT)
        dataset.setString(view.imageLaterality, for: .imageLaterality, vr: .CS)
        if let orientation = view.patientOrientation {
            dataset.setStrings(orientation, for: .patientOrientation, vr: .CS)
        } else {
            // PS3.3 General Image: Type 2C when Image Orientation (Patient) is absent.
            // Unknown orientation is empty, not a guessed direction or an omitted element.
            dataset.setString("", for: .patientOrientation, vr: .CS)
        }
        dataset.setSequence([codeItem(view.anatomicRegion,
                                     modifier: view.anatomicRegionModifier,
                                     modifierTag: .anatomicRegionModifierSequence)],
                            for: .anatomicRegionSequence)
        if let primary = view.primaryAnatomicStructure {
            dataset.setSequence([codeItem(primary,
                                         modifier: view.primaryAnatomicStructureModifier,
                                         modifierTag: .primaryAnatomicStructureModifierSequence)],
                                for: .primaryAnatomicStructureSequence)
        }
        if !view.devices.isEmpty {
            dataset.setSequence(view.devices.map { codeItem($0) }, for: .deviceSequence)
        }
        if let direction {
            var item = codeDataset(direction)
            if !view.viewModifiers.isEmpty {
                item.setSequence(view.viewModifiers.map { codeItem($0) },
                                 for: .viewModifierCodeSequence)
            }
            dataset.setSequence([SequenceItem(elements: item.tags.compactMap { item[$0] })],
                                for: .viewCodeSequence)
        }
        var context: [SequenceItem] = []
        let groups: [(String, [Terminology.Code])] = [
            ("OrthognathicFunctionalConditions", view.orthognathicFunctionalConditions),
            ("FindingByInspection", view.findingsByInspection),
            ("ObservableEntity", view.observableEntities),
            ("DentalOcclusion", view.dentalOcclusion.map { [$0] } ?? [])
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
        try applyClinicalMetadata(metadata, to: &dataset)
        return dataset
    }

    private func applyClinicalMetadata(
        _ metadata: PhotographMetadata, to dataset: inout DataSet
    ) throws {
        if let acquired = metadata.acquisitionDateTime {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.calendar = Calendar(identifier: .gregorian)
            formatter.timeZone = metadata.acquisitionTimeZone
            formatter.dateFormat = "yyyyMMdd"
            let date = formatter.string(from: acquired)
            formatter.dateFormat = "HHmmss.SSSSSS"
            let time = formatter.string(from: acquired)
            formatter.dateFormat = "Z"
            let offset = formatter.string(from: acquired)
            dataset.setString(date + time + offset, for: .acquisitionDateTime, vr: .DT)
            dataset.setString(date, for: .acquisitionDate, vr: .DA)
            dataset.setString(time, for: .acquisitionTime, vr: .TM)
            dataset.setString(date, for: .contentDate, vr: .DA)
            dataset.setString(time, for: .contentTime, vr: .TM)
            dataset.setString(offset, for: .timezoneOffsetFromUTC, vr: .SH)
        }
        guard let progress = metadata.treatmentProgress else { return }
        guard let acquired = metadata.acquisitionDateTime else {
            throw MaterializationError.acquisitionDateRequired
        }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = metadata.acquisitionTimeZone
        let date = try ClinicalDate(year: calendar.component(.year, from: acquired),
                                    month: calendar.component(.month, from: acquired),
                                    day: calendar.component(.day, from: acquired))
        let days = try progress.eventDate.days(until: date)
        guard days >= 0 else { throw MaterializationError.treatmentEventAfterAcquisition }
        guard let eventCode = terminology.codes[progress.event.rawValue],
              let eventName = terminology.codes["TemporalEventType"],
              let offsetName = terminology.codes["OffsetFromEvent"],
              let dayCode = terminology.codes["day"] else {
            throw MaterializationError.invalidTerminology("Treatment progress")
        }
        var event = DataSet()
        event.setString("CODE", for: .valueType, vr: .CS)
        event.setSequence([codeItem(eventName)], for: .conceptNameCodeSequence)
        event.setSequence([codeItem(eventCode)], for: .conceptCodeSequence)
        var offset = DataSet()
        offset.setString("NUMERIC", for: .valueType, vr: .CS)
        offset.setSequence([codeItem(offsetName)], for: .conceptNameCodeSequence)
        offset.setSequence([codeItem(dayCode)], for: .measurementUnitsCodeSequence)
        offset.setString(String(days), for: .numericValue, vr: .DS)
        var context = dataset.sequence(for: .acquisitionContextSequence) ?? []
        context.append(SequenceItem(elements: event.tags.compactMap { event[$0] }))
        context.append(SequenceItem(elements: offset.tags.compactMap { offset[$0] }))
        dataset.setSequence(context, for: .acquisitionContextSequence)
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
