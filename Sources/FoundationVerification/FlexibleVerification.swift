import MechanicsCore
import MechanicsModel
import MechanicsMaterials
import MechanicsNumerics
import MechanicsFlexible

extension FoundationVerification {
    static func verifyFlexible() throws {
        let frame = try EntityID(kind: .frame, key: "flexible-world")
        let material = try FlexibleMaterial(identifier: EntityID(kind: .material, key: "flexible-material"),
            source: SourceProvenance(source: "verified polynomial material", revision: 1),
            law: PolynomialHyperelasticity(elasticity: IsotropicElasticity(bulkModulus: 1000, shearModulus: 400),
                nonlinearModulus: 800, domain: StrainDomain(maximumStrainNorm: 2, minimumVolumeRatio: 0.2)),
            referenceDensity: 6, massDampingRate: 3)
        let nodes = [FlexibleNode(identifier: 10, referencePosition: .zero, boundaryGroup: 1),
                     FlexibleNode(identifier: 11, referencePosition: .unitX, boundaryGroup: 1),
                     FlexibleNode(identifier: 12, referencePosition: .unitY, boundaryGroup: 2),
                     FlexibleNode(identifier: 13, referencePosition: .unitZ, boundaryGroup: 2)]
        let cell = try TetrahedronCell(identifier: 20, nodes: [0, 1, 2, 3], material: material.identifier,
            source: SourceProvenance(source: "physical tetrahedron", revision: 1))
        let raw = try TetrahedralMesh(frame: frame, revision: 1, source: cell.source, nodes: nodes, cells: [cell], materials: [material])
        let admission = try MeshAdmission(maximumNodes: 5, maximumCells: 4, maximumMaterials: 1,
            minimumReferenceVolume: 1e-12, inverseRelativeTolerance: 1e-12)
        var work = NumericalWork(budget: try NumericalBudget(scalarStorage: 100000, arithmeticOperations: 1000000, iterations: 0))
        var calls = try ConstitutiveCallWork(maximumCalls: 200)
        let validator: any TetrahedralMeshValidating = TetrahedralMeshValidator()
        let assembler: any TetrahedralAssembling = TotalLagrangianTetrahedra()
        let mesh = try validator.validate(raw, admission: admission, work: &work)
        let deformation = try Matrix3(1.1, 0, 0, 0, 1, 0, 0, 0, 1)
        let state = try flexibleState(mesh, deformation: deformation)
        let response = try assembler.assemble(mesh, state: state, massForm: .consistent, constitutiveWork: &calls, work: &work)
        try require(response.frame == frame && response.coordinateCount == 12 && response.constitutiveWork.calls == 13)
        try require(abs(response.storedEnergy - 1.4128016875) < 1e-9)
        try require(abs(response.internalForce[3] - 178.11871 / 6) < 1e-9 && abs(response.internalForce[7] - 77.0 / 6) < 1e-9)
        try require(abs(response.totalReferenceMass - 1) < 1e-10 && abs(response.mass[0] - 0.1) < 1e-10)
        try require(abs(response.mass[3] - 0.05) < 1e-10 && abs(response.dissipatedPower - 42) < 1e-9)
        let rotation = try UnitQuaternion(axis: .unitZ, angle: .pi / 2).matrix()
        let rotated = try assembler.assemble(mesh, state: flexibleState(mesh, deformation: rotation.multiplied(by: deformation)),
            massForm: .rowSumLumped, constitutiveWork: &calls, work: &work)
        try require(abs(rotated.storedEnergy - response.storedEnergy) < 1e-9 && abs(rotated.mass[0] - 0.25) < 1e-10)
        let originalForce = try Vector3(response.internalForce[3], response.internalForce[4], response.internalForce[5])
        let expectedForce = try rotation.applying(to: originalForce)
        try require(abs(rotated.internalForce[3] - expectedForce.x) < 1e-9 && abs(rotated.internalForce[4] - expectedForce.y) < 1e-9)
        let refined = try validator.refine(mesh, revision: 2, newNodeIdentifiers: [14], newCellIdentifiers: [21, 22, 23, 24],
            admission: admission, work: &work)
        let fine = try assembler.assemble(refined, state: flexibleState(refined, deformation: deformation),
            massForm: .consistent, constitutiveWork: &calls, work: &work)
        try require(refined.mesh.nodes.count == 5 && refined.mesh.cells.allSatisfy { $0.parentIdentifier == 20 })
        try require(refined.mesh.nodes[0] == nodes[0] && refined.mesh.nodes[4].boundaryGroup == nil)
        try require(abs(fine.storedEnergy - response.storedEnergy) < 1e-9 && abs(fine.totalReferenceMass - 1) < 1e-10)
        let foreignFrame = try EntityID(kind: .frame, key: "foreign-flexible-world")
        var frameRejected = false
        do throws(FlexibleError) {
            _ = try assembler.assemble(mesh, state: NodalState(frame: foreignFrame, meshRevision: 1,
                nodeIdentifiers: state.nodeIdentifiers, positions: state.positions, velocities: state.velocities),
                massForm: .consistent, constitutiveWork: &calls, work: &work)
        } catch {
            try require(error == .layoutMismatch)
            frameRejected = true
        }
        let inverted = try flexibleState(mesh, deformation: Matrix3(-1, 0, 0, 0, 1, 0, 0, 0, 1))
        var inversionRejected = false
        do throws(FlexibleError) {
            _ = try assembler.assemble(mesh, state: inverted, massForm: .consistent, constitutiveWork: &calls, work: &work)
        } catch {
            try require(error == .material(.outsideDomain(measure: "volumeRatio", value: -1, limit: 0.2)))
            inversionRejected = true
        }
        try require(frameRejected && inversionRejected)
    }

    private static func flexibleState(_ mesh: ValidatedTetrahedralMesh, deformation: Matrix3) throws -> NodalState {
        var positions: [Vector3] = [], velocities: [Vector3] = [], identifiers: [UInt64] = []
        for node in mesh.mesh.nodes {
            positions.append(try deformation.applying(to: node.referencePosition))
            velocities.append(try Vector3(2, -1, 3))
            identifiers.append(node.identifier)
        }
        return NodalState(frame: mesh.mesh.frame, meshRevision: mesh.mesh.revision, nodeIdentifiers: identifiers,
            positions: positions, velocities: velocities)
    }
}
