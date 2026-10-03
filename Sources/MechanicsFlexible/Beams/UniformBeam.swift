import MechanicsCore
import MechanicsModel
import MechanicsMaterials
public struct UniformBeam: Equatable, Sendable {
    public let identity: String
    public let revision: UInt64
    public let frame: EntityID
    public let source: SourceProvenance
    public let length: Double
    public let area: Double
    public let secondMoment: Double
    public let maximumFiberDistance: Double
    public let density: Double
    public let elasticity: IsotropicElasticity
    public let elements: Int
    public let massDamping: Double
    public let stiffnessDamping: Double
    public let maximumSlope: Double
    public let maximumLinearStrain: Double
    public init(identity: String, revision: UInt64, frame: EntityID, source: SourceProvenance, length: Double, area: Double,
                secondMoment: Double, maximumFiberDistance: Double, density: Double, elasticity: IsotropicElasticity, elements: Int,
                massDamping: Double, stiffnessDamping: Double, maximumSlope: Double, maximumLinearStrain: Double) throws(BeamError) {
        guard !identity.isEmpty, frame.kind == .frame, elements > 0,
              length.isFinite, length > 0, area.isFinite, area > 0, secondMoment.isFinite, secondMoment > 0,
              maximumFiberDistance.isFinite, maximumFiberDistance > 0, density.isFinite, density > 0, massDamping.isFinite, massDamping >= 0,
              stiffnessDamping.isFinite, stiffnessDamping >= 0, maximumSlope.isFinite, maximumSlope > 0,
              maximumLinearStrain.isFinite, maximumLinearStrain > 0 else { throw .invalidInput }
        let bound=area*maximumFiberDistance*maximumFiberDistance
        guard bound.isFinite,bound>=secondMoment else { throw .invalidInput }
        self.identity=identity;self.revision=revision;self.frame=frame;self.source=source;self.length=length;self.area=area
        self.secondMoment=secondMoment;self.maximumFiberDistance=maximumFiberDistance;self.density=density;self.elasticity=elasticity;self.elements=elements
        self.massDamping=massDamping;self.stiffnessDamping=stiffnessDamping;self.maximumSlope=maximumSlope;self.maximumLinearStrain=maximumLinearStrain
    }
}
