internal struct URDFAdmission {
    private struct Link {
        let name: String
        let body: EntityID
        let frame: EntityID
        let inertia: InertialRepresentation3D?
        let collisionRepresentation: GeometryRepresentation?
        let node: Int
    }
    private struct Joint {
        let name: String
        let parent: String
        let child: String
        let origin: RigidTransform
        let axis: Vector3?
        let node: Int
    }
    let nodes: URDFNodes
    let options: URDFImportOptions
    let compilationPolicy: CompilationPolicy
    private var losses: [URDFLoss] = []
    private var assets: [URDFAssetReference] = []
    private var geometries: [URDFGeometryRecord] = []
    private var collisions: [URDFCollisionBinding] = []
    private var materials: Set<String> = []

    init(nodes: URDFNodes, options: URDFImportOptions, compilationPolicy: CompilationPolicy) {
        self.nodes = nodes; self.options = options; self.compilationPolicy = compilationPolicy
    }

    mutating func read(work: inout URDFWork) throws -> URDFDraft {
        let root = nodes.document.rootIndex, location = nodes.location(root)
        guard nodes.name(root) == "robot", options.worldFrame.kind == .frame else {
            throw URDFFailure(.invalid("robot/world frame"), at: location)
        }
        try identifier(options.identity, at: location, work: &work)
        try identifier(options.rootName, at: location, work: &work)
        try identifier(options.worldFrame.key, at: location, work: &work)
        try identifier(options.provenance.source, at: location, work: &work)
        let rootChildren = try check(root, attributes: ["name", "version"], children: ["link", "joint", "material"], work: &work)
        let robotName = try required(root, "name", work: &work)
        try identifier(robotName, at: location, work: &work)
        if let version = try nodes.attribute(root, "version", work: &work), version != "1.0" {
            throw URDFFailure(.unsupported("URDF version"), at: location)
        }
        // Required physical laws never become representation-loss successes, even below unknown wrappers.
        for index in nodes.document.nodes.indices {
            try work.charge(1, at: nodes.location(index))
            switch nodes.name(index) {
            case "mimic", "transmission", "limit", "safety_controller", "calibration":
                throw URDFFailure(.unsupported(nodes.name(index)), at: nodes.location(index))
            default: break
            }
        }
        for index in rootChildren where nodes.name(index) == "material" {
            let name = try required(index, "name", work: &work)
            try identifier(name, at: nodes.location(index), work: &work)
            try work.allocate(1, stride: MemoryLayout<String>.stride, at: nodes.location(index))
            guard materials.insert(name).inserted else { throw URDFFailure(.duplicate("material"), at: nodes.location(index)) }
            try material(index, global: true, work: &work)
        }
        var links: [Link] = [], joints: [Joint] = [], indices: [String: Int] = [:], jointNames: Set<String> = []
        for index in rootChildren {
            try work.charge(1, at: nodes.location(index))
            switch nodes.name(index) {
            case "link":
                try appendCapacity(links.count, maximum: work.policy.maximumLinks, resource: "links", at: index, work: &work)
                try work.allocate(1, stride: MemoryLayout<Link>.stride, at: nodes.location(index))
                try work.allocate(1, stride: MemoryLayout<(String, Int)>.stride, at: nodes.location(index))
                let link = try link(index, work: &work)
                guard indices.updateValue(links.count, forKey: link.name) == nil else {
                    throw URDFFailure(.duplicate("link"), at: nodes.location(index))
                }
                links.append(link)
            case "joint":
                try appendCapacity(joints.count, maximum: work.policy.maximumJoints, resource: "joints", at: index, work: &work)
                try work.allocate(1, stride: MemoryLayout<Joint>.stride, at: nodes.location(index))
                try work.allocate(1, stride: MemoryLayout<String>.stride, at: nodes.location(index))
                let joint = try joint(index, work: &work)
                guard jointNames.insert(joint.name).inserted else { throw URDFFailure(.duplicate("joint"), at: nodes.location(index)) }
                joints.append(joint)
            default: break
            }
        }
        guard !links.isEmpty, let rootIndex = indices[options.rootName],
              links[rootIndex].name.utf8.elementsEqual(options.rootName.utf8) else {
            throw URDFFailure(.missing("selected root link"), at: location)
        }
        try work.allocate(links.count, stride: MemoryLayout<[Int]>.stride, at: location)
        try work.allocate(joints.count, stride: MemoryLayout<Int>.stride, at: location)
        try work.allocate(links.count, stride: MemoryLayout<Bool>.stride, at: location)
        var childJoints = [[Int]](repeating: [], count: links.count), incoming = [Bool](repeating: false, count: links.count)
        for (index, joint) in joints.enumerated() {
            try work.charge(1, at: nodes.location(joint.node))
            try work.charge(joint.parent.utf8.count, at: nodes.location(joint.node))
            try work.charge(joint.child.utf8.count, at: nodes.location(joint.node))
            guard let parent = indices[joint.parent], let child = indices[joint.child], parent != child,
                  links[parent].name.utf8.elementsEqual(joint.parent.utf8),
                  links[child].name.utf8.elementsEqual(joint.child.utf8) else {
                throw URDFFailure(.invalid("joint body reference"), at: nodes.location(joint.node))
            }
            guard !incoming[child] else { throw URDFFailure(.invalid("multiple parents"), at: nodes.location(joint.node)) }
            incoming[child] = true; childJoints[parent].append(index)
        }
        for index in links.indices {
            try work.charge(1, at: nodes.location(links[index].node))
            guard incoming[index] == (index != rootIndex) else { throw URDFFailure(.invalid("unique selected root"), at: location) }
        }
        let base: BaseLayout, rootPose: RigidTransform, rootAuthority: CoordinateAuthority
        switch options.rootPlacement {
        case .fixed(let pose): base = .fixed; rootPose = pose; rootAuthority = .fixed
        case .spatialFloating(let pose): base = .spatialFloating; rootPose = pose; rootAuthority = .dynamicState
        }
        try work.allocate(links.count, stride: MemoryLayout<RigidTransform?>.stride, at: location)
        try work.allocate(links.count, stride: MemoryLayout<Bool>.stride, at: location)
        try work.allocate(links.count, stride: MemoryLayout<Int>.stride, at: location)
        var poses = [RigidTransform?](repeating: nil, count: links.count), moving = [Bool](repeating: false, count: links.count)
        var queue = [rootIndex], cursor = 0
        queue.reserveCapacity(links.count); poses[rootIndex] = rootPose; moving[rootIndex] = rootAuthority == .dynamicState
        while cursor < queue.count {
            let parent = queue[cursor]; cursor += 1
            guard let parentPose = poses[parent] else { throw URDFFailure(.invalid("topology pose"), at: location) }
            for jointIndex in childJoints[parent] {
                let joint = joints[jointIndex]; try work.charge(40, at: nodes.location(joint.node))
                guard let child = indices[joint.child], poses[child] == nil else {
                    throw URDFFailure(.invalid("cyclic topology"), at: nodes.location(joint.node))
                }
                poses[child] = try parentPose.composed(with: joint.origin)
                moving[child] = moving[parent] || joint.axis != nil; queue.append(child)
            }
        }
        guard queue.count == links.count else { throw URDFFailure(.invalid("disconnected/cyclic topology"), at: location) }
        try work.allocate(links.count, stride: MemoryLayout<MechanicalBody>.stride, at: location)
        try work.allocate(joints.count, stride: MemoryLayout<MechanicalJoint>.stride, at: location)
        var bodies: [MechanicalBody] = [], records: [MechanicalJoint] = []
        bodies.reserveCapacity(links.count); records.reserveCapacity(joints.count)
        var coordinates = base.positionCount, velocities = base.velocityCount
        for index in links.indices {
            let link = links[index]; try work.charge(1, at: nodes.location(link.node))
            guard let pose = poses[index] else { throw URDFFailure(.invalid("missing initial pose"), at: nodes.location(link.node)) }
            guard !moving[index] || link.inertia != nil else { throw URDFFailure(.missing("moving link inertia"), at: nodes.location(link.node)) }
            let record = try BodyRecord3D(id: link.body, frame: link.frame, mode: moving[index] ? .dynamic : .static,
                bodyToWorld: pose, representations: BodyRepresentations(collisionGeometry: link.collisionRepresentation), inertia: link.inertia)
            bodies.append(.spatial(record))
        }
        for joint in joints {
            try work.charge(12, at: nodes.location(joint.node))
            guard let parent = indices[joint.parent], let child = indices[joint.child] else {
                throw URDFFailure(.invalid("joint reference"), at: nodes.location(joint.node))
            }
            let specification: JointSpecification
            if let axis = joint.axis { specification = .revolute(axis: axis) } else { specification = .fixed }
            let manifold = try JointManifold(specification)
            let id = try entity(.joint, joint.name, at: joint.node, work: &work)
            let parentFrame = try entity(.frame, "urdf/joint/\(joint.name)/parent", at: joint.node, work: &work)
            let childFrame = try entity(.frame, "urdf/joint/\(joint.name)/child", at: joint.node, work: &work)
            let record = try JointRecord(id: id, parentBody: links[parent].body, childBody: links[child].body,
                parentAnchor: JointAnchor(frame: parentFrame, placement: .fixed(joint.origin)),
                childAnchor: JointAnchor(frame: childFrame, placement: .fixed(.identity)), manifold: manifold)
            records.append(MechanicalJoint(record: record, authority: joint.axis == nil ? .fixed : .dynamicState))
            coordinates = try sum(coordinates, manifold.positionCount, at: joint.node)
            velocities = try sum(velocities, manifold.velocityCount, at: joint.node)
        }
        try work.allocate(coordinates, stride: MemoryLayout<Double>.stride, at: location)
        try work.allocate(velocities, stride: MemoryLayout<Double>.stride, at: location)
        try work.allocate(velocities, stride: MemoryLayout<Double>.stride, at: location)
        var q = [Double](repeating: 0, count: coordinates)
        if base == .spatialFloating {
            try work.allocate(13, stride: MemoryLayout<Double>.stride, at: location)
            let coordinates = try base.encode(.spatial(pose: rootPose, worldLinearVelocity: .zero, bodyAngularVelocity: .zero))
            for index in coordinates.q.indices { try work.charge(1); q[index] = coordinates.q[index] }
        }
        let state = try KinematicState(revision: options.provenance.revision, time: 0, q: q,
            v: [Double](repeating: 0, count: velocities), acceleration: [Double](repeating: 0, count: velocities))
        let descriptor = try MechanicalDescriptor(identity: options.identity, revision: options.provenance.revision,
            bodies: bodies, joints: records, root: links[rootIndex].body, rootBase: base, rootAuthority: rootAuthority,
            worldFrame: options.worldFrame, initialState: state, representationRequirements: [], features: [], extensions: [])
        return URDFDraft(robotName: robotName, descriptor: descriptor, geometries: geometries, collisions: collisions, assets: assets, losses: losses)
    }

