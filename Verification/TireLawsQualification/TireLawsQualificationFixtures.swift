import SwiftMechanics

public enum TireLawsQualificationFixtures {
    public static func reference(_ kind: EntityKind, _ key: String, revision: UInt64 = 1) throws -> ModelReference {
        ModelReference(id:try EntityID(kind:kind,key:key),revision:revision)
    }
    public static func tire(revision: UInt64 = 1) throws -> ModelReference {try reference(.body,"qualified-tire-µ",revision:revision)}
    public static func road(revision: UInt64 = 1) throws -> ModelReference {try reference(.material,"qualified-road",revision:revision)}
    public static func world(revision: UInt64 = 1) throws -> ModelReference {try reference(.frame,"qualified-world",revision:revision)}
    public static func domain(loadMinimum: Double = 100, loadMaximum: Double = 400,
                              slipMaximum: Double = 2, lateralMaximum: Double = 1) throws(TireLawError) -> TireCalibrationDomain {
        try TireCalibrationDomain(minimumNormalLoad:loadMinimum,maximumNormalLoad:loadMaximum,minimumRadius:0.4,maximumRadius:0.6,
            minimumAbsoluteLongitudinalSpeed:0.2,maximumAbsoluteLongitudinalSpeed:20,maximumAbsoluteLateralSpeed:10,
            maximumAbsoluteSpin:100,maximumAbsoluteSlipRatio:slipMaximum,maximumAbsoluteLateralSlipTangent:lateralMaximum)
    }
    public static func calibration(longitudinal: Double = 1000, lateral: Double = 2000, friction: Double = 0.5,
                                   rolling: Double = 0.02, domain: TireCalibrationDomain? = nil,
                                   formulation: String = TireBrushCalibration.formulation) throws -> TireBrushCalibration {
        try TireBrushCalibration(source:"synthetic-radial-qualification-µ",revision:7,tire:tire(),roadSurface:road(),
            longitudinalStiffness:longitudinal,lateralStiffness:lateral,frictionCoefficient:friction,rollingResistanceLength:rolling,
            domain:domain ?? self.domain(),fittedFormulation:formulation)
    }
    public static func policy() throws(TireLawError) -> TireAcceptancePolicy {
        try TireAcceptancePolicy(contactDistanceTolerance:1e-10,normalSpeedTolerance:1e-10,absolutePowerTolerance:1e-8,
            referencePower:1,absoluteForceTolerance:1e-8,referenceForce:1,relativeTolerance:1e-11)
    }
    public static func frame(rotation: UnitQuaternion = .identity, point: Vector3 = .zero,
                             reference: ModelReference? = nil) throws -> TireRoadFrame {
        try TireRoadFrame(reference:reference ?? world(),contactToReference:rotation,planePoint:point)
    }
    public static func sample(vx: Double = 10, vy: Double = 0, vz: Double = 0, spin: Double = 20,
                              normalLoad: Double = 200, radius: Double = 0.5, height: Double? = nil,
                              roadVelocity: Vector3 = .zero, rotation: UnitQuaternion = .identity, point: Vector3 = .zero,
                              tire: ModelReference? = nil, road: ModelReference? = nil, frame: ModelReference? = nil,
                              calibrationRevision: UInt64 = 7) throws -> TireRoadSample {
        try TireRoadSample(tire:tire ?? self.tire(),roadSurface:road ?? self.road(),referenceFrame:frame ?? world(),
            calibrationRevision:calibrationRevision,timeSeconds:2,
            centerPosition:point.adding(rotation.rotating(Vector3(0,0,height ?? radius))),
            centerVelocity:rotation.rotating(Vector3(vx,vy,vz)).adding(roadVelocity),roadContactVelocity:roadVelocity,
            spin:spin,radius:radius,normalLoad:normalLoad)
    }
    public static func work(limit: Int = 100_000, scalars: Int = 192,
                            cancelled: @escaping @Sendable () -> Bool = {false}) throws -> LoadWork {
        LoadWork(budget:try LoadBudget(maximumWork:limit,maximumScalars:scalars,isCancelled:cancelled))
    }
}
