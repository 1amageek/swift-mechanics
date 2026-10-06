internal enum HydroelasticCellAdmission {
    private typealias A = HydroelasticArithmetic
    static func prepare(_ input: HydroelasticCellSelection,_ policy: HydroelasticPolicy,_ work: inout NumericalWork) throws(HydroelasticError) -> HydroelasticAffineCell {
        try A.check(policy)
        let body=input.representation, mesh=body.mesh.mesh, state=body.state, n=mesh.nodes.count
        guard n <= policy.maximumNodes, mesh.cells.count <= policy.maximumCells, mesh.materials.count <= policy.maximumMaterials else { throw .capacityExceeded }
        guard body.body.id.kind == .body, mesh.frame.kind == .frame else { throw .invalidInput }
        try A.bytes(body.body.id.key,policy,&work); try A.bytes(input.sample.source,policy,&work)
        guard body.body.revision == input.expectedModelRevision, mesh.revision == input.expectedMeshRevision,
              state.meshRevision == mesh.revision, try A.same(mesh.source,input.expectedMeshSource,policy,&work),
              try A.same(input.calibration.source,input.expectedCalibrationSource,policy,&work) else { throw .staleRepresentation }
        guard let field=body.field else { throw .missingPressureField }
        guard field.revision == input.expectedPressureRevision, field.meshRevision == mesh.revision,
              try A.same(field.source,mesh.source,policy,&work) else { throw .staleRepresentation }
        guard try A.same(mesh.frame,state.frame,policy,&work), try A.same(mesh.frame,field.frame,policy,&work) else { throw .frameMismatch }
        guard state.nodeIdentifiers.count == n, state.positions.count == n, state.velocities.count == n,
              field.nodeIdentifiers.count == n, field.pressurePascals.count == n,
              field.materialIdentifiers.count == mesh.materials.count else { throw .invalidLayout }
        for i in 0..<n {
            try A.check(policy); try A.charge(4,&work)
            guard state.nodeIdentifiers[i] == mesh.nodes[i].identifier, field.nodeIdentifiers[i] == mesh.nodes[i].identifier else { throw .invalidLayout }
            let pressure=field.pressurePascals[i]
            guard pressure.isFinite, pressure >= 0, pressure <= policy.maximumPressure else { throw .invalidInput }
        }
        for i in mesh.materials.indices {
            try A.check(policy)
            guard try A.same(field.materialIdentifiers[i],mesh.materials[i].identifier,policy,&work) else { throw .incompatibleMaterial }
        }
        var selected: ReferenceTetrahedron?
        for reference in body.mesh.referenceCells {
            try A.check(policy); try A.charge(1,&work)
            if reference.cell.identifier == input.cellIdentifier { selected=reference }
        }
        guard let reference=selected else { throw .missingCell(input.cellIdentifier) }
        let cell=reference.cell, material=mesh.materials[reference.materialIndex]
        guard try A.same(cell.source,input.expectedCellSource,policy,&work) else { throw .staleRepresentation }
        guard try A.same(cell.material,input.calibration.material,policy,&work),
              try A.same(material.source,input.calibration.materialSource,policy,&work) else { throw .incompatibleMaterial }
        let x0=state.positions[cell.nodes[0]]
        let a=try A.sub(state.positions[cell.nodes[1]],x0,&work)
        let b=try A.sub(state.positions[cell.nodes[2]],x0,&work)
        let c=try A.sub(state.positions[cell.nodes[3]],x0,&work)
        let edges=try A.core({ () throws(CoreError) in try Matrix3(a.x,b.x,c.x,a.y,b.y,c.y,a.z,b.z,c.z) },&work)
        let f=try A.core({ () throws(CoreError) in try edges.multiplied(by:reference.inverseEdges) },&work)
        let determinant=try A.core({ () throws(CoreError) in try f.determinant() },&work)
        guard determinant > policy.minimumVolumeRatio else { throw .invertedCell(cell.identifier) }
        let inverse=try A.core({ () throws(CoreError) in try edges.inverted(relativeTolerance:policy.inverseRelativeTolerance) },&work)
        try A.charge(3,&work)
        let p0=field.pressurePascals[cell.nodes[0]]
        let difference=try A.core({ () throws(CoreError) in try Vector3(field.pressurePascals[cell.nodes[1]]-p0,
            field.pressurePascals[cell.nodes[2]]-p0,field.pressurePascals[cell.nodes[3]]-p0) },&work)
        let gradient=try A.core({ () throws(CoreError) in try inverse.transposed().applying(to:difference) },&work)
        return HydroelasticAffineCell(selection:input,reference:reference,field:field,inverse:inverse,gradient:gradient,basePressure:p0)
    }
    static func plane(_ input: HydroelasticPlaneSelection,_ first: HydroelasticCellSelection,_ policy: HydroelasticPolicy,_ work: inout NumericalWork) throws(HydroelasticError) {
        let plane=input.representation
        guard plane.body.id.kind == .body, plane.frame.id.kind == .frame else { throw .invalidInput }
        guard plane.body.revision == input.expectedModelRevision, plane.frame.revision == input.expectedModelRevision,
              input.expectedModelRevision == first.expectedModelRevision, plane.revision == input.expectedPlaneRevision,
              try A.same(input.geometrySource,input.expectedGeometrySource,policy,&work) else { throw .staleRepresentation }
        guard try A.same(plane.frame.id,first.representation.mesh.mesh.frame,policy,&work) else { throw .frameMismatch }
        guard try !A.same(plane.body.id,first.representation.body.id,policy,&work) else { throw .invalidInput }
        guard try A.same(input.sample,first.sample,policy,&work), input.sampleTimeSeconds == first.sampleTimeSeconds else { throw .sampleMismatch }
        let magnitude=try A.norm(plane.normal,&work); try A.charge(2,&work)
        guard abs(magnitude-1) <= policy.normalTolerance else { throw .invalidInput }
    }
}
