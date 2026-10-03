import MechanicsCore
import MechanicsModel
import MechanicsMaterials
import MechanicsNumerics
import MechanicsFlexible
import MechanicsContactPatches

extension FoundationVerification {
    @inline(never) static func verifyContactPatches() throws {
        let body = try patchProbeBody()
        let plane = try patchProbePlane(body.mesh.mesh.frame)
        try verifyPatchProbeIntegrals(body, plane: plane)
        try verifyPatchProbeFailures(body, plane: plane)
    }

    @inline(never) private static func patchProbeWork() throws -> NumericalWork {
        NumericalWork(budget: try NumericalBudget(scalarStorage: 100_000, arithmeticOperations: 1_000_000, iterations: 0))
    }

    @inline(never) private static func patchProbePolicy() throws(PatchError) -> PatchPolicy {
        try PatchPolicy(maximumNodes: 4, maximumCells: 1, maximumTriangles: 2, expectedModelRevision: 9, expectedMeshRevision: 1,
            expectedPressureRevision: 3, expectedPlaneRevision: 4, maximumPressure: 100, minimumDeterminant: 1e-10,
            minimumTriangleArea: 1e-12, planeDistanceTolerance: 1e-10, normalTolerance: 1e-10,
            forceScale: 1, momentScale: 1, powerScale: 1, residualTolerance: 1e-8)
    }

    @inline(never) private static func patchProbeMesh() throws -> ValidatedTetrahedralMesh {
        let material = try FlexibleMaterial(identifier: EntityID(kind: .material, key: "patch-solid"), source: SourceProvenance(source: "patch material", revision: 1),
            law: PolynomialHyperelasticity(elasticity: IsotropicElasticity(bulkModulus: 1000, shearModulus: 400), nonlinearModulus: 0,
                domain: StrainDomain(maximumStrainNorm: 2, minimumVolumeRatio: 0.2)), referenceDensity: 1, massDampingRate: 0)
        let nodes = [FlexibleNode(identifier: 10, referencePosition: .zero), FlexibleNode(identifier: 11, referencePosition: .unitX),
            FlexibleNode(identifier: 12, referencePosition: .unitY), FlexibleNode(identifier: 13, referencePosition: .unitZ)]
        let cell = try TetrahedronCell(identifier: 50, nodes: [0, 1, 2, 3], material: material.identifier, source: SourceProvenance(source: "patch cell", revision: 1))
        let raw = try TetrahedralMesh(frame: EntityID(kind: .frame, key: "patch-world"), revision: 1, source: SourceProvenance(source: "patch tetrahedron", revision: 1),
            nodes: nodes, cells: [cell], materials: [material])
        let admission = try MeshAdmission(maximumNodes: 4, maximumCells: 1, maximumMaterials: 1, minimumReferenceVolume: 1e-12, inverseRelativeTolerance: 1e-12)
        let validator: any TetrahedralMeshValidating = TetrahedralMeshValidator()
        var supplierWork = try patchProbeWork()
        return try validator.validate(raw, admission: admission, work: &supplierWork)
    }

    @inline(never) private static func patchProbeBody() throws -> PressureBody {
        let mesh = try patchProbeMesh()
        let state = try NodalState(frame: mesh.mesh.frame, meshRevision: 1, nodeIdentifiers: [10, 11, 12, 13], positions: [.zero, .unitX, .unitY, .unitZ],
            velocities: [Vector3(0, 0, 1), Vector3(0, 0, 2), Vector3(0, 0, 3), Vector3(0, 0, 4)])
        let field = NodalPressureField(frame: mesh.mesh.frame, meshRevision: 1, revision: 3, nodeIdentifiers: state.nodeIdentifiers,
            materialIdentifiers: [mesh.mesh.materials[0].identifier], pressurePascals: [2, 5, 6, 7], source: mesh.mesh.source)
        return PressureBody(body: ModelReference(id: try EntityID(kind: .body, key: "patch-compliant"), revision: 9), mesh: mesh, state: state, field: field)
    }

