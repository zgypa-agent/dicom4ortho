import DICOMCore

// Standard dental/visible-light tags absent from DICOMKit's convenience constants.
// DICOM PS3.6 data dictionary; these are not private tags.
extension Tag {
    static let deviceSequence = Tag(group: 0x0050, element: 0x0010) // DeviceSequence
    static let viewCodeSequence = Tag(group: 0x0054, element: 0x0220) // ViewCodeSequence
    static let viewModifierCodeSequence = Tag(group: 0x0054, element: 0x0222) // ViewModifierCodeSequence
}