    private mutating func link(_ index: Int, work: inout URDFWork) throws -> Link {
        let children = try check(index, attributes: ["name"], children: ["inertial", "visual", "collision"], work: &work)
        let name = try required(index, "name", work: &work)
        let body = try entity(.body, name, at: index, work: &work)
        let frame = try entity(.frame, "urdf/link/\(name)", at: index, work: &work)
        let inertialNode = try nodes.single(index, "inertial", work: &work)
        let inertia: InertialRepresentation3D?
        if let inertialNode { inertia = try inertial(inertialNode, work: &work) } else { inertia = nil }
        let start = collisions.count
        var unservedCollision = false
        for child in children {
            try work.charge(1, at: nodes.location(child))
            if nodes.name(child) == "collision" || nodes.name(child) == "visual" {
                let served = try geometry(child, body: body, work: &work)
                if nodes.name(child) == "collision", !served { unservedCollision = true }
            }
        }
        let representation: GeometryRepresentation?
        if collisions.count > start, !unservedCollision {
            let key = "urdf/link/\(name)/collision"
            try identifier(key, at: nodes.location(index), work: &work)
            representation = try GeometryRepresentation(kind: .collisionGeometry, assetKey: key, provenance: options.provenance, quality: .exact)
        } else { representation = nil }
        return Link(name: name, body: body, frame: frame, inertia: inertia, collisionRepresentation: representation, node: index)
    }