    @inline(never) private static func patchProbePlane(_ frame: EntityID) throws -> RigidPressurePlane {
        RigidPressurePlane(body: ModelReference(id: try EntityID(kind: .body, key: "patch-rigid"), revision: 9), frame: ModelReference(id: frame, revision: 9), revision: 4,
            point: try Vector3(0, 0, 0.2), normal: .unitZ, velocityAboutPoint: SpatialMotion(angular: .unitX, linear: try Vector3(0, 0, 0.5)))
    }

    @inline(never) private static func verifyPatchProbeIntegrals(_ body: PressureBody, plane: RigidPressurePlane) throws {
        let service: any PressurePatchIntegrating = TetrahedralPressurePatchIntegrator()
        var work = try patchProbeWork(), workspace = PatchWorkspace()
        let result = try service.integrate(body, against: .rigidPlane(plane), origin: .zero, policy: patchProbePolicy(), workspace: &workspace, work: &work)
        // z=.2, x+y<=.8, supplied p=3+3*x+4*y. These monomial integrals are independent of patch quadrature.
        let l = 0.8, area = l*l/2, pressure = 3*area + 7*l*l*l/6
        let xp = 3*l*l*l/6 + 3*l*l*l*l/12 + 4*l*l*l*l/24
        let yp = 3*l*l*l/6 + 3*l*l*l*l/24 + 4*l*l*l*l/12
        try require(result.triangles.count == 1 && abs(result.area - area) < 1e-10 && abs(result.integratedPressure - pressure) < 1e-10)
        try require(abs(result.wrenchOnRigid.force.z - pressure) < 1e-10 && abs(result.wrenchOnCompliant.force.z + pressure) < 1e-10)
        try require(abs(result.wrenchOnRigid.torque.x - yp) < 1e-10 && abs(result.wrenchOnRigid.torque.y + xp) < 1e-10)
        try require(abs(result.nodalForces[0].z + l*pressure - xp - yp) < 1e-10)
        try require(abs(result.nodalForces[1].z + xp) < 1e-10 && abs(result.nodalForces[2].z + yp) < 1e-10 && abs(result.nodalForces[3].z + 0.2*pressure) < 1e-10)
        try require(abs(result.compliantPower + 1.6*pressure + xp + 2*yp) < 1e-10 && abs(result.rigidPower - 0.5*pressure - yp) < 1e-10)
        try require(result.originalForceResidual < 1e-8 && result.originalMomentResidual < 1e-8 && result.originalPowerResidual < 1e-8)
        try require(result.meshRevision == 1 && result.pressureRevision == 3 && result.planeRevision == 4)
    }

    @inline(never) private static func verifyPatchProbeFailures(_ body: PressureBody, plane: RigidPressurePlane) throws {
        guard let field = body.field else { throw FoundationVerificationError.analyticCheckFailed }
        let service: any PressurePatchIntegrating = TetrahedralPressurePatchIntegrator()
        for missing in [true, false] {
            let stale = NodalPressureField(frame: field.frame, meshRevision: field.meshRevision, revision: 99, nodeIdentifiers: field.nodeIdentifiers,
                materialIdentifiers: field.materialIdentifiers, pressurePascals: field.pressurePascals, source: field.source)
            let invalid = PressureBody(body: body.body, mesh: body.mesh, state: body.state, field: missing ? nil : stale)
            var work = try patchProbeWork(), workspace = PatchWorkspace(), rejected = false
            do throws(PatchError) {
                _ = try service.integrate(invalid, against: .rigidPlane(plane), origin: .zero, policy: patchProbePolicy(), workspace: &workspace, work: &work)
            } catch {
                switch error {
                case .missingPressureField: try require(missing); rejected = true
                case .staleRepresentation: try require(!missing); rejected = true
                default: throw FoundationVerificationError.unexpectedFailure
                }
            }
            try require(rejected)
        }
    }
}
