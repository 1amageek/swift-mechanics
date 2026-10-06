public protocol ModalReducing: Sendable {
    func beam(_ assembly: BeamAssembly, fixedCoordinates: [Int], compressiveLoad: Double,
              expectedRevision: UInt64, retainedModes: [Int], maps: ModalReductionMaps,
              envelope: ModalReductionEnvelope, policy: ModalReductionPolicy,
              work: inout NumericalWork) throws(ModalReductionError) -> ModalReducedModel
    func tetrahedra(_ mesh: ValidatedTetrahedralMesh, operatingState: NodalState, fixedCoordinates: [Int],
                    coordinateScale: Double, retainedModes: [Int], maps: ModalReductionMaps,
                    envelope: ModalReductionEnvelope, policy: ModalReductionPolicy,
                    constitutiveWork: inout ConstitutiveCallWork,
                    work: inout NumericalWork) throws(ModalReductionError) -> ModalReducedModel
    func initialState(_ model: ModalReducedModel, coordinates: [Double], velocities: [Double], time: Double,
                      work: inout NumericalWork) throws(ModalReductionError) -> ModalReducedState
    func step(_ state: ModalReducedState, expectedBinding: StructuralBinding, duration: Double,
              angularFrequency: Double, inputEfforts: [Double], interfaceEfforts: [Double],
              fullReference: ModalFullReference?, linearTolerance: LinearTolerance<Double>,
              work: inout NumericalWork) throws(ModalReductionError) -> ModalReducedStep
    func beamStress(_ state: ModalReducedState, element: Int, elementCoordinate: Double, fiberDistance: Double,
                    work: inout NumericalWork) throws(ModalReductionError) -> Double
    // FIXME(INCOMPLETE_IMPLEMENTATION): The legacy public stress signature cannot charge its material
    // ledger through the public supplier contract; ReferenceModalReducer refuses until that path is qualified.
    func tetrahedralStress(_ state: ModalReducedState, cellIdentifier: UInt64,
                           constitutiveWork: inout ConstitutiveCallWork,
                           work: inout NumericalWork) throws(ModalReductionError) -> FiniteStressResponse
    func tetrahedralStress(_ state: ModalReducedState, expectedBinding: StructuralBinding,
                           location: Tet4FieldLocation, geometryRevision: UInt64, fieldPolicy: FieldOutputPolicy,
                           constitutiveWork: inout FieldConstitutiveWork,
                           work: inout NumericalWork) throws(ModalReductionError) -> ModalTet4StressOutput
}