    private mutating func joint(_ index: Int, work: inout URDFWork) throws -> Joint {
        _ = try check(index, attributes: ["name", "type"], children: ["origin", "parent", "child", "axis", "dynamics"], work: &work)
        let name = try required(index, "name", work: &work); try identifier(name, at: nodes.location(index), work: &work)
        let type = try required(index, "type", work: &work)
        guard type == "fixed" || type == "continuous" else { throw URDFFailure(.unsupported("joint type \(type)"), at: nodes.location(index)) }
        guard let parentNode = try nodes.single(index, "parent", required: true, work: &work),
              let childNode = try nodes.single(index, "child", required: true, work: &work) else {
            throw URDFFailure(.missing("joint bodies"), at: nodes.location(index))
        }
        _ = try check(parentNode, attributes: ["link"], children: [], work: &work)
        _ = try check(childNode, attributes: ["link"], children: [], work: &work)
        let parent = try required(parentNode, "link", work: &work), child = try required(childNode, "link", work: &work)
        try identifier(parent, at: nodes.location(parentNode), work: &work); try identifier(child, at: nodes.location(childNode), work: &work)
        let origin = try origin(try nodes.single(index, "origin", work: &work), work: &work)
        let axisNode = try nodes.single(index, "axis", work: &work)
        var axis: Vector3? = type == "continuous" ? .unitX : nil
        if let axisNode {
            guard type == "continuous" else { throw URDFFailure(.unsupported("axis on fixed joint"), at: nodes.location(axisNode)) }
            _ = try check(axisNode, attributes: ["xyz"], children: [], work: &work)
            axis = try URDFNumbers.vector(required(axisNode, "xyz", work: &work), at: nodes.location(axisNode), work: &work)
            do { _ = try axis?.normalized() }
            catch { throw URDFFailure(.core(error), at: nodes.location(axisNode)) }
        }
        if let dynamics = try nodes.single(index, "dynamics", work: &work) {
            _ = try check(dynamics, attributes: ["damping", "friction"], children: [], work: &work)
            let dampingText = try nodes.attribute(dynamics, "damping", work: &work)
            let frictionText = try nodes.attribute(dynamics, "friction", work: &work)
            guard dampingText != nil || frictionText != nil else {
                throw URDFFailure(.invalid("empty dynamics"), at: nodes.location(dynamics))
            }
            let damping = try number(dynamics, "damping", defaultValue: 0, work: &work)
            let friction = try number(dynamics, "friction", defaultValue: 0, work: &work)
            guard damping == 0, friction == 0 else { throw URDFFailure(.unsupported("joint dynamics law"), at: nodes.location(dynamics)) }
        }
        return Joint(name: name, parent: parent, child: child, origin: origin, axis: axis, node: index)
    }

