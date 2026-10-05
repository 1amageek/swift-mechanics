internal extension MJCFModelFeatures {
    mutating func buildEqualities(table: MJCFElementTable, defaults: MJCFDefaults, section: Int?, context: MJCFImportContext,
                                  compiled: CompiledMechanicalModel, joints: [MJCFScalarJoint], losses: inout [MJCFLoss],
                                  constraints: any ConstraintEvaluating, work: inout MJCFWork, numericalWork: inout NumericalWork) throws(MJCFError) {
        guard let section else {
            guard context.equalityDomain.isEmpty else { throw .invalidInput(node: -1, field: "unused equality domain") }; return
        }
        try emptySection(table, node: section, work: &work)
        guard !table.children[section].isEmpty else {
            guard context.equalityDomain.isEmpty else { throw .invalidInput(node: section, field: "unused equality domain") }; return
        }
        let n = joints.count
        guard n > 0, context.equalityDomain.count == n else { throw .invalidInput(node: section, field: "equality domain") }
        let square = try MJCFArithmetic.product(n,n)
        try work.allocate(try MJCFArithmetic.product(n, 4 * MemoryLayout<Double>.stride + MemoryLayout<UInt64>.stride + MemoryLayout<PhysicalDimension>.stride))
        var scales = try zeros(n, work: &work), lower = scales, upper = scales, ids = [UInt64](repeating: 0,count: n), dimensions = [PhysicalDimension](repeating: .length,count: n)
        var used = Set<String>()
        for joint in joints {
            var found: MJCFCoordinateDomain?
            for domain in context.equalityDomain { try work.charge(1); if domain.jointName == joint.binding.originalName { guard found == nil else { throw .duplicate(node: -1, name: domain.jointName) }; found = domain } }
            guard let domain = found, used.insert(domain.jointName).inserted else { throw .missingField(node: section, field: joint.binding.originalName) }
            let i = joint.positionIndex; scales[i] = domain.scale; lower[i] = domain.minimum; upper[i] = domain.maximum
            ids[i] = domain.coordinateID; dimensions[i] = joint.coordinate == .translation ? .length : .angle
        }
        var rows: [QuadraticConstraint] = []
        for node in table.children[section] {
            try feature(work: &work); try leaf(table, node: node)
            let kind = table.name(node)
            // FIXME(INCOMPLETE_IMPLEMENTATION): importModel reaches non-affine and non-slide equality charts here.
            // Rotational/nonlinear/weld/connect soft constraints need their own unit and solver contracts before admission.
            guard kind == "joint" || kind == "tendon" else { throw .unsupported(node: node, feature: kind) }
            let fields = try defaults.effective(table: table, node: node, kind: "equality", activeClass: "main", work: &work)
            let first = kind + "1", second = kind + "2"
            try MJCFElementTable.check(fields, allowed: ["name","class",first,second] + (MJCFDefaults.fields(for: "equality") ?? []), node: node, work: &work)
            let name = try MJCFElementTable.required(fields, "name", node: node, work: &work)
            for e in equalities { try work.charge(1); guard e.name != name else { throw .duplicate(node: node, name: name) } }
            // FIXME(INCOMPLETE_IMPLEMENTATION): importModel reaches unsupported MJCF semantics at this gate.
            // This path must keep failing until its real provider and original behavioral evidence are available.
            if let active = try MJCFElementTable.value(fields, "active", work: &work) { guard active == "true" else { throw .unsupported(node: node, feature: "inactive equality scheduling") } }
            let p = try MJCFElementTable.numbers(fields, "polycoef", fallback: [0,1,0,0,0], count: 5, node: node, work: &work)
            // FIXME(INCOMPLETE_IMPLEMENTATION): importModel reaches unsupported MJCF semantics at this gate.
            // This path must keep failing until its real provider and original behavioral evidence are available.
            guard p[2] == 0, p[3] == 0, p[4] == 0 else { throw .unsupported(node: node, feature: "nonlinear equality") }
            let one = try MJCFElementTable.required(fields, first, node: node, work: &work), two = try MJCFElementTable.value(fields, second, work: &work)
            var gradient = try equalityGradient(kind: kind, name: one, node: node, joints: joints, work: &work)
            if let two {
                let other = try equalityGradient(kind: kind, name: two, node: node, joints: joints, work: &work)
                for i in gradient.indices { try work.charge(2); gradient[i] = try MJCFArithmetic.finite(gradient[i] - p[1] * other[i]) }
            }
            let physicalGradient = gradient
            try work.allocate(try MJCFArithmetic.product(n, MemoryLayout<Double>.stride))
            for i in gradient.indices { try work.charge(2); gradient[i] = try MJCFArithmetic.finite((gradient[i] * scales[i]) / context.equalityResidualScale) }
            let hessian = try zeros(square, work: &work), mixed = try zeros(n, work: &work)
            let id = UInt64(try MJCFArithmetic.sum(rows.count,1))
            try work.allocate(MemoryLayout<QuadraticConstraint>.stride + MemoryLayout<MJCFEqualityBinding>.stride)
            rows.append(QuadraticConstraint(id: id, constant: try MJCFArithmetic.finite(-p[0] / context.equalityResidualScale), linear: gradient, hessian: hessian, timeLinear: 0, timeQuadratic: 0, mixedTime: mixed))
            let entity = try MJCFArithmetic.id(.joint, compiled.stamp.identity + "/equality:" + name, work: &work)
            equalities.append(MJCFEqualityBinding(name: name, node: node, rowID: id, entity: entity, constantSI: -p[0], gradientSI: physicalGradient,
                                                 residualScale: context.equalityResidualScale, effectiveAttributes: fields))
            losses.append(try MJCFBodyBuilder.loss(.softEqualitySolver, node: node, field: kind,
                                                 reason: "The affine deviation equation is preserved mathematically; MuJoCo soft equality/contact solver behavior is not executed.", source: context.source, work: &work))
        }
        let layout: ConstraintCoordinateLayout, system: QuadraticConstraintSystem, policy: ConstraintEvaluationPolicy
        do {
            layout = try ConstraintCoordinateLayout(coordinateIDs: ids, dimensions: dimensions, scales: scales, timeScale: context.timeScale, revision: compiled.stamp.revision)
            system = try QuadraticConstraintSystem(layout: layout, rows: rows, minimumPosition: lower, maximumPosition: upper, minimumTime: context.minimumTime, maximumTime: context.maximumTime)
            policy = try ConstraintEvaluationPolicy(maximumCoordinates: n, maximumRows: rows.count, expectedLayoutRevision: compiled.stamp.revision, isCancelled: work.policy.isCancelled)
        } catch { throw .constraints(error) }
        let zero = try zeros(n, work: &work)
        do { initialEvaluation = try constraints.evaluate(system, position: zero, velocity: zero, time: 0, policy: policy, work: &numericalWork) } catch { throw .constraints(error) }
        self.system = system
        guard let initialEvaluation else { throw .producerRejected(node: section) }
        initialPhysicalEqualities = try MJCFOriginalEqualities.evaluate(bindings: equalities, system: system, evaluation: initialEvaluation,
                                                                       position: zero, context: context, work: &work)
    }
    private func equalityGradient(kind: String, name: String, node: Int, joints: [MJCFScalarJoint], work: inout MJCFWork) throws(MJCFError) -> [Double] {
        if kind == "joint" {
            let index = try jointIndex(name, joints: joints, node: node, work: &work), joint = joints[index]
            // FIXME(INCOMPLETE_IMPLEMENTATION): importModel reaches unsupported MJCF semantics at this gate.
            // This path must keep failing until its real provider and original behavioral evidence are available.
            guard joint.coordinate == .translation else { throw .unsupported(node: node, feature: "joint equality requires slide coordinates") }
            var result = try zeros(joints.count, work: &work); result[joint.positionIndex] = 1; return result
        }
        let index = try portIndex(name, ports: tendons, node: node, work: &work)
        // Copy is required: row normalization must not mutate the immutable transmission owner.
        try work.allocate(try MJCFArithmetic.product(joints.count, MemoryLayout<Double>.stride)); try work.charge(joints.count)
        return tendons[index].transmission.gradient
    }
}
