internal struct MJCFModelFeatures {
    var tendons: [MJCFAffinePort] = [], motors: [MJCFAffinePort] = []
    var materials: [MJCFMaterial] = [], sensors: [MJCFSensor] = [], equalities: [MJCFEqualityBinding] = []
    var system: QuadraticConstraintSystem?, initialEvaluation: ConstraintEvaluation?
    var initialPhysicalEqualities: [MJCFEqualitySample] = []
    private var featureCount = 0
    mutating func build(table: MJCFElementTable, defaults: MJCFDefaults, sections: [String:Int], context: MJCFImportContext,
                        compiled: CompiledMechanicalModel, joints: [MJCFScalarJoint], losses: inout [MJCFLoss], constraints: any ConstraintEvaluating,
                        work: inout MJCFWork, actuationWork: inout ActuationWork, numericalWork: inout NumericalWork) throws(MJCFError) {
        if let asset = sections["asset"] {
            try emptySection(table, node: asset, work: &work)
            for node in table.children[asset] {
                try feature(work: &work)
                let kind = table.name(node)
                if kind == "material" {
                    let fields = try defaults.effective(table: table, node: node, kind: "material", activeClass: "main", work: &work)
                    try MJCFElementTable.check(fields, allowed: ["name","class"] + (MJCFDefaults.fields(for: "material") ?? []), node: node, work: &work)
                    try leaf(table, node: node)
                    let name = try MJCFElementTable.required(fields, "name", node: node, work: &work)
                    for m in materials { try work.charge(1); guard m.name != name else { throw .duplicate(node: node, name: name) } }
                    guard try MJCFElementTable.value(fields, "texture", work: &work) == nil,
                          try MJCFElementTable.value(fields, "texrepeat", work: &work) == nil,
                          // FIXME(INCOMPLETE_IMPLEMENTATION): importModel reaches unsupported MJCF semantics at this gate.
                          // This path must keep failing until its real provider and original behavioral evidence are available.
                          try MJCFElementTable.value(fields, "texuniform", work: &work) == nil else { throw .unsupported(node: node, feature: "textured material") }
                    let rgba = try MJCFElementTable.numbers(fields, "rgba", fallback: [1,1,1,1], count: 4, node: node, work: &work)
                    for v in rgba { try work.charge(1); guard v >= 0, v <= 1 else { throw .invalidInput(node: node, field: "rgba") } }
                    for name in ["emission","specular","shininess","reflectance"] {
                        let v = try MJCFElementTable.numbers(fields, name, fallback: [0], count: 1, node: node, work: &work)[0]
                        guard v >= 0, v <= 1 else { throw .invalidInput(node: node, field: name) }
                    }
                    losses.append(try MJCFBodyBuilder.loss(.retainedRendering, node: node, field: "material", reason: "Material values are retained visual descriptions; rendering is not executed.", source: context.source, work: &work))
                    let entity = try MJCFArithmetic.id(.material, context.identity + "/material:" + name, work: &work)
                    try work.allocate(MemoryLayout<MJCFMaterial>.stride); materials.append(MJCFMaterial(name: name, node: node, entity: entity, attributes: fields))
                } else {
                    // FIXME(INCOMPLETE_IMPLEMENTATION): importModel reaches unsupported MJCF semantics at this gate.
                    // This path must keep failing until its real provider and original behavioral evidence are available.
                    guard ["mesh","texture","hfield","skin"].contains(kind) else { throw .unsupported(node: node, feature: kind) }
                    losses.append(try MJCFBodyBuilder.loss(.retainedAsset, node: node, field: kind, reason: "Original asset declarations are retained only; no files are downloaded or geometry inferred.", source: context.source, work: &work))
                }
            }
        }
        if let section = sections["tendon"] {
            try emptySection(table, node: section, work: &work)
            for node in table.children[section] {
                try feature(work: &work)
                // FIXME(INCOMPLETE_IMPLEMENTATION): importModel reaches spatial tendon routing here.
                // A geometry-owned route and its original derivative/power evidence are needed before admission.
                guard table.name(node) == "fixed" else { throw .unsupported(node: node, feature: table.name(node)) }
                let fields = try defaults.effective(table: table, node: node, kind: "tendon", activeClass: "main", work: &work)
                try MJCFElementTable.check(fields, allowed: ["name","class"] + (MJCFDefaults.fields(for: "tendon") ?? []), node: node, work: &work)
                let name = try MJCFElementTable.required(fields, "name", node: node, work: &work)
                for t in tendons { try work.charge(1); guard t.name != name else { throw .duplicate(node: node, name: name) } }
                try MJCFBodyBuilder.unlimited(fields, node: node, work: &work)
                try MJCFBodyBuilder.passiveZero(fields, names: ["stiffness","damping","frictionloss"], node: node, work: &work)
                // FIXME(INCOMPLETE_IMPLEMENTATION): importModel reaches unsupported MJCF semantics at this gate.
                // This path must keep failing until its real provider and original behavioral evidence are available.
                guard try MJCFElementTable.value(fields, "springlength", work: &work) == nil else { throw .unsupported(node: node, feature: "springlength") }
                for visual in ["width","rgba","material"] where try MJCFElementTable.value(fields, visual, work: &work) != nil {
                    losses.append(try MJCFBodyBuilder.loss(.retainedRendering, node: node, field: visual, reason: "Tendon rendering parameters are retained only.", source: context.source, work: &work))
                }
                var gradient = try zeros(joints.count, work: &work), offset = 0.0, seen = Set<Int>()
                for child in table.children[node] {
                    // FIXME(INCOMPLETE_IMPLEMENTATION): importModel reaches unsupported MJCF semantics at this gate.
                    // This path must keep failing until its real provider and original behavioral evidence are available.
                    try feature(work: &work); guard table.name(child) == "joint" else { throw .unsupported(node: child, feature: table.name(child)) }; try leaf(table, node: child)
                    let f = try table.fields(child, work: &work)
                    try MJCFElementTable.check(f, allowed: ["joint","coef"], node: child, work: &work)
                    let target = try MJCFElementTable.required(f, "joint", node: child, work: &work)
                    let index = try jointIndex(target, joints: joints, node: child, work: &work), joint = joints[index]
                    // FIXME(INCOMPLETE_IMPLEMENTATION): importModel reaches unsupported MJCF semantics at this gate.
                    // This path must keep failing until its real provider and original behavioral evidence are available.
                    guard joint.coordinate == .translation, seen.insert(index).inserted else { throw .unsupported(node: child, feature: "fixed tendon requires distinct slide coordinates") }
                    let c = try MJCFElementTable.numbers(f, "coef", fallback: nil, count: 1, node: child, work: &work)[0]
                    // FIXME(INCOMPLETE_IMPLEMENTATION): importModel omits zero-gradient tendon contributors.
                    // Zero contributors require an explicit retained inactive-port contract before admission.
                    guard c != 0 else { throw .unsupported(node: child, feature: "zero tendon coefficient") }
                    try work.charge(3); gradient[joint.velocityIndex] = c; offset = try MJCFArithmetic.finite(offset + c * joint.reference)
                }
                tendons.append(try port(name: name, node: node, motor: false, offset: offset, gradient: gradient, output: .translation, fields: fields,
                                        compiled: compiled, joints: joints, work: &work, actuationWork: &actuationWork))
            }
        }
        if let section = sections["actuator"] {
            try emptySection(table, node: section, work: &work)
            for node in table.children[section] {
                try feature(work: &work)
                // FIXME(INCOMPLETE_IMPLEMENTATION): importModel admits direct motors only.
                // Stateful/general/servo actuator laws require actual law providers before successful conversion.
                guard table.name(node) == "motor" else { throw .unsupported(node: node, feature: table.name(node)) }; try leaf(table, node: node)
                let fields = try defaults.effective(table: table, node: node, kind: "motor", activeClass: "main", work: &work)
                try MJCFElementTable.check(fields, allowed: ["name","class","joint","tendon"] + (MJCFDefaults.fields(for: "motor") ?? []), node: node, work: &work)
                let name = try MJCFElementTable.required(fields, "name", node: node, work: &work)
                for m in motors { try work.charge(1); guard m.name != name else { throw .duplicate(node: node, name: name) } }
                for field in ["ctrllimited","forcelimited"] {
                    // FIXME(INCOMPLETE_IMPLEMENTATION): importModel reaches unsupported MJCF semantics at this gate.
                    // This path must keep failing until its real provider and original behavioral evidence are available.
                    if let value = try MJCFElementTable.value(fields, field, work: &work) { guard value == "false" || value == "auto" else { throw .unsupported(node: node, feature: field) } }
                }
                guard try MJCFElementTable.value(fields, "ctrlrange", work: &work) == nil,
                      // FIXME(INCOMPLETE_IMPLEMENTATION): importModel reaches unsupported MJCF semantics at this gate.
                      // This path must keep failing until its real provider and original behavioral evidence are available.
                      try MJCFElementTable.value(fields, "forcerange", work: &work) == nil else { throw .unsupported(node: node, feature: "motor clamping") }
                let values = try MJCFArithmetic.numbers(MJCFElementTable.value(fields, "gear", work: &work) ?? "1", maximum: 6, node: node, work: &work)
                guard values.count == 1 || values.count == 6 else { throw .invalidInput(node: node, field: "gear") }
                // FIXME(INCOMPLETE_IMPLEMENTATION): importModel reaches unsupported MJCF semantics at this gate.
                // This path must keep failing until its real provider and original behavioral evidence are available.
                for i in 1..<values.count { try work.charge(1); guard values[i] == 0 else { throw .unsupported(node: node, feature: "non-scalar gear") } }
                let g = values[0], jointName = try MJCFElementTable.value(fields, "joint", work: &work), tendonName = try MJCFElementTable.value(fields, "tendon", work: &work)
                guard (jointName != nil) != (tendonName != nil) else { throw .invalidInput(node: node, field: "motor target") }
                var gradient = try zeros(joints.count, work: &work), offset = 0.0, output = ScalarCoordinateKind.translation
                if let jointName {
                    let index = try jointIndex(jointName, joints: joints, node: node, work: &work), joint = joints[index]
                    gradient[joint.velocityIndex] = g; offset = try MJCFArithmetic.finite(g * joint.reference); output = joint.coordinate
                } else if let tendonName {
                    let index = try portIndex(tendonName, ports: tendons, node: node, work: &work), tendon = tendons[index]
                    for i in gradient.indices { try work.charge(1); gradient[i] = try MJCFArithmetic.finite(g * tendon.transmission.gradient[i]) }
                    offset = try MJCFArithmetic.finite(g * tendon.referenceOffset)
                }
                motors.append(try port(name: name, node: node, motor: true, offset: offset, gradient: gradient, output: output, fields: fields,
                                       compiled: compiled, joints: joints, work: &work, actuationWork: &actuationWork))
            }
        }
        try buildEqualities(table: table, defaults: defaults, section: sections["equality"], context: context, compiled: compiled, joints: joints,
                            losses: &losses, constraints: constraints, work: &work, numericalWork: &numericalWork)
        if let section = sections["sensor"] {
            try emptySection(table, node: section, work: &work)
            for node in table.children[section] {
                try feature(work: &work); try leaf(table, node: node)
                let fields = try table.fields(node, work: &work), type = table.name(node)
                try MJCFElementTable.check(fields, allowed: ["name","joint","tendon","actuator","noise","cutoff"], node: node, work: &work)
                try MJCFBodyBuilder.passiveZero(fields, names: ["noise","cutoff"], node: node, work: &work)
                let name = try MJCFElementTable.required(fields, "name", node: node, work: &work)
                for s in sensors { try work.charge(1); guard s.name != name else { throw .duplicate(node: node, name: name) } }
                let kind: MJCFSensorKind, index: Int, target: String
                switch type {
                case "jointpos","jointvel":
                    kind = type == "jointpos" ? .jointPosition : .jointVelocity; target = "joint"
                    index = try jointIndex(MJCFElementTable.required(fields, target, node: node, work: &work), joints: joints, node: node, work: &work)
                case "tendonpos","tendonvel":
                    kind = type == "tendonpos" ? .tendonPosition : .tendonVelocity; target = "tendon"
                    index = try portIndex(MJCFElementTable.required(fields, target, node: node, work: &work), ports: tendons, node: node, work: &work)
                case "actuatorpos","actuatorvel":
                    kind = type == "actuatorpos" ? .actuatorPosition : .actuatorVelocity; target = "actuator"
                    index = try portIndex(MJCFElementTable.required(fields, target, node: node, work: &work), ports: motors, node: node, work: &work)
                // FIXME(INCOMPLETE_IMPLEMENTATION): importModel reaches unsupported MJCF semantics at this gate.
                // This path must keep failing until its real provider and original behavioral evidence are available.
                default: throw .unsupported(node: node, feature: type)
                }
                for other in ["joint","tendon","actuator"] where other != target { guard try MJCFElementTable.value(fields, other, work: &work) == nil else { throw .invalidInput(node: node, field: other) } }
                let entity = try MJCFArithmetic.id(.sensor, context.identity + "/sensor:" + name, work: &work)
                try work.allocate(MemoryLayout<MJCFSensor>.stride); sensors.append(MJCFSensor(name: name, node: node, entity: entity, kind: kind, targetIndex: index))
            }
        }
    }
    mutating func feature(work: inout MJCFWork) throws(MJCFError) {
        try work.charge(1); featureCount = try MJCFArithmetic.sum(featureCount, 1)
        guard featureCount <= work.policy.maximumFeatures else { throw .capacityExceeded }
    }
    func emptySection(_ table: MJCFElementTable, node: Int, work: inout MJCFWork) throws(MJCFError) {
        try MJCFElementTable.check(table.fields(node, work: &work), allowed: [], node: node, work: &work)
    }
    // FIXME(INCOMPLETE_IMPLEMENTATION): importModel reaches unsupported MJCF semantics at this gate.
    // This path must keep failing until its real provider and original behavioral evidence are available.
    func leaf(_ table: MJCFElementTable, node: Int) throws(MJCFError) { guard table.children[node].isEmpty else { throw .unsupported(node: node, feature: "child elements") } }
    func zeros(_ count: Int, work: inout MJCFWork) throws(MJCFError) -> [Double] {
        try work.charge(count); try work.allocate(try MJCFArithmetic.product(count, MemoryLayout<Double>.stride)); return [Double](repeating: 0,count: count)
    }
    func jointIndex(_ name: String, joints: [MJCFScalarJoint], node: Int, work: inout MJCFWork) throws(MJCFError) -> Int {
        for i in joints.indices { try work.charge(1); if joints[i].binding.originalName == name { return i } }; throw .danglingReference(node: node, name: name)
    }
    func portIndex(_ name: String, ports: [MJCFAffinePort], node: Int, work: inout MJCFWork) throws(MJCFError) -> Int {
        for i in ports.indices { try work.charge(1); if ports[i].name == name { return i } }; throw .danglingReference(node: node, name: name)
    }
    func port(name: String, node: Int, motor: Bool, offset: Double, gradient: [Double], output: ScalarCoordinateKind, fields: [MJCFEffectiveAttribute],
              compiled: CompiledMechanicalModel, joints: [MJCFScalarJoint], work: inout MJCFWork, actuationWork: inout ActuationWork) throws(MJCFError) -> MJCFAffinePort {
        try work.allocate(try MJCFArithmetic.product(joints.count, MemoryLayout<ScalarCoordinateKind>.stride))
        var kinds = [ScalarCoordinateKind](repeating: .translation, count: joints.count)
        for joint in joints { try work.charge(1); kinds[joint.velocityIndex] = joint.coordinate }
        let transmission: AffineTransmission
        do { transmission = try AffineTransmission(model: compiled.stamp, frame: compiled.descriptor.worldFrame, outputCoordinate: output,
                                                   inputCoordinates: kinds, gradient: gradient, prescribedRate: 0, work: &actuationWork) } catch { throw .actuation(error) }
        try work.allocate(MemoryLayout<MJCFAffinePort>.stride)
        let entity = try MJCFArithmetic.id(motor ? .actuator : .load, compiled.stamp.identity + (motor ? "/actuator:" : "/tendon:") + name, work: &work)
        return MJCFAffinePort(name: name, node: node, entity: entity, referenceOffset: offset, transmission: transmission, effectiveAttributes: fields)
    }
}
