import MechanicsJoints

public struct ExtensionValidationContext: Sendable {
    public let descriptor: MechanicalDescriptor
    public let tree: KinematicTree

    internal init(descriptor: MechanicalDescriptor, tree: KinematicTree) { self.descriptor = descriptor; self.tree = tree }
}
