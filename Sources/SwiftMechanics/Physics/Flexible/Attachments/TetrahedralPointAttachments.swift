public struct TetrahedralPointAttachments: RigidMaterialAttachmentComputing {
    public init() {}

    public func materialSite(_ material: SurfaceMaterialPoint, snapshot: DeformingSurfaceSnapshot,
                             policy p: AttachmentPolicy, surfacePolicy: DeformingContactPolicy,
                             work: inout NumericalWork) throws(AttachmentError) -> AttachmentMaterialSite {
        try admitSurface(snapshot, policy: p, surfacePolicy: surfacePolicy, work: &work)
        _ = try AttachmentArithmetic.surface { () throws(DeformingContactError) in
            try TetrahedralBoundaryUpdater().point(material, in: snapshot, policy: surfacePolicy, work: &work)
        }
        try AttachmentArithmetic.check(p)
        return AttachmentMaterialSite(surface: snapshot.surface, material: material)
    }

    @inline(never)
    public func query(_ attachments: [RigidMaterialAttachment], boundaryOwner: String,
                      existingBoundaryRows: [[Double]], rigid: AttachmentRigidSource,
                      material: DeformingSurfaceSnapshot, policy p: AttachmentPolicy,
                      surfacePolicy: DeformingContactPolicy,
                      work: inout NumericalWork) throws(AttachmentError) -> RigidMaterialAttachmentQuery {
        try AttachmentArithmetic.check(p)
        guard !attachments.isEmpty, attachments.count <= p.maximumAttachments,
              existingBoundaryRows.count <= p.maximumRows else { throw .capacityExceeded }
        try AttachmentArithmetic.text(boundaryOwner, p, &work)
        let snapshot = rigid.snapshot, rigidCount = snapshot.tree.layout.velocityCount
        guard snapshot.time == material.timeSeconds else { throw .timeMismatch }
        guard snapshot.tree.worldFrame == material.state.frame else { throw .frameMismatch }
        let columnCount = try AttachmentArithmetic.sum(rigidCount, AttachmentArithmetic.product(3, material.state.positions.count))
        guard columnCount > 0, columnCount <= p.maximumScalars else { throw .capacityExceeded }
        guard p.rankColumnScales.count == columnCount,
              p.generalizedEffortTolerances.count == rigidCount else { throw .staleLayout }
        try AttachmentArithmetic.charge(rigidCount, p, &work)
        guard rigid.state.v.count == rigidCount, rigid.state.v.allSatisfy({ $0.isFinite }) else { throw .staleLayout }
        var rowCount = existingBoundaryRows.count
        for attachment in attachments {
            try AttachmentArithmetic.text(attachment.identifier, p, &work)
            try AttachmentArithmetic.text(attachment.boundaryOwner, p, &work)
            try AttachmentArithmetic.text(attachment.rigidBody.key, p, &work)
            try AttachmentArithmetic.text(attachment.rigidFrame.key, p, &work)
            guard attachment.boundaryOwner == boundaryOwner else { throw .boundaryOwnershipMismatch }
            guard attachment.site.surface === material.surface else { throw .staleSite }
            guard attachment.rigidRevision == snapshot.tree.revision else { throw .staleSource }
            rowCount = try AttachmentArithmetic.sum(rowCount, directions(attachment).count)
            guard rowCount <= p.maximumRows else { throw .capacityExceeded }
        }
        let rowScalars = try AttachmentArithmetic.product(rowCount, columnCount)
        // Retained query rows, normalization/elimination copies and operation-local supplier outputs coexist.
        let storage = try AttachmentArithmetic.sum(AttachmentArithmetic.product(4, rowScalars),
            AttachmentArithmetic.sum(AttachmentArithmetic.product(24, columnCount), AttachmentArithmetic.product(32, rowCount)))
        try AttachmentArithmetic.storage(storage, p, &work)
        for i in attachments.indices {
            for j in attachments.indices where j < i {
                try AttachmentArithmetic.charge(1, p, &work)
                guard attachments[i].identifier != attachments[j].identifier else { throw .duplicateAttachment }
            }
        }
        for row in existingBoundaryRows {
            guard row.count == columnCount else { throw .staleLayout }
            try AttachmentArithmetic.charge(columnCount, p, &work)
            guard row.allSatisfy({ $0.isFinite }) else { throw .nonFinite }
        }
        try admitSurface(material, policy: p, surfacePolicy: surfacePolicy, work: &work)
        var rows: [AttachmentConstraintRow] = []
        rows.reserveCapacity(rowCount - existingBoundaryRows.count)
        for attachment in attachments {
            try appendRows(attachment, rigid: snapshot, generalizedVelocity: rigid.state.v, material: material, policy: p,
                           surfacePolicy: surfacePolicy, rows: &rows, work: &work)
        }
        try admitRank(existingBoundaryRows, rows: rows, columns: columnCount, policy: p, work: &work)
        try AttachmentArithmetic.check(p)
        return RigidMaterialAttachmentQuery(boundaryOwner: boundaryOwner, attachments: attachments,
            rigid: rigid, material: material, rows: rows, existing: existingBoundaryRows,
            policy: p, surfacePolicy: surfacePolicy, work: work)
    }

    @inline(never)
    public func forces(_ original: RigidMaterialAttachmentQuery, multipliers: [Double],
                       currentRigid: AttachmentRigidSource, currentMaterial: DeformingSurfaceSnapshot,
                       policy p: AttachmentPolicy, surfacePolicy: DeformingContactPolicy,
                       work: inout NumericalWork) throws(AttachmentError) -> AttachmentForceProposal {
        try AttachmentArithmetic.check(p)
        guard currentRigid === original.rigidSource else { throw .staleSource }
        guard currentMaterial.surface === original.materialSnapshot.surface else { throw .staleSite }
        guard currentMaterial.geometryRevision == original.materialSnapshot.geometryRevision,
              currentMaterial.timeSeconds == original.materialSnapshot.timeSeconds else { throw .staleGeometry }
        guard currentMaterial.state.frame == original.materialSnapshot.state.frame,
              currentMaterial.state.meshRevision == original.materialSnapshot.state.meshRevision else { throw .staleLayout }
        guard multipliers.count == original.rows.count, multipliers.count <= p.maximumRows else { throw .invalidInput }
        try AttachmentArithmetic.charge(multipliers.count, p, &work)
        guard multipliers.allSatisfy({ $0.isFinite }) else { throw .nonFinite }
        // Recompute original equations and rank under this operation's policy; an earlier query is not acceptance.
        let fresh = try query(original.attachments, boundaryOwner: original.boundaryOwner,
            existingBoundaryRows: original.existingBoundaryRows, rigid: currentRigid, material: currentMaterial,
            policy: p, surfacePolicy: surfacePolicy, work: &work)
        try AttachmentArithmetic.charge(try AttachmentArithmetic.product(16, currentMaterial.state.positions.count), p, &work)
        guard currentMaterial.state.nodeIdentifiers == original.materialSnapshot.state.nodeIdentifiers,
              currentMaterial.state.positions == original.materialSnapshot.state.positions,
              currentMaterial.state.velocities == original.materialSnapshot.state.velocities else { throw .staleGeometry }
        let columnCount = try AttachmentArithmetic.sum(fresh.rigidVelocityCount, AttachmentArithmetic.product(3, currentMaterial.state.positions.count))
        let retainedRows = try AttachmentArithmetic.product(2, AttachmentArithmetic.product(fresh.rows.count, columnCount))
        let forceStorage = try AttachmentArithmetic.sum(retainedRows, AttachmentArithmetic.product(24, columnCount))
        try AttachmentArithmetic.storage(forceStorage, p, &work)
        var forces = [Vector3](repeating: .zero, count: currentMaterial.state.positions.count)
        var efforts = [Double](repeating: 0, count: fresh.rigidVelocityCount)
        var independentEfforts = [Double](repeating: 0, count: fresh.rigidVelocityCount)
        var loads: [AttachmentRigidLoad] = []; loads.reserveCapacity(fresh.attachments.count)
        var rowIndex = 0, rigidPower = 0.0, prescribedPower = 0.0, multiplierPower = 0.0
        var totalForce = Vector3.zero, totalMoment = Vector3.zero
        var maximumInterfaceForceResidual = 0.0, maximumInterfaceMomentResidual = 0.0
        var maximumInterfacePowerResidual = 0.0
        for attachment in fresh.attachments {
            var force = Vector3.zero
            var interfaceMultiplierPower = 0.0
            for direction in try directions(attachment) {
                let row = fresh.rows[rowIndex], previous = original.rows[rowIndex], multiplier = multipliers[rowIndex]
                try AttachmentArithmetic.charge(try AttachmentArithmetic.sum(columnCount, 16), p, &work)
                guard abs(row.gap) <= p.gapTolerance, abs(row.rate) <= p.rateTolerance,
                      row.attachment == previous.attachment, row.direction == previous.direction,
                      row.columns == previous.columns, row.gap == previous.gap, row.rate == previous.rate,
                      row.accelerationBias == previous.accelerationBias, row.prescribedRate == previous.prescribedRate else { throw .physicalResidual }
                force = try AttachmentArithmetic.core { () throws(CoreError) in try force.adding(direction.scaled(by: multiplier)) }
                multiplierPower = try AttachmentArithmetic.finite(multiplierPower + multiplier * row.rate)
                interfaceMultiplierPower = try AttachmentArithmetic.finite(interfaceMultiplierPower + multiplier * row.rate)
                for c in efforts.indices {
                    try AttachmentArithmetic.charge(2, p, &work)
                    efforts[c] = try AttachmentArithmetic.finite(efforts[c] + multiplier * row.columns[c])
                }
                rowIndex += 1
            }
            guard let face = currentMaterial.surface.triangles.first(where: { $0.feature == attachment.site.material.feature }) else { throw .staleSite }
            var interfaceForce = Vector3.zero, interfaceMoment = Vector3.zero, interfaceNodalPower = 0.0
            for i in 0..<3 {
                try AttachmentArithmetic.charge(96, p, &work)
                let node = face.nodes[i]
                let contribution = try AttachmentArithmetic.core { () throws(CoreError) in
                    try force.scaled(by: attachment.site.material.barycentric[i])
                }
                forces[face.nodes[i]] = try AttachmentArithmetic.core { () throws(CoreError) in
                    try forces[face.nodes[i]].adding(contribution)
                }
                interfaceForce = try AttachmentArithmetic.core { () throws(CoreError) in try interfaceForce.adding(contribution) }
                interfaceMoment = try AttachmentArithmetic.core { () throws(CoreError) in try interfaceMoment.adding(currentMaterial.state.positions[node].cross(contribution)) }
                interfaceNodalPower = try AttachmentArithmetic.finite(interfaceNodalPower + AttachmentArithmetic.core { () throws(CoreError) in try contribution.dot(currentMaterial.state.velocities[node]) })
            }
            try AttachmentArithmetic.charge(try AttachmentArithmetic.sum(256, AttachmentArithmetic.product(16, fresh.rigidVelocityCount)), p, &work)
            let body = try rigidBody(attachment.rigidBody, in: currentRigid.snapshot)
            let offset = try AttachmentArithmetic.core { () throws(CoreError) in try body.motion.pose.rotation.rotating(attachment.bodyLocalPoint) }
            let point = try AttachmentArithmetic.core { () throws(CoreError) in try body.motion.pose.translation.adding(offset) }
            let reaction = try AttachmentArithmetic.core { () throws(CoreError) in try force.scaled(by: -1) }
            let wrench = SpatialWrench(torque: try AttachmentArithmetic.core { () throws(CoreError) in try offset.cross(reaction) }, force: reaction)
            let power = try AttachmentArithmetic.core { () throws(CoreError) in try wrench.power(against: body.motion.velocity) }
            let driftPower = try AttachmentArithmetic.core { () throws(CoreError) in try wrench.power(against: body.prescribedDriftVelocity) }
            let geometric = try rigidColumns(attachment.rigidBody, in: currentRigid.snapshot)
            for c in independentEfforts.indices {
                independentEfforts[c] = try AttachmentArithmetic.finite(independentEfforts[c] + AttachmentArithmetic.core { () throws(CoreError) in try wrench.power(against: geometric[geometric.startIndex+c]) })
            }
            let interfaceForceResidual = try AttachmentArithmetic.core { () throws(CoreError) in try interfaceForce.adding(reaction).magnitude() }
            let interfaceMomentResidual = try AttachmentArithmetic.core { () throws(CoreError) in try interfaceMoment.adding(point.cross(reaction)).magnitude() }
            let interfacePower = try AttachmentArithmetic.finite(interfaceNodalPower + power)
            let interfacePowerResidual = max(abs(interfacePower-interfaceMultiplierPower), abs(interfacePower))
            guard interfaceForceResidual <= p.forceTolerance, interfaceMomentResidual <= p.momentTolerance,
                  interfacePowerResidual <= p.powerTolerance else { throw .physicalResidual }
            maximumInterfaceForceResidual = max(maximumInterfaceForceResidual, interfaceForceResidual)
            maximumInterfaceMomentResidual = max(maximumInterfaceMomentResidual, interfaceMomentResidual)
            maximumInterfacePowerResidual = max(maximumInterfacePowerResidual, interfacePowerResidual)
            rigidPower = try AttachmentArithmetic.finite(rigidPower + power)
            prescribedPower = try AttachmentArithmetic.finite(prescribedPower + driftPower)
            totalForce = try AttachmentArithmetic.core { () throws(CoreError) in try totalForce.adding(reaction) }
            totalMoment = try AttachmentArithmetic.core { () throws(CoreError) in try totalMoment.adding(point.cross(reaction)) }
            loads.append(AttachmentRigidLoad(attachment: attachment.identifier, body: attachment.rigidBody,
                bodyFrame: attachment.rigidFrame, referenceFrame: body.worldFrame, wrench: wrench,
                point: point, power: power, prescribedPower: driftPower))
        }
        var nodalPower = 0.0, generalizedPower = 0.0
        for c in efforts.indices {
            try AttachmentArithmetic.charge(2, p, &work)
            guard abs(efforts[c]-independentEfforts[c]) <= p.generalizedEffortTolerances[c] else { throw .physicalResidual }
            generalizedPower = try AttachmentArithmetic.finite(generalizedPower + efforts[c] * currentRigid.state.v[c])
        }
        for n in forces.indices {
            try AttachmentArithmetic.charge(64, p, &work)
            totalForce = try AttachmentArithmetic.core { () throws(CoreError) in try totalForce.adding(forces[n]) }
            totalMoment = try AttachmentArithmetic.core { () throws(CoreError) in try totalMoment.adding(currentMaterial.state.positions[n].cross(forces[n])) }
            nodalPower = try AttachmentArithmetic.finite(nodalPower + AttachmentArithmetic.core { () throws(CoreError) in try forces[n].dot(currentMaterial.state.velocities[n]) })
            let mapped = [forces[n].x, forces[n].y, forces[n].z]
            for axis in 0..<3 {
                var transpose = 0.0
                for r in fresh.rows.indices {
                    try AttachmentArithmetic.charge(2, p, &work)
                    transpose = try AttachmentArithmetic.finite(transpose + multipliers[r] * fresh.rows[r].columns[fresh.rigidVelocityCount + 3*n + axis])
                }
                guard abs(transpose - mapped[axis]) <= p.forceTolerance else { throw .physicalResidual }
            }
        }
        let forceResidual = max(maximumInterfaceForceResidual, try AttachmentArithmetic.core { () throws(CoreError) in try totalForce.magnitude() })
        let momentResidual = max(maximumInterfaceMomentResidual, try AttachmentArithmetic.core { () throws(CoreError) in try totalMoment.magnitude() })
        let physicalPower = try AttachmentArithmetic.finite(nodalPower + rigidPower)
        let powerResidual = max(maximumInterfacePowerResidual, max(abs(physicalPower - multiplierPower), abs(rigidPower - generalizedPower - prescribedPower)))
        guard forceResidual <= p.forceTolerance, momentResidual <= p.momentTolerance,
              powerResidual <= p.powerTolerance, abs(physicalPower) <= p.powerTolerance else { throw .physicalResidual }
        try AttachmentArithmetic.check(p)
        return AttachmentForceProposal(query: original, multipliers: multipliers, forces: forces,
            loads: loads, efforts: efforts, nodalPower: nodalPower, rigidPower: rigidPower,
            prescribedPower: prescribedPower, multiplierPower: multiplierPower,
            forceResidual: forceResidual, momentResidual: momentResidual, powerResidual: powerResidual,
            policy: p, surfacePolicy: surfacePolicy, work: work)
    }

    private func directions(_ attachment: RigidMaterialAttachment) throws(AttachmentError) -> [Vector3] {
        switch attachment.degreesOfFreedom {
        case .pointTranslation(let directions):
            guard !directions.isEmpty, directions.count <= 3 else { throw .invalidInput }
            return directions
        // FIXME(INCOMPLETE_IMPLEMENTATION): Material orientation reaches the public attachment query.
        // IM23 publishes point interpolation only. Actual material rotation, angular Jacobian and reciprocal
        // nodal couple/virtual-power evidence are required before this selected DOF can succeed.
        case .materialOrientation: throw .unsupportedOrientation
        }
    }

    private func admitSurface(_ snapshot: DeformingSurfaceSnapshot, policy p: AttachmentPolicy,
                              surfacePolicy: DeformingContactPolicy, work: inout NumericalWork) throws(AttachmentError) {
        try AttachmentArithmetic.check(p)
        let count = try AttachmentArithmetic.sum(snapshot.state.positions.count,
            AttachmentArithmetic.sum(snapshot.surface.mesh.mesh.cells.count, snapshot.surface.triangles.count))
        try AttachmentArithmetic.storage(try AttachmentArithmetic.sum(512, AttachmentArithmetic.product(32, count)), p, &work)
        try AttachmentArithmetic.text(snapshot.surface.mesh.mesh.source.source, p, &work)
        _ = try AttachmentArithmetic.surface { () throws(DeformingContactError) in
            try TetrahedralBoundaryUpdater().update(snapshot.surface, state: snapshot.state,
                geometryRevision: snapshot.geometryRevision, time: snapshot.timeSeconds,
                previous: nil, policy: surfacePolicy, work: &work)
        }
        try AttachmentArithmetic.check(p)
    }

    private func rigidBody(_ id: EntityID, in snapshot: KinematicSnapshot) throws(AttachmentError) -> BodyKinematics {
        do throws(JointError) { return try snapshot.body(id) } catch { throw .joint(error) }
    }

    private func rigidColumns(_ id: EntityID, in snapshot: KinematicSnapshot) throws(AttachmentError) -> ArraySlice<SpatialMotion> {
        do throws(JointError) { return try snapshot.geometricColumns(body: id) } catch { throw .joint(error) }
    }

    private func appendRows(_ attachment: RigidMaterialAttachment, rigid: KinematicSnapshot,
                            generalizedVelocity: [Double],
                            material: DeformingSurfaceSnapshot, policy p: AttachmentPolicy,
                            surfacePolicy: DeformingContactPolicy, rows: inout [AttachmentConstraintRow],
                            work: inout NumericalWork) throws(AttachmentError) {
        let body = try rigidBody(attachment.rigidBody, in: rigid)
        guard body.bodyFrame == attachment.rigidFrame, body.worldFrame == material.state.frame else { throw .frameMismatch }
        let calculator = KinematicJacobianCalculator()
        let jacobian: PointJacobian, motion: PointKinematics
        do {
            jacobian = try calculator.point(body: attachment.rigidBody, bodyLocalPoint: attachment.bodyLocalPoint, snapshot: rigid)
            motion = try calculator.pointMotion(body: attachment.rigidBody, bodyLocalPoint: attachment.bodyLocalPoint, snapshot: rigid)
        } catch let error as JointError { throw .joint(error) }
        catch let error as CoreError { throw .core(error) }
        catch { throw .rigidSupplierFailure }
        let rigidCount = rigid.tree.layout.velocityCount
        guard jacobian.columns.count == rigidCount, jacobian.body == attachment.rigidBody,
              jacobian.referenceFrame == material.state.frame, motion.referenceFrame == material.state.frame,
              jacobian.pointWorld == motion.position else { throw .invalidSupplierOutput }
        try AttachmentArithmetic.charge(try AttachmentArithmetic.product(128, AttachmentArithmetic.sum(rigidCount, 1)), p, &work)
        let offset = try AttachmentArithmetic.core { () throws(CoreError) in try body.motion.pose.rotation.rotating(attachment.bodyLocalPoint) }
        let originalBias = try AttachmentArithmetic.core { () throws(CoreError) in
            try body.accelerationBias.linear.adding(body.accelerationBias.angular.cross(offset))
                .adding(body.motion.velocity.angular.cross(body.motion.velocity.angular.cross(offset)))
        }
        guard try AttachmentArithmetic.core({ () throws(CoreError) in try originalBias.subtracting(motion.accelerationBias).magnitude() }) <= p.accelerationTolerance else { throw .physicalResidual }
        var generatedVelocity = jacobian.prescribedDriftVelocity
        for c in jacobian.columns.indices {
            generatedVelocity = try AttachmentArithmetic.core { () throws(CoreError) in
                try generatedVelocity.adding(jacobian.columns[c].scaled(by: generalizedVelocity[c]))
            }
        }
        guard try AttachmentArithmetic.core({ () throws(CoreError) in try generatedVelocity.subtracting(motion.velocity).magnitude() }) <= p.velocityTolerance else { throw .physicalResidual }
        let point = try AttachmentArithmetic.surface { () throws(DeformingContactError) in
            try TetrahedralBoundaryUpdater().point(attachment.site.material, in: material, policy: surfacePolicy, work: &work)
        }
        guard let face = material.surface.triangles.first(where: { $0.feature == attachment.site.material.feature }) else { throw .staleSite }
        let gap = try AttachmentArithmetic.core { () throws(CoreError) in try point.position.subtracting(motion.position) }
        let velocity = try AttachmentArithmetic.core { () throws(CoreError) in try point.velocity.subtracting(motion.velocity) }
        let columnCount = try AttachmentArithmetic.sum(rigidCount, AttachmentArithmetic.product(3, material.state.positions.count))
        for direction in try directions(attachment) {
            guard abs(try AttachmentArithmetic.core { () throws(CoreError) in try direction.magnitude() } - 1) <= p.directionTolerance else { throw .invalidInput }
            var columns = [Double](repeating: 0, count: columnCount)
            for c in jacobian.columns.indices {
                try AttachmentArithmetic.charge(8, p, &work)
                columns[c] = try AttachmentArithmetic.core { () throws(CoreError) in try -direction.dot(jacobian.columns[c]) }
            }
            for i in 0..<3 {
                let weight = attachment.site.material.barycentric[i], start = rigidCount + 3*face.nodes[i]
                columns[start] = try AttachmentArithmetic.finite(weight*direction.x)
                columns[start+1] = try AttachmentArithmetic.finite(weight*direction.y)
                columns[start+2] = try AttachmentArithmetic.finite(weight*direction.z)
            }
            let rate = try AttachmentArithmetic.core { () throws(CoreError) in try direction.dot(velocity) }
            let prescribed = try AttachmentArithmetic.core { () throws(CoreError) in try -direction.dot(motion.prescribedDriftVelocity) }
            var rowRate = prescribed
            for c in 0..<rigidCount { rowRate = try AttachmentArithmetic.finite(rowRate + columns[c]*generalizedVelocity[c]) }
            for n in material.state.velocities.indices {
                try AttachmentArithmetic.charge(8, p, &work)
                let v = material.state.velocities[n], start = rigidCount + 3*n
                rowRate = try AttachmentArithmetic.finite(rowRate + columns[start]*v.x + columns[start+1]*v.y + columns[start+2]*v.z)
            }
            guard abs(rowRate-rate) <= p.velocityTolerance else { throw .physicalResidual }
            rows.append(AttachmentConstraintRow(attachment: attachment.identifier, direction: direction,
                gap: try AttachmentArithmetic.core { () throws(CoreError) in try direction.dot(gap) }, rate: rate,
                accelerationBias: try AttachmentArithmetic.core { () throws(CoreError) in try -direction.dot(motion.accelerationBias) },
                prescribedRate: prescribed, columns: columns))
        }
    }

    private func admitRank(_ existing: [[Double]], rows: [AttachmentConstraintRow], columns: Int,
                           policy p: AttachmentPolicy, work: inout NumericalWork) throws(AttachmentError) {
        var basis: [[Double]] = []; basis.reserveCapacity(existing.count + rows.count)
        var pivots: [Int] = []; pivots.reserveCapacity(existing.count + rows.count)
        for index in 0..<(existing.count + rows.count) {
            var candidate = index < existing.count ? existing[index] : rows[index-existing.count].columns
            var scale = 0.0
            for c in 0..<columns {
                try AttachmentArithmetic.charge(2, p, &work)
                candidate[c] = try AttachmentArithmetic.finite(candidate[c]*p.rankColumnScales[c])
                scale = max(scale, abs(candidate[c]))
            }
            guard scale > 0 else { throw .rankDeficient }
            for c in 0..<columns { candidate[c] = try AttachmentArithmetic.finite(candidate[c]/scale) }
            for b in basis.indices {
                let factor = candidate[pivots[b]]
                for c in 0..<columns {
                    try AttachmentArithmetic.charge(2, p, &work)
                    candidate[c] = try AttachmentArithmetic.finite(candidate[c] - factor*basis[b][c])
                }
                candidate[pivots[b]] = 0
            }
            var pivot = 0
            for c in 0..<columns {
                try AttachmentArithmetic.charge(1, p, &work)
                if abs(candidate[c]) > abs(candidate[pivot]) { pivot = c }
            }
            guard abs(candidate[pivot]) > p.rankTolerance else { throw .overconstrained }
            let divisor = candidate[pivot]
            for c in 0..<columns {
                try AttachmentArithmetic.charge(1, p, &work)
                candidate[c] = try AttachmentArithmetic.finite(candidate[c]/divisor)
            }
            basis.append(candidate); pivots.append(pivot)
        }
    }
}
