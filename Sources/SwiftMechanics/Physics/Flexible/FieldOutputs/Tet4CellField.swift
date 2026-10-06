public struct Tet4CellField: Sendable {
    public let cell: TetrahedronCell
    public let material: FlexibleMaterial
    public let referenceVolume: Double, currentVolume: Double, volumeRatio: Double
    public let deformationGradient: Matrix3
    public let response: FiniteStressResponse
    /// Positive cell energy-gradient forces in the cell's original node order.
    public let internalForces: [Vector3]
    public let storedEnergy: Double
    public let constitutivePower: Double
    internal init(cell: TetrahedronCell, material: FlexibleMaterial, referenceVolume: Double,
                  currentVolume: Double, volumeRatio: Double, deformationGradient: Matrix3,
                  response: FiniteStressResponse, internalForces: [Vector3], storedEnergy: Double,
                  constitutivePower: Double) {
        self.cell = cell; self.material = material; self.referenceVolume = referenceVolume
        self.currentVolume = currentVolume; self.volumeRatio = volumeRatio
        self.deformationGradient = deformationGradient; self.response = response
        self.internalForces = internalForces; self.storedEnergy = storedEnergy; self.constitutivePower = constitutivePower
    }
}
