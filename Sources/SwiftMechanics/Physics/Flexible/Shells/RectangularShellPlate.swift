/// A uniformly subdivided flat reference plate; no physical body state is implied.
public struct RectangularShellPlate: Sendable {
    public let identity: String
    public let revision: UInt64
    public let frame: EntityID
    public let source: SourceProvenance
    public let basis: ShellBasis
    public let width: Double
    public let height: Double
    public let thickness: Double
    public let density: Double
    public let elasticity: IsotropicElasticity
    public let elementsX: Int
    public let elementsY: Int
    public let nodeCount: Int
    public let cellCount: Int
    public let coordinateCount: Int
    public let shearCorrection: Double
    public let massDampingRate: Double
    public let stiffnessDampingTime: Double
    public let maximumKinematicMagnitude: Double
    public let maximumLinearStrain: Double
    public let formulation: ShellFormulation

    public init(identity: String, revision: UInt64, frame: EntityID, source: SourceProvenance,
                basis: ShellBasis, width: Double, height: Double, thickness: Double, density: Double,
                elasticity: IsotropicElasticity, elementsX: Int, elementsY: Int,
                shearCorrection: Double, massDampingRate: Double, stiffnessDampingTime: Double,
                maximumKinematicMagnitude: Double, maximumLinearStrain: Double,
                formulation: ShellFormulation = .infinitesimalMITC4) throws(ShellError) {
        guard !identity.isEmpty, frame.kind == .frame else { throw .invalidParameter(name: "identityOrFrame") }
        guard width.isFinite, width > 0, height.isFinite, height > 0,
              thickness.isFinite, thickness > 0, density.isFinite, density > 0 else {
            throw .invalidParameter(name: "geometryOrDensity")
        }
        guard elementsX > 0, elementsY > 0 else { throw .invalidParameter(name: "subdivision") }
        guard shearCorrection.isFinite, shearCorrection > 0, shearCorrection <= 1,
              massDampingRate.isFinite, massDampingRate >= 0,
              stiffnessDampingTime.isFinite, stiffnessDampingTime >= 0 else {
            throw .invalidParameter(name: "shearOrDamping")
        }
        guard maximumKinematicMagnitude.isFinite, maximumKinematicMagnitude > 0, maximumKinematicMagnitude <= 0.1,
              maximumLinearStrain.isFinite, maximumLinearStrain > 0, maximumLinearStrain <= 0.05 else {
            throw .invalidParameter(name: "linearDomain")
        }
        do {
            nodeCount = try NumericalWork.product(NumericalWork.sum(elementsX, 1), NumericalWork.sum(elementsY, 1))
            cellCount = try NumericalWork.product(elementsX, elementsY)
            coordinateCount = try NumericalWork.product(nodeCount, 5)
        } catch { throw .numerical(error) }
        self.identity = identity; self.revision = revision; self.frame = frame; self.source = source
        self.basis = basis; self.width = width; self.height = height; self.thickness = thickness
        self.density = density; self.elasticity = elasticity; self.elementsX = elementsX; self.elementsY = elementsY
        self.shearCorrection = shearCorrection; self.massDampingRate = massDampingRate
        self.stiffnessDampingTime = stiffnessDampingTime; self.maximumKinematicMagnitude = maximumKinematicMagnitude
        self.maximumLinearStrain = maximumLinearStrain; self.formulation = formulation
    }

    /// Reference node identifier is exactly its checked row-major ordinal.
    public func referencePosition(node: Int) throws(ShellError) -> Vector3 {
        guard node >= 0, node < nodeCount else { throw .invalidLayout }
        let column = node % (elementsX + 1), row = node / (elementsX + 1)
        return try basis.referencePosition(x: width * (Double(column) / Double(elementsX)),
                                           y: height * (Double(row) / Double(elementsY)))
    }
}
