/// Adapter-issued immutable model; original source and losses survive every export.
public struct MJCFImportedModel: Sendable {
    public let normativeVersion = "MuJoCo 3.3.7 / f1d45bd"
    public let context: MJCFImportContext
    public let document: XMLDocument
    public let nativeDocument: NativeMechanicalDocument
    public let compiled: CompiledMechanicalModel
    public let bodies: [MJCFEntityBinding]
    public let joints: [MJCFScalarJoint]
    public let tendons: [MJCFAffinePort]
    public let motors: [MJCFAffinePort]
    public let materials: [MJCFMaterial]
    public let sensors: [MJCFSensor]
    public let equalities: [MJCFEqualityBinding]
    public let equalitySystem: QuadraticConstraintSystem?
    public let initialEqualityEvaluation: ConstraintEvaluation?
    public let initialPhysicalEqualities: [MJCFEqualitySample]
    public let gravity: AffineGravity
    public let losses: [MJCFLoss]
    internal init(context: MJCFImportContext, document: XMLDocument, compiled: CompiledMechanicalModel,
                  bodies: [MJCFEntityBinding], joints: [MJCFScalarJoint], features: MJCFModelFeatures, gravity: AffineGravity, losses: [MJCFLoss]) {
        self.context = context; self.document = document; self.compiled = compiled
        nativeDocument = NativeMechanicalDocument(descriptor: compiled.descriptor, assets: context.assets)
        self.bodies = bodies; self.joints = joints; tendons = features.tendons; motors = features.motors
        materials = features.materials; sensors = features.sensors; equalities = features.equalities
        equalitySystem = features.system; initialEqualityEvaluation = features.initialEvaluation
        initialPhysicalEqualities = features.initialPhysicalEqualities
        self.gravity = gravity; self.losses = losses
    }
}
