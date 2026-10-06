/// A caller draft. Only initialize's original model/law admission can issue an assembly state.
public struct WheeledAssemblyConfiguration: Sendable {
    public let model: CompiledMechanicalModel
    public let topology: WheeledAssemblyTopology
    public let calibration: SourceProvenance
    public let rearSuspensionLaw, frontSuspensionLaw: PolynomialSpringDamper
    public let steeringServo: ScalarServo
    public let driveline: AffineTransmission
    public let maximumShaftEffort, maximumRearBrakeTorque, maximumFrontBrakeTorque: Double
    public let gravity: AffineGravity
    public let policy: WheeledAssemblyPolicy
    public init(model: CompiledMechanicalModel, topology: WheeledAssemblyTopology, calibration: SourceProvenance,
                rearSuspensionLaw: PolynomialSpringDamper, frontSuspensionLaw: PolynomialSpringDamper,
                steeringServo: ScalarServo, driveline: AffineTransmission, maximumShaftEffort: Double,
                maximumRearBrakeTorque: Double, maximumFrontBrakeTorque: Double,
                gravity: AffineGravity, policy: WheeledAssemblyPolicy) throws(WheeledAssemblyFailure) {
        guard calibration.revision > 0, [maximumShaftEffort,maximumRearBrakeTorque,maximumFrontBrakeTorque].allSatisfy({ $0.isFinite && $0 > 0 }),
              rearSuspensionLaw.coordinateKind == .translation, frontSuspensionLaw.coordinateKind == .translation,
              gravity.frame == model.tree.worldFrame else { throw .refusal(.invalidInput) }
        // FIXME(INCOMPLETE_IMPLEMENTATION): Variable or nonuniform gravity has no interval field-work contract here.
        // Assembly initialize refuses it until distributed mass moments and time-dependent field work are verified.
        guard gravity.gradient == .zero, gravity.uniformTimeDerivative == .zero else { throw .refusal(.outsideCalibration) }
        self.model=model; self.topology=topology; self.calibration=calibration
        self.rearSuspensionLaw=rearSuspensionLaw; self.frontSuspensionLaw=frontSuspensionLaw
        self.steeringServo=steeringServo; self.driveline=driveline; self.maximumShaftEffort=maximumShaftEffort
        self.maximumRearBrakeTorque=maximumRearBrakeTorque; self.maximumFrontBrakeTorque=maximumFrontBrakeTorque
        self.gravity=gravity; self.policy=policy
    }
}