    private mutating func inertial(_ index: Int, work: inout URDFWork) throws -> InertialRepresentation3D {
        _ = try check(index, attributes: [], children: ["origin", "mass", "inertia"], work: &work)
        guard let massNode = try nodes.single(index, "mass", required: true, work: &work),
              let tensor = try nodes.single(index, "inertia", required: true, work: &work) else {
            throw URDFFailure(.missing("inertial values"), at: nodes.location(index))
        }
        _ = try check(massNode, attributes: ["value"], children: [], work: &work)
        _ = try check(tensor, attributes: ["ixx", "ixy", "ixz", "iyy", "iyz", "izz"], children: [], work: &work)
        let mass = try number(massNode, "value", work: &work)
        let xx = try number(tensor, "ixx", work: &work), xy = try number(tensor, "ixy", work: &work)
        let xz = try number(tensor, "ixz", work: &work), yy = try number(tensor, "iyy", work: &work)
        let yz = try number(tensor, "iyz", work: &work), zz = try number(tensor, "izz", work: &work)
        let pose = try origin(try nodes.single(index, "origin", work: &work), work: &work)
        try work.charge(160, at: nodes.location(index))
        do {
            let supplied = try MassProperties3D(mass: mass, centerOfMass: .zero,
                inertiaAtCenter: Matrix3(xx, xy, xz, xy, yy, yz, xz, yz, zz), policy: compilationPolicy.inertiaPolicy)
            let properties = try supplied.transformed(by: pose, policy: compilationPolicy.inertiaPolicy)
            return InertialRepresentation3D(properties: properties, provenance: options.provenance, quality: .exact)
        } catch let error as CoreError { throw URDFFailure(.core(error), at: nodes.location(index)) }
        catch let error as ModelError { throw URDFFailure(.model(error), at: nodes.location(index)) }
        catch { throw URDFFailure(.unexpectedProducer, at: nodes.location(index)) }
    }

