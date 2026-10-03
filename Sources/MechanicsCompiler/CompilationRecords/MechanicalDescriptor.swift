import MechanicsModel
import MechanicsJoints

public struct MechanicalDescriptor: Equatable, Sendable {
    public let identity: String
    public let revision: UInt64
    public let bodies: [MechanicalBody]
    public let joints: [MechanicalJoint]
    public let root: EntityID
    public let rootBase: BaseLayout
    public let rootAuthority: CoordinateAuthority
    public let worldFrame: EntityID
    public let initialState: KinematicState
    public let representationRequirements: [BodyRepresentationRequirement]
    public let features: [FeatureRequirement]
    public let extensions: [MechanicalExtensionRecord]

    public init(identity: String, revision: UInt64, bodies: [MechanicalBody], joints: [MechanicalJoint],
                root: EntityID, rootBase: BaseLayout, rootAuthority: CoordinateAuthority, worldFrame: EntityID,
                initialState: KinematicState, representationRequirements: [BodyRepresentationRequirement],
                features: [FeatureRequirement], extensions: [MechanicalExtensionRecord]) throws(CompilationFailure) {
        guard !identity.isEmpty else { throw .one(.invalidInput, .input, message: "Model identity must be nonempty.") }
        self.identity = identity; self.revision = revision; self.bodies = bodies; self.joints = joints
        self.root = root; self.rootBase = rootBase; self.rootAuthority = rootAuthority; self.worldFrame = worldFrame
        self.initialState = initialState; self.representationRequirements = representationRequirements
        self.features = features; self.extensions = extensions
    }
}
