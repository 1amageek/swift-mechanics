public enum AttachmentDegreesOfFreedom: Sendable {
    /// Directions are fixed unit vectors expressed in the common query frame.
    case pointTranslation(directions: [Vector3])
    /// Requires an actual material rotation supplier, unavailable in the selected Tet4 point contract.
    case materialOrientation
}