    private mutating func origin(_ index: Int?, work: inout URDFWork) throws -> RigidTransform {
        guard let index else { return .identity }
        _ = try check(index, attributes: ["xyz", "rpy"], children: [], work: &work)
        let translation: Vector3, rpy: Vector3
        if let text = try nodes.attribute(index, "xyz", work: &work) { translation = try URDFNumbers.vector(text, at: nodes.location(index), work: &work) }
        else { translation = .zero }
        if let text = try nodes.attribute(index, "rpy", work: &work) { rpy = try URDFNumbers.vector(text, at: nodes.location(index), work: &work) }
        else { rpy = .zero }
        try work.charge(80, at: nodes.location(index))
        let roll = try UnitQuaternion(axis: .unitX, angle: rpy.x), pitch = try UnitQuaternion(axis: .unitY, angle: rpy.y)
        let yaw = try UnitQuaternion(axis: .unitZ, angle: rpy.z)
        return RigidTransform(rotation: try yaw.multiplied(by: pitch).multiplied(by: roll), translation: translation)
    }

    private mutating func geometry(_ index: Int, body: EntityID, work: inout URDFWork) throws -> Bool {
        let visual = nodes.name(index) == "visual"
        _ = try check(index, attributes: ["name"], children: visual ? ["origin", "geometry", "material"] : ["origin", "geometry"], work: &work)
        if let name = try nodes.attribute(index, "name", work: &work) { try identifier(name, at: nodes.location(index), work: &work) }
        let placement = try origin(try nodes.single(index, "origin", work: &work), work: &work)
        guard let geometryNode = try nodes.single(index, "geometry", required: true, work: &work) else {
            throw URDFFailure(.missing("geometry"), at: nodes.location(index))
        }
        let shapes = try check(geometryNode, attributes: [], children: ["box", "sphere", "cylinder", "mesh"], work: &work)
        guard shapes.count == 1 else { throw URDFFailure(.invalid("single geometry shape"), at: nodes.location(geometryNode)) }
        let shapeNode = shapes[0], geometry: URDFGeometryRecord.Geometry, shape: CollisionShape?
        switch nodes.name(shapeNode) {
        case "box":
            _ = try check(shapeNode, attributes: ["size"], children: [], work: &work)
            let size = try URDFNumbers.vector(required(shapeNode, "size", work: &work), at: nodes.location(shapeNode), work: &work)
            guard size.x > 0, size.y > 0, size.z > 0 else { throw URDFFailure(.invalid("box dimensions"), at: nodes.location(shapeNode)) }
            geometry = .box(size: size); shape = .box(halfExtents: try size.scaled(by: 0.5))
        case "sphere":
            _ = try check(shapeNode, attributes: ["radius"], children: [], work: &work)
            let radius = try number(shapeNode, "radius", work: &work)
            guard radius > 0 else { throw URDFFailure(.invalid("sphere radius"), at: nodes.location(shapeNode)) }
            geometry = .sphere(radius: radius); shape = .sphere(radius: radius)
        case "cylinder":
            _ = try check(shapeNode, attributes: ["radius", "length"], children: [], work: &work)
            let radius = try number(shapeNode, "radius", work: &work), length = try number(shapeNode, "length", work: &work)
            guard radius > 0, length > 0 else { throw URDFFailure(.invalid("cylinder dimensions"), at: nodes.location(shapeNode)) }
            geometry = .cylinder(radius: radius, length: length); shape = nil
        case "mesh":
            _ = try check(shapeNode, attributes: ["filename", "scale"], children: [], work: &work)
            let reference = try asset(required(shapeNode, "filename", work: &work), at: shapeNode, work: &work)
            let scale: Vector3
            if let text = try nodes.attribute(shapeNode, "scale", work: &work) { scale = try URDFNumbers.vector(text, at: nodes.location(shapeNode), work: &work) }
            else { scale = try Vector3(1, 1, 1) }
            guard scale.x > 0, scale.y > 0, scale.z > 0 else { throw URDFFailure(.invalid("positive mesh scale"), at: nodes.location(shapeNode)) }
            geometry = .mesh(reference: reference, scale: scale); shape = nil
        default: throw URDFFailure(.unsupported("geometry shape"), at: nodes.location(shapeNode))
        }
        try appendCapacity(geometries.count, maximum: work.policy.maximumGeometryRecords, resource: "geometries", at: index, work: &work)
        try work.allocate(1, stride: MemoryLayout<URDFGeometryRecord>.stride, at: nodes.location(index))
        geometries.append(URDFGeometryRecord(body: body, usage: visual ? .visual : .collision, geometry: geometry, geometryToBody: placement, location: nodes.location(index)))
        if visual {
            try loss("visual geometry has no display provider", at: index, work: &work)
            if let materialNode = try nodes.single(index, "material", work: &work) { try material(materialNode, global: false, work: &work) }
            return false
        }
        guard let shape else { try loss("unsupported collision geometry", at: index, work: &work); return false }
        try shape.validate()
        try work.allocate(1, stride: MemoryLayout<URDFCollisionBinding>.stride, at: nodes.location(index))
        let key = "urdf/collision/\(body.key)/\(collisions.count)"
        let collider = try entity(.collider, key, at: index, work: &work)
        let representation = try GeometryRepresentation(kind: .collisionGeometry, assetKey: key, provenance: options.provenance, quality: .exact)
        collisions.append(URDFCollisionBinding(body: body, collider: collider, shape: shape, shapeToBody: placement,
            representation: representation, stamp: ModelStamp(identity: options.identity, revision: options.provenance.revision), worldFrame: options.worldFrame))
        return true
    }

