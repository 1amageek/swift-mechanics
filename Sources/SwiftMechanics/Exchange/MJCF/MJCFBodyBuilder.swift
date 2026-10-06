internal struct MJCFBodyBuilder {
    let defaults: MJCFDefaults
    let sections: [String: Int]
    let gravity: AffineGravity
    private let angleScale: Double
    var losses: [MJCFLoss]
    private(set) var bindings: [MJCFEntityBinding] = []
    private var scalarBindings: [(MJCFEntityBinding, ScalarCoordinateKind, Double)] = []
    init(table: MJCFElementTable, context: MJCFImportContext, work: inout MJCFWork) throws(MJCFError) {
        try work.text(context.identity); try work.text(context.source.source)
        let root = table.document.rootIndex
        guard table.name(root) == "mujoco" else { throw .invalidInput(node: root, field: "mujoco") }
        try MJCFElementTable.check(table.fields(root, work: &work), allowed: ["model"], node: root, work: &work)
        var sections: [String: Int] = [:]
        for node in table.children[root] {
            try work.charge(1); let name = table.name(node)
            // FIXME(INCOMPLETE_IMPLEMENTATION): importModel supports only selected tree/affine MJCF semantics.
            // Includes, keyframes, plugins, contact, custom data and other sections need real providers before success.
            guard ["compiler","option","worldbody","default","asset","tendon","actuator","equality","sensor"].contains(name) else { throw .unsupported(node: node, feature: name) }
            guard sections[name] == nil else { throw .duplicate(node: node, name: name) }
            try work.allocate(MemoryLayout<(String,Int)>.stride); sections[name] = node
        }
        guard sections["worldbody"] != nil else { throw .missingField(node: root, field: "worldbody") }
        var scale = Double.pi / 180
        if let node = sections["compiler"] {
            // FIXME(INCOMPLETE_IMPLEMENTATION): importModel reaches unsupported MJCF semantics at this gate.
            // This path must keep failing until its real provider and original behavioral evidence are available.
            guard table.children[node].isEmpty else { throw .unsupported(node: node, feature: "compiler children") }
            let fields = try table.fields(node, work: &work)
            try MJCFElementTable.check(fields, allowed: ["angle","inertiafromgeom","autolimits","fusestatic"], node: node, work: &work)
            if let angle = try MJCFElementTable.value(fields, "angle", work: &work) {
                guard angle == "degree" || angle == "radian" else { throw .invalidInput(node: node, field: "angle") }; scale = angle == "degree" ? Double.pi / 180 : 1
            }
            if let inertia = try MJCFElementTable.value(fields, "inertiafromgeom", work: &work) {
                // FIXME(INCOMPLETE_IMPLEMENTATION): importModel reaches unsupported MJCF semantics at this gate.
                // This path must keep failing until its real provider and original behavioral evidence are available.
                guard inertia == "auto" || inertia == "false" else { throw .unsupported(node: node, feature: "inertia inference") }
            }
            // FIXME(INCOMPLETE_IMPLEMENTATION): importModel reaches unsupported MJCF semantics at this gate.
            // This path must keep failing until its real provider and original behavioral evidence are available.
            if let fuse = try MJCFElementTable.value(fields, "fusestatic", work: &work) { guard fuse == "false" else { throw .unsupported(node: node, feature: "static fusion") } }
            if let limits = try MJCFElementTable.value(fields, "autolimits", work: &work) { guard limits == "true" || limits == "false" else { throw .invalidInput(node: node, field: "autolimits") } }
        }
        angleScale = scale; self.sections = sections
        defaults = try MJCFDefaults(table: table, root: sections["default"], work: &work)
        losses = [try Self.loss(.mujocoSolverExecution, node: root, field: "engine",
                               reason: "MuJoCo solver, integration and control execution are not invoked by this structural adapter.", source: context.source, work: &work)]
        var g: [Double] = [0,0,-9.81]
        if let node = sections["option"] {
            // FIXME(INCOMPLETE_IMPLEMENTATION): importModel reaches unsupported MJCF semantics at this gate.
            // This path must keep failing until its real provider and original behavioral evidence are available.
            guard table.children[node].isEmpty else { throw .unsupported(node: node, feature: "option flags") }
            let fields = try table.fields(node, work: &work)
            try MJCFElementTable.check(fields, allowed: ["gravity","timestep","integrator","solver","iterations","tolerance","ls_iterations","ls_tolerance","cone","jacobian","impratio","noslip_iterations","noslip_tolerance"], node: node, work: &work)
            g = try MJCFElementTable.numbers(fields, "gravity", fallback: g, count: 3, node: node, work: &work)
            for field in fields where field.name != "gravity" {
                losses.append(try Self.loss(.mujocoSolverExecution, node: field.definingNode, field: field.name,
                                           reason: "Original engine option is retained in XML and not executed.", source: context.source, work: &work))
            }
        }
        let frame = try MJCFArithmetic.id(.frame, context.identity + "/world", work: &work)
        do { gravity = try AffineGravity(frame: frame, accelerationAtOrigin: MJCFArithmetic.core { () throws(CoreError) in try Vector3(g[0],g[1],g[2]) }) }
        catch let error as MJCFError { throw error }
        catch let error as LoadError { throw .load(error) }
        catch { throw .producerRejected(node: root) }
    }
    static func loss(_ category: MJCFLossCategory, node: Int, field: String, reason: String,
                     source: SourceProvenance, work: inout MJCFWork) throws(MJCFError) -> MJCFLoss {
        try work.charge(1)
        guard work.policy.allowedLosses.contains(category) else { throw .lossNotSelected(node: node, category: category) }
        try work.allocate(MemoryLayout<MJCFLoss>.stride); try work.text(field); try work.text(reason)
        return MJCFLoss(category: category, node: node, field: field, reason: reason, source: source)
    }
    mutating func descriptor(table: MJCFElementTable, context: MJCFImportContext, work: inout MJCFWork) throws(MJCFError) -> MechanicalDescriptor {
        guard let worldNode = sections["worldbody"] else { throw .missingField(node: table.document.rootIndex, field: "worldbody") }
        try MJCFElementTable.check(table.fields(worldNode, work: &work), allowed: [], node: worldNode, work: &work)
        let world = try MJCFArithmetic.id(.body, context.identity + "/worldbody", work: &work)
        let worldBodyFrame = try MJCFArithmetic.id(.frame, context.identity + "/frame:worldbody", work: &work)
        let empty: BodyRepresentations
        do { empty = try BodyRepresentations() } catch { throw .model(error) }
        let worldBody: BodyRecord3D
        do { worldBody = try BodyRecord3D(id: world, frame: worldBodyFrame, mode: .static, bodyToWorld: .identity, representations: empty, inertia: nil) } catch { throw .model(error) }
        var bodies: [MechanicalBody] = [.spatial(worldBody)], joints: [MechanicalJoint] = []
        try work.allocate(MemoryLayout<MechanicalBody>.stride + MemoryLayout<(Int,EntityID,RigidTransform,Bool,String)>.stride)
        var queue: [(Int,EntityID,RigidTransform,Bool,String)] = [(worldNode,world,.identity,false,"main")], cursor = 0
        var names = Set<String>(), jointNames = Set<String>(), usedGeometry = Set<String>()
        for i in context.geometry.indices {
            try work.charge(1)
            for j in 0..<i { try work.charge(1); guard context.geometry[i].bodyName != context.geometry[j].bodyName else { throw .duplicate(node: -1, name: context.geometry[i].bodyName) } }
        }
        while cursor < queue.count {
            try work.charge(1)
            let (parentNode,parent,parentPose,parentMoves,activeClass) = queue[cursor]; cursor += 1
            for node in table.children[parentNode] {
                try work.charge(1)
                if table.name(node) == "geom" {
                    losses.append(try Self.loss(.retainedGeometryAndContact, node: node, field: "geom",
                                               reason: "Original geom/contact parameters are retained only; physical geometry comes from the caller's CAD owner.", source: context.source, work: &work)); continue
                }
                guard table.name(node) == "body" else {
                    if parentNode != worldNode, table.name(node) == "joint" || table.name(node) == "inertial" { continue }
                    // FIXME(INCOMPLETE_IMPLEMENTATION): importModel reaches unsupported MJCF semantics at this gate.
                    // This path must keep failing until its real provider and original behavioral evidence are available.
                    throw .unsupported(node: node, feature: table.name(node))
                }
                guard bodies.count < work.policy.maximumBodies else { throw .capacityExceeded }
                let fields = try table.fields(node, work: &work)
                try MJCFElementTable.check(fields, allowed: ["name","pos","quat","childclass"], node: node, work: &work)
                let name = try MJCFElementTable.required(fields, "name", node: node, work: &work)
                guard names.insert(name).inserted else { throw .duplicate(node: node, name: name) }
                try work.allocate(4 * MemoryLayout<String>.stride)
                let childClass = try MJCFElementTable.value(fields, "childclass", work: &work) ?? activeClass
                guard defaults.contains(childClass) else { throw .danglingReference(node: node, name: childClass) }
                let id = try MJCFArithmetic.id(.body, context.identity + "/body:" + name, work: &work)
                let frame = try MJCFArithmetic.id(.frame, context.identity + "/frame:body:" + name, work: &work)
                let local = try table.pose(fields, node: node, work: &work)
                let worldPose = try MJCFArithmetic.core { () throws(CoreError) in try parentPose.composed(with: local) }
                var jointNode: Int?, inertialNode: Int?
                for child in table.children[node] {
                    try work.charge(1)
                    // FIXME(INCOMPLETE_IMPLEMENTATION): importModel reaches unsupported MJCF semantics at this gate.
                    // This path must keep failing until its real provider and original behavioral evidence are available.
                    if table.name(child) == "joint" { guard jointNode == nil else { throw .unsupported(node: child, feature: "multiple joints per body") }; jointNode = child }
                    if table.name(child) == "inertial" { guard inertialNode == nil else { throw .duplicate(node: child, name: "inertial") }; inertialNode = child }
                }
                let moves = parentMoves || jointNode != nil
                guard !moves || inertialNode != nil else { throw .missingField(node: node, field: "inertial") }
                let inertia: InertialRepresentation3D?
                if let inertialNode { inertia = try Self.inertia(table: table, node: inertialNode, context: context, work: &work) } else { inertia = nil }
                var representations = empty
                for binding in context.geometry { try work.charge(1); if binding.bodyName == name { representations = binding.representations; usedGeometry.insert(name) } }
                let body: BodyRecord3D
                do { body = try BodyRecord3D(id: id, frame: frame, mode: moves ? .dynamic : .static, bodyToWorld: worldPose, representations: representations, inertia: inertia) } catch { throw .model(error) }
                try work.allocate(MemoryLayout<MechanicalBody>.stride + MemoryLayout<MJCFEntityBinding>.stride + MemoryLayout<MechanicalJoint>.stride)
                bodies.append(.spatial(body)); bindings.append(MJCFEntityBinding(node: node, originalName: name, entity: id, effectiveAttributes: fields))
                let joint = try attachment(table: table, node: jointNode, bodyNode: node, bodyName: name, parent: parent, child: id,
                                           local: local, activeClass: childClass, context: context, names: &jointNames, work: &work)
                joints.append(joint)
                try work.allocate(MemoryLayout<(Int,EntityID,RigidTransform,Bool,String)>.stride)
                queue.append((node,id,worldPose,moves,childClass))
            }
        }
        guard usedGeometry.count == context.geometry.count else { throw .danglingReference(node: -1, name: "CAD body binding") }
        let count = scalarBindings.count
        try work.allocate(try MJCFArithmetic.product(try MJCFArithmetic.product(count,3), MemoryLayout<Double>.stride))
        let state: KinematicState
        do { state = try KinematicState(revision: context.source.revision, time: 0, q: [Double](repeating: 0,count: count), v: [Double](repeating: 0,count: count), acceleration: [Double](repeating: 0,count: count)) } catch { throw .joint(error) }
        do { return try MechanicalDescriptor(identity: context.identity, revision: context.source.revision, bodies: bodies, joints: joints,
                                            root: world, rootBase: .fixed, rootAuthority: .fixed, worldFrame: gravity.frame, initialState: state,
                                            representationRequirements: [], features: [], extensions: []) } catch { throw .compilation(error) }
    }
    private mutating func attachment(table: MJCFElementTable, node: Int?, bodyNode: Int, bodyName: String, parent: EntityID, child: EntityID,
                                     local: RigidTransform, activeClass: String, context: MJCFImportContext, names: inout Set<String>, work: inout MJCFWork) throws(MJCFError) -> MechanicalJoint {
        var fields: [MJCFEffectiveAttribute] = [], name = "fixed:" + bodyName, origin = bodyNode, position = Vector3.zero
        var kind: ScalarCoordinateKind?, reference = 0.0, manifold: JointManifold
        if let node {
            // FIXME(INCOMPLETE_IMPLEMENTATION): importModel reaches unsupported MJCF semantics at this gate.
            // This path must keep failing until its real provider and original behavioral evidence are available.
            origin = node; guard table.children[node].isEmpty else { throw .unsupported(node: node, feature: "joint children") }
            fields = try defaults.effective(table: table, node: node, kind: "joint", activeClass: activeClass, work: &work)
            try MJCFElementTable.check(fields, allowed: ["name","class"] + (MJCFDefaults.fields(for: "joint") ?? []), node: node, work: &work)
            name = try MJCFElementTable.required(fields, "name", node: node, work: &work)
            guard names.insert(name).inserted else { throw .duplicate(node: node, name: name) }
            try work.allocate(4 * MemoryLayout<String>.stride)
            let type = try MJCFElementTable.value(fields, "type", work: &work) ?? "hinge"
            // FIXME(INCOMPLETE_IMPLEMENTATION): importModel reaches non-scalar/limited/passive joints here.
            // Their manifold, passive law and physical bound providers must be integrated before admission.
            guard type == "hinge" || type == "slide" else { throw .unsupported(node: node, feature: type) }
            try Self.passiveZero(fields, names: ["armature","damping","frictionloss","stiffness","springref"], node: node, work: &work)
            try Self.unlimited(fields, node: node, work: &work)
            let p = try MJCFElementTable.numbers(fields, "pos", fallback: [0,0,0], count: 3, node: node, work: &work)
            let a = try MJCFElementTable.numbers(fields, "axis", fallback: [0,0,1], count: 3, node: node, work: &work)
            position = try MJCFArithmetic.core { () throws(CoreError) in try Vector3(p[0],p[1],p[2]) }
            let axis = try MJCFArithmetic.core { () throws(CoreError) in try Vector3(a[0],a[1],a[2]) }
            guard try MJCFArithmetic.core({ () throws(CoreError) in try axis.magnitude() }) > 1e-13 else { throw .invalidInput(node: node, field: "axis") }
            reference = try MJCFArithmetic.finite(MJCFElementTable.numbers(fields, "ref", fallback: [0], count: 1, node: node, work: &work)[0] * (type == "hinge" ? angleScale : 1))
            kind = type == "hinge" ? .rotation : .translation
            do { manifold = try JointManifold(type == "hinge" ? .revolute(axis: axis) : .prismatic(axis: axis)) }
            catch let e as JointError { throw .joint(e) } catch let e as CoreError { throw .core(e) } catch { throw .producerRejected(node: node) }
        } else {
            do { manifold = try JointManifold(.fixed) } catch let e as JointError { throw .joint(e) } catch let e as CoreError { throw .core(e) } catch { throw .producerRejected(node: bodyNode) }
        }
        let id = try MJCFArithmetic.id(.joint, context.identity + (node == nil ? "/" : "/joint:") + name, work: &work)
        let parentFrame = try MJCFArithmetic.id(.frame, id.key + "/parent", work: &work)
        let childFrame = try MJCFArithmetic.id(.frame, id.key + "/child", work: &work)
        let offset = RigidTransform(rotation: .identity, translation: position)
        let parentPose = try MJCFArithmetic.core { () throws(CoreError) in try local.composed(with: offset) }
        let record: JointRecord
        do { record = try JointRecord(id: id, parentBody: parent, childBody: child,
                                     parentAnchor: JointAnchor(frame: parentFrame, placement: .fixed(parentPose)), childAnchor: JointAnchor(frame: childFrame, placement: .fixed(offset)), manifold: manifold) } catch { throw .joint(error) }
        if let kind { try work.allocate(MemoryLayout<(MJCFEntityBinding,ScalarCoordinateKind,Double)>.stride); scalarBindings.append((MJCFEntityBinding(node: origin, originalName: name, entity: id, effectiveAttributes: fields), kind, reference)) }
        return MechanicalJoint(record: record, authority: node == nil ? .fixed : .dynamicState)
    }
    static func passiveZero(_ fields: [MJCFEffectiveAttribute], names: [String], node: Int, work: inout MJCFWork) throws(MJCFError) {
        for name in names {
            if let text = try MJCFElementTable.value(fields, name, work: &work) {
                let values = try MJCFArithmetic.numbers(text, maximum: 1, node: node, work: &work)
                // FIXME(INCOMPLETE_IMPLEMENTATION): importModel reaches unsupported MJCF semantics at this gate.
                // This path must keep failing until its real provider and original behavioral evidence are available.
                guard values.count == 1, values[0] == 0 else { throw .unsupported(node: node, feature: name) }
            }
        }
    }
    static func unlimited(_ fields: [MJCFEffectiveAttribute], node: Int, work: inout MJCFWork) throws(MJCFError) {
        // FIXME(INCOMPLETE_IMPLEMENTATION): importModel reaches unsupported MJCF semantics at this gate.
        // This path must keep failing until its real provider and original behavioral evidence are available.
        if let limit = try MJCFElementTable.value(fields, "limited", work: &work) { guard limit == "false" || limit == "auto" else { throw .unsupported(node: node, feature: "limited") } }
        guard try MJCFElementTable.value(fields, "range", work: &work) == nil else { throw .unsupported(node: node, feature: "range") }
    }
    private static func inertia(table: MJCFElementTable, node: Int, context: MJCFImportContext, work: inout MJCFWork) throws(MJCFError) -> InertialRepresentation3D {
        // FIXME(INCOMPLETE_IMPLEMENTATION): importModel reaches unsupported MJCF semantics at this gate.
        // This path must keep failing until its real provider and original behavioral evidence are available.
        guard table.children[node].isEmpty else { throw .unsupported(node: node, feature: "inertial children") }
        let fields = try table.fields(node, work: &work)
        try MJCFElementTable.check(fields, allowed: ["pos","quat","mass","diaginertia","fullinertia"], node: node, work: &work)
        _ = try MJCFElementTable.required(fields, "pos", node: node, work: &work)
        let mass = try MJCFElementTable.numbers(fields, "mass", fallback: nil, count: 1, node: node, work: &work)[0]
        let diagonal = try MJCFElementTable.value(fields, "diaginertia", work: &work), full = try MJCFElementTable.value(fields, "fullinertia", work: &work)
        guard (diagonal != nil) != (full != nil) else { throw .invalidInput(node: node, field: "inertia tensor") }
        var tensor: Matrix3
        if diagonal != nil {
            let v = try MJCFElementTable.numbers(fields, "diaginertia", fallback: nil, count: 3, node: node, work: &work)
            tensor = try MJCFArithmetic.core { () throws(CoreError) in try Matrix3(v[0],0,0,0,v[1],0,0,0,v[2]) }
        } else {
            // FIXME(INCOMPLETE_IMPLEMENTATION): importModel reaches unsupported MJCF semantics at this gate.
            // This path must keep failing until its real provider and original behavioral evidence are available.
            guard try MJCFElementTable.value(fields, "quat", work: &work) == nil else { throw .unsupported(node: node, feature: "fullinertia with quat") }
            let v = try MJCFElementTable.numbers(fields, "fullinertia", fallback: nil, count: 6, node: node, work: &work)
            tensor = try MJCFArithmetic.core { () throws(CoreError) in try Matrix3(v[0],v[3],v[4],v[3],v[1],v[5],v[4],v[5],v[2]) }
        }
        let pose = try table.pose(fields, node: node, work: &work)
        do {
            let properties = try MassProperties3D(mass: mass, centerOfMass: .zero, inertiaAtCenter: tensor, policy: context.compilationPolicy.inertiaPolicy)
            return InertialRepresentation3D(properties: try properties.transformed(by: pose, policy: context.compilationPolicy.inertiaPolicy), provenance: context.source, quality: .exact)
        } catch let e as ModelError { throw .model(e) } catch let e as CoreError { throw .core(e) } catch { throw .producerRejected(node: node) }
    }
    func scalarJoints(compiled: CompiledMechanicalModel, work: inout MJCFWork) throws(MJCFError) -> [MJCFScalarJoint] {
        var result: [MJCFScalarJoint] = []
        for (binding,kind,reference) in scalarBindings {
            var found: Int?
            for i in compiled.tree.joints.indices { try work.charge(1); if compiled.tree.joints[i].id == binding.entity { found = i } }
            guard let index = found else { throw .identityMismatch }
            let layout = compiled.tree.layout.joints[index]
            guard layout.positions.count == 1, layout.velocities.count == 1, layout.positions.start == layout.velocities.start else { throw .identityMismatch }
            try work.allocate(MemoryLayout<MJCFScalarJoint>.stride)
            result.append(MJCFScalarJoint(binding: binding, coordinate: kind, positionIndex: layout.positions.range.lowerBound, velocityIndex: layout.velocities.range.lowerBound, reference: reference))
        }
        guard result.count == compiled.tree.layout.positionCount, result.count == compiled.tree.layout.velocityCount else { throw .identityMismatch }
        return result
    }
}
