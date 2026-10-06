public struct TetrahedralFieldEvaluator: Tet4FieldComputing {
    public init() {}

    @inline(never)
    public func evaluate(source: Tet4FieldSource, state: NodalState, timeSeconds: Double, geometryRevision: UInt64,
                         previous: Tet4FieldSnapshot?, policy p: FieldOutputPolicy, work: inout NumericalWork,
                         constitutiveWork: inout FieldConstitutiveWork) throws(FieldOutputError) -> Tet4FieldSnapshot {
        try admit(source, state: state, policy: p, work: &work)
        guard timeSeconds.isFinite, timeSeconds >= 0 else { throw .invalidInput }
        if let previous {
            guard previous.source === source else { throw .staleSource }
            guard timeSeconds >= previous.timeSeconds, geometryRevision >= previous.geometryRevision else { throw .staleGeometry }
            try FieldOutputArithmetic.charge(try FieldOutputArithmetic.product(16, state.positions.count), p, &work)
            if previous.state.positions != state.positions || previous.state.velocities != state.velocities {
                guard geometryRevision > previous.geometryRevision else { throw .staleGeometry }
            }
        }
        let mesh = source.mesh.mesh
        var fields: [Tet4CellField] = []; fields.reserveCapacity(mesh.cells.count)
        var forces = [Vector3](repeating: .zero, count: mesh.nodes.count)
        var displacements: [Vector3] = []; displacements.reserveCapacity(mesh.nodes.count)
        var energy = 0.0, constitutivePower = 0.0
        for reference in source.mesh.referenceCells {
            let field = try cellField(reference, source: source, state: state, policy: p,
                work: &work, calls: &constitutiveWork)
            fields.append(field)
            energy = try FieldOutputArithmetic.finite(energy+field.storedEnergy)
            constitutivePower = try FieldOutputArithmetic.finite(constitutivePower+field.constitutivePower)
            for i in 0..<4 {
                try FieldOutputArithmetic.charge(3, p, &work)
                let node = field.cell.nodes[i]
                forces[node] = try FieldOutputArithmetic.core { () throws(CoreError) in try forces[node].adding(field.internalForces[i]) }
            }
        }
        var force = Vector3.zero, moment = Vector3.zero, power = 0.0
        for n in mesh.nodes.indices {
            try FieldOutputArithmetic.charge(64, p, &work)
            displacements.append(try FieldOutputArithmetic.core { () throws(CoreError) in try state.positions[n].subtracting(mesh.nodes[n].referencePosition) })
            force = try FieldOutputArithmetic.core { () throws(CoreError) in try force.adding(forces[n]) }
            moment = try FieldOutputArithmetic.core { () throws(CoreError) in try moment.adding(state.positions[n].subtracting(state.positions[0]).cross(forces[n])) }
            power = try FieldOutputArithmetic.finite(power+FieldOutputArithmetic.core { () throws(CoreError) in try forces[n].dot(state.velocities[n]) })
        }
        let fr = try FieldOutputArithmetic.core { () throws(CoreError) in try force.magnitude() }
        let mr = try FieldOutputArithmetic.core { () throws(CoreError) in try moment.magnitude() }
        let pr = abs(power-constitutivePower)
        guard fr <= p.forceTolerance, mr <= p.momentTolerance, pr <= p.powerTolerance else { throw .physicalResidual }
        try FieldOutputArithmetic.check(p)
        return Tet4FieldSnapshot(source: source, state: state, time: timeSeconds, revision: geometryRevision,
            cells: fields, displacement: displacements, forces: forces, energy: energy, power: power,
            forceResidual: fr, momentResidual: mr, powerResidual: pr, policy: p, work: work, calls: constitutiveWork)
    }

    public func sample(_ snapshot: Tet4FieldSnapshot, location: Tet4FieldLocation, measure: FieldStressMeasure,
                       projection: FieldProjection, policy p: FieldOutputPolicy,
                       work: inout NumericalWork) throws(FieldOutputError) -> Tet4FieldSample {
        try admit(snapshot.source, state: snapshot.state, policy: p, work: &work)
        try admitProjection(projection)
        guard location.meshRevision == snapshot.source.mesh.mesh.revision,
              abs(location.barycentric.reduce(0,+)-1) <= p.barycentricTolerance else { throw .invalidLocation }
        let field = try lookup(location.cell, in: snapshot, policy: p, work: &work)
        let stress = try selectedStress(field, measure: measure)
        var reference = Vector3.zero, current = Vector3.zero, velocity = Vector3.zero
        for i in 0..<4 {
            try FieldOutputArithmetic.charge(64, p, &work)
            let node = field.cell.nodes[i], weight = location.barycentric[i]
            reference = try FieldOutputArithmetic.core { () throws(CoreError) in try reference.adding(snapshot.source.mesh.mesh.nodes[node].referencePosition.scaled(by: weight)) }
            current = try FieldOutputArithmetic.core { () throws(CoreError) in try current.adding(snapshot.state.positions[node].scaled(by: weight)) }
            velocity = try FieldOutputArithmetic.core { () throws(CoreError) in try velocity.adding(snapshot.state.velocities[node].scaled(by: weight)) }
        }
        let displacement = try FieldOutputArithmetic.core { () throws(CoreError) in try current.subtracting(reference) }
        try FieldOutputArithmetic.check(p)
        return Tet4FieldSample(snapshot: snapshot, location: location, field: field, measure: measure,
            projection: projection, stress: stress, referencePosition: reference, currentPosition: current,
            displacement: displacement, velocity: velocity, policy: p, work: work)
    }

    @inline(never)
    public func average(_ snapshot: Tet4FieldSnapshot, selectedCells: [UInt64], measure: FieldStressMeasure,
                        projection: FieldProjection, averaging: FieldAveragingPolicy, policy p: FieldOutputPolicy,
                        work: inout NumericalWork) throws(FieldOutputError) -> Tet4FieldAverage {
        try admit(snapshot.source, state: snapshot.state, policy: p, work: &work)
        try admitProjection(projection)
        guard !selectedCells.isEmpty, selectedCells.count <= p.maximumLocations,
              selectedCells.count <= p.maximumCells else { throw .capacityExceeded }
        var stress = Matrix3.zero, strain = Matrix3.zero, displacement = Vector3.zero
        var density = 0.0, energy = 0.0, weight = 0.0
        var firstMaterial: EntityID?
        for i in selectedCells.indices {
            for j in 0..<i {
                try FieldOutputArithmetic.charge(1, p, &work)
                guard selectedCells[i] != selectedCells[j] else { throw .duplicateSelection }
            }
            let field = try lookup(selectedCells[i], in: snapshot, policy: p, work: &work)
            if let firstMaterial, averaging.materialMixing == .requireSameMaterial {
                guard firstMaterial == field.material.identifier else { throw .mixedMaterials }
            } else if firstMaterial == nil { firstMaterial = field.material.identifier }
            let w = averaging.weighting == .referenceVolume ? field.referenceVolume : field.currentVolume
            let selected = try selectedStress(field, measure: measure)
            let e = try FieldOutputArithmetic.material { () throws(MaterialError) in try field.response.greenStrain.matrix() }
            try FieldOutputArithmetic.charge(160, p, &work)
            stress = try FieldOutputArithmetic.core { () throws(CoreError) in try stress.adding(selected.scaled(by: w)) }
            strain = try FieldOutputArithmetic.core { () throws(CoreError) in try strain.adding(e.scaled(by: w)) }
            var centroid = Vector3.zero
            for node in field.cell.nodes {
                centroid = try FieldOutputArithmetic.core { () throws(CoreError) in try centroid.adding(snapshot.nodalDisplacements[node].scaled(by: 0.25)) }
            }
            displacement = try FieldOutputArithmetic.core { () throws(CoreError) in try displacement.adding(centroid.scaled(by: w)) }
            density = try FieldOutputArithmetic.finite(density+w*field.response.energyDensity)
            energy = try FieldOutputArithmetic.finite(energy+field.storedEnergy)
            weight = try FieldOutputArithmetic.finite(weight+w)
        }
        guard weight > 0 else { throw .invalidInput }
        stress = try FieldOutputArithmetic.core { () throws(CoreError) in try stress.scaled(by: 1/weight) }
        strain = try FieldOutputArithmetic.core { () throws(CoreError) in try strain.scaled(by: 1/weight) }
        displacement = try FieldOutputArithmetic.core { () throws(CoreError) in try displacement.scaled(by: 1/weight) }
        density = try FieldOutputArithmetic.finite(density/weight)
        try FieldOutputArithmetic.check(p)
        return Tet4FieldAverage(snapshot: snapshot, selectedCells: selectedCells, measure: measure,
            projection: projection, averaging: averaging, stress: stress, strain: strain,
            displacement: displacement, density: density, energy: energy, weight: weight, policy: p, work: work)
    }

    @inline(never)
    public func assemblyDiagnostics(_ snapshot: Tet4FieldSnapshot, massForm: FlexibleMassForm,
                                    policy p: FieldOutputPolicy, work: inout NumericalWork,
                                    constitutiveWork: inout ConstitutiveCallWork) throws(FieldOutputError) -> Tet4FieldAssemblyDiagnostics {
        try admit(snapshot.source, state: snapshot.state, policy: p, work: &work)
        let nodes = snapshot.state.positions.count, n = try FieldOutputArithmetic.product(3, nodes)
        let supplierStorage = try FieldOutputArithmetic.sum(snapshot.source.mesh.scalarStorage,
            FieldOutputArithmetic.sum(FieldOutputArithmetic.product(3, FieldOutputArithmetic.product(n,n)), FieldOutputArithmetic.product(2,n)))
        let combinedStorage = try FieldOutputArithmetic.sum(snapshotStorage(snapshot.source), supplierStorage)
        try FieldOutputArithmetic.storage(combinedStorage, p, &work)
        for field in snapshot.cells { try admitCell(field, policy: p, work: &work) }
        try FieldOutputArithmetic.check(p)
        let supplier: any TetrahedralAssembling = TotalLagrangianTetrahedra(isCancelled: p.isCancelled)
        let assembly: FlexibleAssembly
        do throws(FlexibleError) {
            assembly = try supplier.assemble(snapshot.source.mesh, state: snapshot.state, massForm: massForm,
                constitutiveWork: &constitutiveWork, work: &work)
        } catch { throw .flexible(error) }
        guard assembly.frame == snapshot.state.frame, assembly.meshRevision == snapshot.state.meshRevision,
              assembly.nodeIdentifiers == snapshot.state.nodeIdentifiers, assembly.coordinateCount == n,
              assembly.internalForce.count == n else { throw .staleLayout }
        var forceResidual = 0.0, resultant = Vector3.zero, moment = Vector3.zero
        for node in 0..<nodes {
            try FieldOutputArithmetic.charge(96, p, &work)
            let force = try FieldOutputArithmetic.core { () throws(CoreError) in
                try Vector3(assembly.internalForce[3*node],assembly.internalForce[3*node+1],assembly.internalForce[3*node+2])
            }
            let difference = try FieldOutputArithmetic.core { () throws(CoreError) in try force.subtracting(snapshot.internalForces[node]) }
            forceResidual = max(forceResidual, try FieldOutputArithmetic.core { () throws(CoreError) in try difference.magnitude() })
            resultant = try FieldOutputArithmetic.core { () throws(CoreError) in try resultant.adding(difference) }
            moment = try FieldOutputArithmetic.core { () throws(CoreError) in try moment.adding(snapshot.state.positions[node].subtracting(snapshot.momentReferencePosition).cross(difference)) }
        }
        let fr = try FieldOutputArithmetic.core { () throws(CoreError) in try resultant.magnitude() }
        let mr = try FieldOutputArithmetic.core { () throws(CoreError) in try moment.magnitude() }
        let er = abs(try FieldOutputArithmetic.finite(assembly.storedEnergy-snapshot.storedEnergy))
        guard forceResidual <= p.forceTolerance, fr <= p.forceTolerance, mr <= p.momentTolerance,
              er <= p.energyTolerance else { throw .physicalResidual }
        try FieldOutputArithmetic.check(p)
        return Tet4FieldAssemblyDiagnostics(snapshot: snapshot, assembly: assembly, force: forceResidual,
            energy: er, resultant: fr, moment: mr, policy: p, work: work)
    }

    private func snapshotStorage(_ source: Tet4FieldSource) throws(FieldOutputError) -> Int {
        try FieldOutputArithmetic.sum(source.mesh.scalarStorage,
            FieldOutputArithmetic.sum(FieldOutputArithmetic.product(160,source.mesh.mesh.cells.count),
                FieldOutputArithmetic.sum(512,FieldOutputArithmetic.product(32,source.mesh.mesh.nodes.count))))
    }

    private func admit(_ source: Tet4FieldSource, state: NodalState, policy p: FieldOutputPolicy,
                       work: inout NumericalWork) throws(FieldOutputError) {
        try FieldOutputArithmetic.check(p)
        let mesh = source.mesh.mesh
        guard mesh.nodes.count <= p.maximumNodes, mesh.cells.count <= p.maximumCells,
              mesh.materials.count <= p.maximumMaterials else { throw .capacityExceeded }
        try FieldOutputArithmetic.storage(snapshotStorage(source), p, &work)
        try FieldOutputArithmetic.text(mesh.frame.key, p, &work)
        try FieldOutputArithmetic.text(state.frame.key, p, &work)
        try FieldOutputArithmetic.text(mesh.source.source, p, &work)
        for material in mesh.materials {
            try FieldOutputArithmetic.text(material.identifier.key, p, &work)
            try FieldOutputArithmetic.text(material.source.source, p, &work)
        }
        for cell in mesh.cells {
            try FieldOutputArithmetic.text(cell.material.key, p, &work)
            try FieldOutputArithmetic.text(cell.source.source, p, &work)
        }
        guard state.frame == mesh.frame else { throw .frameMismatch }
        guard state.meshRevision == mesh.revision, state.nodeIdentifiers.count == mesh.nodes.count,
              state.positions.count == mesh.nodes.count, state.velocities.count == mesh.nodes.count,
              source.mesh.referenceCells.count == mesh.cells.count else { throw .staleLayout }
        for n in mesh.nodes.indices {
            try FieldOutputArithmetic.charge(1, p, &work)
            guard state.nodeIdentifiers[n] == mesh.nodes[n].identifier else { throw .staleLayout }
        }
    }

    private func cellField(_ reference: ReferenceTetrahedron, source: Tet4FieldSource, state: NodalState,
                           policy p: FieldOutputPolicy, work: inout NumericalWork,
                           calls: inout FieldConstitutiveWork) throws(FieldOutputError) -> Tet4CellField {
        try FieldOutputArithmetic.charge(512, p, &work)
        let cell = reference.cell, material = source.mesh.mesh.materials[reference.materialIndex]
        let origin = state.positions[cell.nodes[0]]
        let a = try FieldOutputArithmetic.core { () throws(CoreError) in try state.positions[cell.nodes[1]].subtracting(origin) }
        let b = try FieldOutputArithmetic.core { () throws(CoreError) in try state.positions[cell.nodes[2]].subtracting(origin) }
        let c = try FieldOutputArithmetic.core { () throws(CoreError) in try state.positions[cell.nodes[3]].subtracting(origin) }
        let edges = try FieldOutputArithmetic.core { () throws(CoreError) in try Matrix3(a.x,b.x,c.x,a.y,b.y,c.y,a.z,b.z,c.z) }
        let volume = try FieldOutputArithmetic.finite(FieldOutputArithmetic.core { () throws(CoreError) in try edges.determinant() } / 6)
        let f = try FieldOutputArithmetic.core { () throws(CoreError) in try edges.multiplied(by: reference.inverseEdges) }
        let j = try FieldOutputArithmetic.core { () throws(CoreError) in try f.determinant() }
        guard volume >= p.minimumCurrentVolume, j >= p.minimumVolumeRatio else { throw .invertedCell(cell.identifier) }
        guard abs(try FieldOutputArithmetic.finite(volume-reference.volume*j)) <= p.volumeTolerance else { throw .physicalResidual }
        var gradientF = Matrix3.zero, rateF = Matrix3.zero
        for i in 0..<4 {
            try FieldOutputArithmetic.charge(48, p, &work)
            let gradient = try FieldOutputArithmetic.gradient(reference, i), node = cell.nodes[i]
            let contribution = try FieldOutputArithmetic.outer(state.positions[node], gradient)
            let rate = try FieldOutputArithmetic.outer(state.velocities[node], gradient)
            gradientF = try FieldOutputArithmetic.core { () throws(CoreError) in try gradientF.adding(contribution) }
            rateF = try FieldOutputArithmetic.core { () throws(CoreError) in try rateF.adding(rate) }
        }
        guard try FieldOutputArithmetic.core({ () throws(CoreError) in try f.subtracting(gradientF).maximumMagnitude }) <= p.deformationTolerance else { throw .physicalResidual }
        try FieldOutputArithmetic.check(p)
        try calls.charge()
        let law: any HyperelasticResponding = material.law
        let response = try FieldOutputArithmetic.material { () throws(MaterialError) in try law.evaluate(deformationGradient: f) }
        try FieldOutputArithmetic.charge(512, p, &work)
        let originalStrain = try FieldOutputArithmetic.core { () throws(CoreError) in try f.transposed().multiplied(by: f).subtracting(.identity).scaled(by: 0.5) }
        let strain = try FieldOutputArithmetic.material { () throws(MaterialError) in try response.greenStrain.matrix() }
        let secondPiola = try FieldOutputArithmetic.material { () throws(MaterialError) in try response.secondPiolaStress.matrix() }
        let originalP = try FieldOutputArithmetic.core { () throws(CoreError) in try f.multiplied(by: secondPiola) }
        let originalCauchy = try FieldOutputArithmetic.core { () throws(CoreError) in try response.firstPiolaStress.multiplied(by: f.transposed()).scaled(by: 1/j) }
        guard try FieldOutputArithmetic.core({ () throws(CoreError) in try strain.subtracting(originalStrain).maximumMagnitude }) <= p.strainTolerance,
              try FieldOutputArithmetic.core({ () throws(CoreError) in try response.firstPiolaStress.subtracting(originalP).maximumMagnitude }) <= p.stressTolerance,
              try FieldOutputArithmetic.core({ () throws(CoreError) in try response.cauchyStress.subtracting(originalCauchy).maximumMagnitude }) <= p.stressTolerance else { throw .physicalResidual }
        var forces: [Vector3] = []; forces.reserveCapacity(4)
        var resultant = Vector3.zero, moment = Vector3.zero, power = 0.0
        for i in 0..<4 {
            try FieldOutputArithmetic.charge(96, p, &work)
            let gradient = try FieldOutputArithmetic.gradient(reference, i)
            let force = try FieldOutputArithmetic.core { () throws(CoreError) in try response.firstPiolaStress.applying(to: gradient).scaled(by: reference.volume) }
            forces.append(force)
            resultant = try FieldOutputArithmetic.core { () throws(CoreError) in try resultant.adding(force) }
            moment = try FieldOutputArithmetic.core { () throws(CoreError) in try moment.adding(state.positions[cell.nodes[i]].subtracting(origin).cross(force)) }
            power = try FieldOutputArithmetic.finite(power+FieldOutputArithmetic.core { () throws(CoreError) in try force.dot(state.velocities[cell.nodes[i]]) })
        }
        let constitutivePower = try FieldOutputArithmetic.finite(reference.volume*FieldOutputArithmetic.contracted(response.firstPiolaStress,rateF))
        guard try FieldOutputArithmetic.core({ () throws(CoreError) in try resultant.magnitude() }) <= p.forceTolerance,
              try FieldOutputArithmetic.core({ () throws(CoreError) in try moment.magnitude() }) <= p.momentTolerance,
              abs(power-constitutivePower) <= p.powerTolerance else { throw .physicalResidual }
        let energy = try FieldOutputArithmetic.finite(reference.volume*response.energyDensity)
        try FieldOutputArithmetic.check(p)
        return Tet4CellField(cell: cell, material: material, referenceVolume: reference.volume,
            currentVolume: volume, volumeRatio: j, deformationGradient: f, response: response,
            internalForces: forces, storedEnergy: energy, constitutivePower: constitutivePower)
    }

    private func lookup(_ identifier: UInt64, in snapshot: Tet4FieldSnapshot, policy p: FieldOutputPolicy,
                        work: inout NumericalWork) throws(FieldOutputError) -> Tet4CellField {
        try FieldOutputArithmetic.charge(snapshot.cells.count, p, &work)
        guard let field = snapshot.cells.first(where: { $0.cell.identifier == identifier }) else { throw .invalidLocation }
        try admitCell(field, policy: p, work: &work)
        return field
    }

    private func admitCell(_ field: Tet4CellField, policy p: FieldOutputPolicy,
                           work: inout NumericalWork) throws(FieldOutputError) {
        try FieldOutputArithmetic.charge(512, p, &work)
        guard field.currentVolume >= p.minimumCurrentVolume, field.volumeRatio >= p.minimumVolumeRatio else { throw .invertedCell(field.cell.identifier) }
        let f = field.deformationGradient
        let originalStrain = try FieldOutputArithmetic.core { () throws(CoreError) in try f.transposed().multiplied(by: f).subtracting(.identity).scaled(by: 0.5) }
        let strain = try FieldOutputArithmetic.material { () throws(MaterialError) in try field.response.greenStrain.matrix() }
        let s = try FieldOutputArithmetic.material { () throws(MaterialError) in try field.response.secondPiolaStress.matrix() }
        let piola = try FieldOutputArithmetic.core { () throws(CoreError) in try f.multiplied(by: s) }
        let cauchy = try FieldOutputArithmetic.core { () throws(CoreError) in try field.response.firstPiolaStress.multiplied(by: f.transposed()).scaled(by: 1/field.volumeRatio) }
        guard try FieldOutputArithmetic.core({ () throws(CoreError) in try strain.subtracting(originalStrain).maximumMagnitude }) <= p.strainTolerance,
              try FieldOutputArithmetic.core({ () throws(CoreError) in try field.response.firstPiolaStress.subtracting(piola).maximumMagnitude }) <= p.stressTolerance,
              try FieldOutputArithmetic.core({ () throws(CoreError) in try field.response.cauchyStress.subtracting(cauchy).maximumMagnitude }) <= p.stressTolerance,
              abs(try FieldOutputArithmetic.finite(field.currentVolume-field.referenceVolume*field.volumeRatio)) <= p.volumeTolerance else { throw .physicalResidual }
    }

    private func selectedStress(_ field: Tet4CellField, measure: FieldStressMeasure) throws(FieldOutputError) -> Matrix3 {
        switch measure {
        case .firstPiola: field.response.firstPiolaStress
        case .secondPiola: try FieldOutputArithmetic.material { () throws(MaterialError) in try field.response.secondPiolaStress.matrix() }
        case .cauchy: field.response.cauchyStress
        // FIXME(INCOMPLETE_IMPLEMENTATION): Logarithmic stress reaches public field sampling/averaging.
        // An explicit conjugate strain/rotation contract and original mechanical-power proof are required.
        case .logarithmic: throw .unsupportedStressMeasure
        }
    }

    private func admitProjection(_ projection: FieldProjection) throws(FieldOutputError) {
        // FIXME(INCOMPLETE_IMPLEMENTATION): Nodal smoothing reaches public field sampling/averaging.
        // Physical projection weights, material discontinuity rules and independent recovery evidence
        // are required before any nodal smoothness or recovered stress can be published.
        guard projection == .elementConstant else { throw .unsupportedProjection }
    }
}