    private mutating func material(_ index: Int, global: Bool, work: inout URDFWork) throws {
        let children = try check(index, attributes: ["name"], children: ["color", "texture"], work: &work)
        let name = try required(index, "name", work: &work); try identifier(name, at: nodes.location(index), work: &work)
        let color = try nodes.single(index, "color", work: &work), texture = try nodes.single(index, "texture", work: &work)
        if !global, children.isEmpty {
            guard let existing = materials.firstIndex(of: name), materials[existing].utf8.elementsEqual(name.utf8) else {
                throw URDFFailure(.missing("named material"), at: nodes.location(index))
            }
        }
        if global, color == nil, texture == nil { throw URDFFailure(.missing("material definition"), at: nodes.location(index)) }
        if let color {
            _ = try check(color, attributes: ["rgba"], children: [], work: &work)
            let text = try required(color, "rgba", work: &work)
            try work.charge(text.utf8.count, at: nodes.location(color))
            try work.allocate(5, stride: MemoryLayout<Substring>.stride, at: nodes.location(color))
            let values = text.split(maxSplits: 4, omittingEmptySubsequences: true) { $0 == " " || $0 == "\t" || $0 == "\n" || $0 == "\r" }
            guard values.count == 4 else { throw URDFFailure(.invalid("RGBA"), at: nodes.location(color)) }
            for text in values {
                try work.allocate(text.utf8.count, at: nodes.location(color))
                let value = try URDFNumbers.scalar(String(text), at: nodes.location(color), work: &work)
                guard value >= 0, value <= 1 else { throw URDFFailure(.invalid("RGBA range"), at: nodes.location(color)) }
            }
        }
        if let texture {
            _ = try check(texture, attributes: ["filename"], children: [], work: &work)
            _ = try asset(required(texture, "filename", work: &work), at: texture, work: &work)
        }
        try loss("material has no display provider", at: index, work: &work)
    }

    private mutating func asset(_ path: String, at index: Int, work: inout URDFWork) throws(URDFFailure) -> URDFAssetReference {
        let location = nodes.location(index)
        guard let base = options.assetBase, !base.isEmpty, !path.isEmpty else { throw URDFFailure(.missing("explicit asset base/reference"), at: location) }
        try work.limit(base.utf8.count, work.policy.maximumReferenceBytes, "asset base", at: location)
        try work.limit(path.utf8.count, work.policy.maximumReferenceBytes, "asset reference", at: location)
        try work.charge(path.utf8.count, at: location)
        guard !path.hasPrefix("/"), !path.utf8.contains(where: { $0 == 92 || $0 == 58 || $0 == 37 || $0 == 35 || $0 == 63 || $0 < 32 || $0 == 127 }) else {
            throw URDFFailure(.invalid("safe relative asset reference"), at: location)
        }
        // Iterate owned UTF8 without a component array. Empty, dot and parent segments are prohibited.
        var segmentStart = path.utf8.startIndex, cursor = segmentStart
        while true {
            if cursor == path.utf8.endIndex || path.utf8[cursor] == 47 {
                let segment = path.utf8[segmentStart..<cursor]
                guard !segment.isEmpty, !(segment.count == 1 && segment.first == 46),
                      !(segment.count == 2 && segment.allSatisfy({ $0 == 46 })) else {
                    throw URDFFailure(.invalid("asset path segment"), at: location)
                }
                if cursor == path.utf8.endIndex { break }
                segmentStart = path.utf8.index(after: cursor)
            }
            cursor = path.utf8.index(after: cursor)
        }
        try appendCapacity(assets.count, maximum: work.policy.maximumAssets, resource: "assets", at: index, work: &work)
        try work.allocate(1, stride: MemoryLayout<URDFAssetReference>.stride, at: location)
        let reference = URDFAssetReference(base: base, relativePath: path, location: location)
        assets.append(reference)
        try loss("unresolved external asset", at: index, work: &work)
        return reference
    }

