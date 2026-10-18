import Foundation

/// Reviewed orthodontic terminology, bundled rather than fetched at runtime.
///
/// Both language ports are generated in one maintenance run from the same resolved
/// source data. SwiftPM copies the committed JSON into this target's resource bundle;
/// neither a Python installation nor a live terminology server is needed at runtime.
/// This type exposes the catalog; internal `View` records drive clinical mapping.
public struct Terminology: Decodable, Sendable {
    /// A coded concept, independently of any particular DICOM dataset representation.
    public struct Code: Decodable, Sendable, Equatable {
        /// Code Value, for example a SNOMED CT identifier.
        public let value: String
        /// DICOM Coding Scheme Designator, for example `SCT` or `DCM`.
        public let scheme: String
        /// Code Meaning, already constrained by the terminology generator for DICOM use.
        public let meaning: String
    }

    /// A published ADA 1100 photograph type and its catalog labels.
    public struct ImageType: Decodable, Sendable {
        /// Stable photograph keyword, for example `EV01`.
        public let keyword: String
        /// Published compact abbreviation, not a DICOM UID or filename convention.
        public let abbreviation: String
        /// Full human-readable description of the photograph type.
        public let meaning: String
        /// Coded identifier suitable for a scheduled protocol or photograph-type mapping.
        public let code: Code
    }

    struct View: Decodable, Sendable {
        let keyword: String
        let patientOrientation: [String]?
        let imageLaterality: String
        let anatomicRegion: Code
        let anatomicRegionModifier: Code?
        let primaryAnatomicStructure: Code?
        let primaryAnatomicStructureModifier: Code?
        let devices: [Code]
        let viewCode: Code?
        let viewModifiers: [Code]
        let orthognathicFunctionalConditions: [Code]
        let findingsByInspection: [Code]
        let observableEntities: [Code]
        let dentalOcclusion: Code?
        let description: String
        let seriesDescription: String

        // The interchange schema is language-neutral snake_case. Swift properties
        // use lowerCamelCase; explicit keys keep decoding stable without global magic.
        private enum CodingKeys: String, CodingKey {
            case keyword, devices, description
            case patientOrientation = "patient_orientation"
            case imageLaterality = "image_laterality"
            case anatomicRegion = "anatomic_region"
            case anatomicRegionModifier = "anatomic_region_modifier"
            case primaryAnatomicStructure = "primary_anatomic_structure"
            case primaryAnatomicStructureModifier = "primary_anatomic_structure_modifier"
            case viewCode = "view_code"
            case viewModifiers = "view_modifiers"
            case orthognathicFunctionalConditions = "orthognathic_functional_conditions"
            case findingsByInspection = "findings_by_inspection"
            case observableEntities = "observable_entities"
            case dentalOcclusion = "dental_occlusion"
            case seriesDescription = "series_description"
        }
    }

    /// Structural concepts and context-group codes indexed by generator keyword.
    public let codes: [String: Code]
    /// Published photograph catalog indexed by ADA keyword.
    public let imageTypes: [String: ImageType]
    /// SHA-256 of the corresponding generated Python artifact, for cross-port traceability.
    public let sourceLockSHA256: String
    let views: [String: View]

    private enum CodingKeys: String, CodingKey {
        case codes
        case views
        case imageTypes = "image_types"
        case sourceLockSHA256 = "source_lock_sha256"
    }

    /// Load the committed mapping snapshot; errors are not hidden by fallback data.
    /// - Throws: A resource I/O or JSON decoding error if the bundled snapshot is unavailable.
    public static func bundled() throws -> Terminology {
        guard let url = Bundle.module.url(forResource: "terminology", withExtension: "json") else {
            throw CocoaError(.fileNoSuchFile)
        }
        return try JSONDecoder().decode(Self.self, from: Data(contentsOf: url))
    }
}
