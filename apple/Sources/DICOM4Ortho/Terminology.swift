import Foundation

/// Reviewed orthodontic terminology, bundled rather than fetched at runtime.
public struct Terminology: Decodable, Sendable {
    public struct Code: Decodable, Sendable, Equatable {
        public let value: String
        public let scheme: String
        public let meaning: String
    }

    public struct ImageType: Decodable, Sendable {
        public let keyword: String
        public let abbreviation: String
        public let meaning: String
        public let code: Code
    }

    struct View: Decodable, Sendable {
        let keyword: String
        let patient_orientation: [String]?
        let image_laterality: String
        let anatomic_region: Code
        let anatomic_region_modifier: Code?
        let primary_anatomic_structure: Code?
        let primary_anatomic_structure_modifier: Code?
        let devices: [Code]
        let view_code: Code?
        let view_modifiers: [Code]
        let orthognathic_functional_conditions: [Code]
        let findings_by_inspection: [Code]
        let observable_entities: [Code]
        let dental_occlusion: Code?
        let description: String
        let series_description: String
    }

    public let codes: [String: Code]
    public let imageTypes: [String: ImageType]
    public let sourceLockSHA256: String
    let views: [String: View]

    private enum CodingKeys: String, CodingKey {
        case codes
        case views
        case imageTypes = "image_types"
        case sourceLockSHA256 = "source_lock_sha256"
    }

    /// Load the committed mapping snapshot; errors are not hidden by fallback data.
    public static func bundled() throws -> Terminology {
        guard let url = Bundle.module.url(forResource: "terminology", withExtension: "json") else {
            throw CocoaError(.fileNoSuchFile)
        }
        return try JSONDecoder().decode(Self.self, from: Data(contentsOf: url))
    }
}
