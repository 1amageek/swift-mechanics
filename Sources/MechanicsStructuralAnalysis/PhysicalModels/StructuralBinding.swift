import MechanicsCore
import MechanicsModel
import MechanicsEquilibrium
import MechanicsFlexible
public struct StructuralBinding: Equatable, Sendable {
    public let identity: String
    public let revision: UInt64
    public let frame: EntityID
    public let source: StructuralSource
    public let provenance: SourceProvenance?
    public let sourceCoordinateIDs: [UInt64]
    public let reductionBasis: [Double]
    public let beam: UniformBeam?
    public let equilibriumModel: StaticForceModel?
    public let operatingParameter: Double?
    public let branchIdentity: String?
    public let retainedCoordinates: [Int]
    public let dimensions: [PhysicalDimension]
    public let coordinateScales: [Double]
    public let operatingTime: Double
    public let operatingCoordinates: [Double]
    internal init(identity: String, revision: UInt64, frame: EntityID, source: StructuralSource, provenance: SourceProvenance?, sourceCoordinateIDs: [UInt64], reductionBasis: [Double], beam: UniformBeam?, equilibriumModel: StaticForceModel?, operatingParameter: Double?, branchIdentity: String?, retainedCoordinates: [Int], dimensions: [PhysicalDimension], coordinateScales: [Double], operatingTime: Double, operatingCoordinates: [Double]) {
        self.identity=identity;self.revision=revision;self.frame=frame;self.source=source;self.provenance=provenance;self.sourceCoordinateIDs=sourceCoordinateIDs;self.reductionBasis=reductionBasis;self.beam=beam;self.equilibriumModel=equilibriumModel;self.operatingParameter=operatingParameter;self.branchIdentity=branchIdentity;self.retainedCoordinates=retainedCoordinates
        self.dimensions=dimensions;self.coordinateScales=coordinateScales;self.operatingTime=operatingTime;self.operatingCoordinates=operatingCoordinates
    }
}