    private mutating func check(_ index: Int, attributes allowedAttributes: [String], children allowedChildren: [String],
                                work: inout URDFWork) throws(URDFFailure) -> [Int] {
        guard case .element(_, let attributes) = nodes.document.nodes[index].content else { throw URDFFailure(.invalid("element"), at: nodes.location(index)) }
        for attribute in attributes {
            try work.charge(attribute.name.utf8.count, at: attribute.location)
            switch attribute.name {
            case "unit", "units", "length_unit", "mass_unit", "time_unit", "angle_unit", "quat_xyzw":
                throw URDFFailure(.unsupported("unit/version pose attribute"), at: attribute.location)
            default: break
            }
            if !allowedAttributes.contains(attribute.name) { try loss("attribute \(attribute.name)", at: index, work: &work) }
        }
        let children = try nodes.elements(index, work: &work)
        for child in children {
            try work.charge(nodes.name(child).utf8.count, at: nodes.location(child))
            if !allowedChildren.contains(nodes.name(child)) { try loss("element \(nodes.name(child))", at: child, work: &work) }
        }
        return children
    }
    private mutating func loss(_ feature: String, at index: Int, work: inout URDFWork) throws(URDFFailure) {
        guard case .preserveUnservedRepresentations = options.lossMode else { throw URDFFailure(.unsupported(feature), at: nodes.location(index)) }
        try appendCapacity(losses.count, maximum: work.policy.maximumLosses, resource: "losses", at: index, work: &work)
        try work.allocate(1, stride: MemoryLayout<URDFLoss>.stride, at: nodes.location(index))
        try work.allocate(feature.utf8.count, at: nodes.location(index))
        losses.append(URDFLoss(feature: feature, location: nodes.location(index)))
    }
    private func required(_ index: Int, _ key: String, work: inout URDFWork) throws(URDFFailure) -> String {
        guard let value = try nodes.attribute(index, key, required: true, work: &work) else { throw URDFFailure(.missing(key), at: nodes.location(index)) }
        return value
    }
    private func number(_ index: Int, _ key: String, defaultValue: Double? = nil, work: inout URDFWork) throws(URDFFailure) -> Double {
        if let text = try nodes.attribute(index, key, work: &work) { return try URDFNumbers.scalar(text, at: nodes.location(index), work: &work) }
        guard let defaultValue else { throw URDFFailure(.missing(key), at: nodes.location(index)) }
        return defaultValue
    }
    private func identifier(_ text: String, at location: XMLLocation, work: inout URDFWork) throws(URDFFailure) {
        guard !text.isEmpty else { throw URDFFailure(.invalid("empty identifier"), at: location) }
        try work.limit(text.utf8.count, work.policy.maximumIdentifierBytes, "identifier bytes", at: location)
        try work.charge(text.utf8.count, at: location)
    }
    private func entity(_ kind: EntityKind, _ key: String, at index: Int, work: inout URDFWork) throws -> EntityID {
        try identifier(key, at: nodes.location(index), work: &work)
        try work.allocate(key.utf8.count, at: nodes.location(index))
        return try EntityID(kind: kind, key: key)
    }
    private func appendCapacity(_ count: Int, maximum: Int, resource: String, at index: Int, work: inout URDFWork) throws(URDFFailure) {
        try work.charge(1, at: nodes.location(index))
        guard count < maximum else { throw URDFFailure(.limit(resource, maximum), at: nodes.location(index)) }
    }
    private func sum(_ a: Int, _ b: Int, at index: Int) throws(URDFFailure) -> Int {
        let (result, overflow) = a.addingReportingOverflow(b)
        guard !overflow else { throw URDFFailure(.arithmeticOverflow, at: nodes.location(index)) }
        return result
    }
}
