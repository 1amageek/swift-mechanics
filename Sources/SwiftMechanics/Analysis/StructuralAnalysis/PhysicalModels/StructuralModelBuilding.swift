public protocol StructuralModelBuilding: Sendable {
    func beam(_ assembly: BeamAssembly, fixedCoordinates: [Int], compressiveLoad: Double, expectedRevision: UInt64,
              policy: StructuralPolicy, work: inout NumericalWork) throws(StructuralError) -> StructuralPencil
    func flexible(_ mesh: ValidatedTetrahedralMesh, state: NodalState, fixedCoordinates: [Int], coordinateScale: Double,
                  assembler: any TetrahedralAssembling, constitutiveWork: inout ConstitutiveCallWork,
                  policy: StructuralPolicy, work: inout NumericalWork) throws(StructuralError) -> StructuralPencil
    func equilibrium(_ linearization: EquilibriumLinearization, expectedModel: ModelStamp,
                     policy: StructuralPolicy, work: inout NumericalWork) throws(StructuralError) -> StructuralPencil
}
