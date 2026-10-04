
public struct AnalyticMassCalculator: MassPropertyCalculating, Sendable {
    public init() {}

    public func properties(of primitive: AnalyticPrimitive3D, density: Double,
                           policy: InertiaValidationPolicy) throws -> MassProperties3D {
        try primitive.validating()
        guard density.isFinite, density > 0 else { throw ModelError.invalidDensity }
        let mass: Double, ix: Double, iy: Double, iz: Double
        switch primitive {
        case .box(let width, let depth, let height):
            mass = density * width * depth * height
            ix = mass * (depth * depth + height * height) / 12
            iy = mass * (width * width + height * height) / 12
            iz = mass * (width * width + depth * depth) / 12
        case .sphere(let radius):
            mass = density * (4 / 3) * Double.pi * radius * radius * radius
            ix = (2 / 5) * mass * radius * radius
            iy = ix; iz = ix
        case .cylinder(let radius, let height):
            mass = density * Double.pi * radius * radius * height
            ix = mass * (3 * radius * radius + height * height) / 12
            iy = ix
            iz = mass * radius * radius / 2
        }
        return try MassProperties3D(mass: mass, centerOfMass: .zero,
                                    inertiaAtCenter: Matrix3(ix, 0, 0, 0, iy, 0, 0, 0, iz), policy: policy, origin: .analyticPrimitive)
    }

    public func properties(of primitive: AnalyticPrimitive2D, arealDensity: Double) throws -> MassProperties2D {
        guard arealDensity.isFinite, arealDensity > 0 else { throw ModelError.invalidDensity }
        let mass: Double, inertia: Double
        switch primitive {
        case .rectangle(let width, let height):
            guard width.isFinite, height.isFinite, width > 0, height > 0 else { throw ModelError.invalidDimensions }
            mass = arealDensity * width * height
            inertia = mass * (width * width + height * height) / 12
        case .disk(let radius):
            guard radius.isFinite, radius > 0 else { throw ModelError.invalidDimensions }
            mass = arealDensity * Double.pi * radius * radius
            inertia = mass * radius * radius / 2
        }
        return try MassProperties2D(mass: mass, centerX: 0, centerY: 0, polarInertiaAtCenter: inertia)
    }

    public func compound(parts: [CompoundPart3D], overlap: CompoundOverlapPolicy,
                         policy: InertiaValidationPolicy) throws -> MassProperties3D {
        guard !parts.isEmpty else { throw ModelError.emptyCompound }
        if overlap == .requireDisjointBoundingBoxes {
            let bounds = try parts.map { try boundingBox(of: $0) }
            for first in bounds.indices {
                for second in (first + 1)..<bounds.count {
                    let a = bounds[first], b = bounds[second]
                    let separated = a.1.x <= b.0.x || b.1.x <= a.0.x
                        || a.1.y <= b.0.y || b.1.y <= a.0.y
                        || a.1.z <= b.0.z || b.1.z <= a.0.z
                    guard separated else { throw ModelError.ambiguousOverlap(first: first, second: second) }
                }
            }
        }
        let properties = try parts.map {
            try self.properties(of: $0.primitive, density: $0.density, policy: policy)
                .transformed(by: $0.primitiveToCompound, policy: policy)
        }
        var totalMass = 0.0
        var weightedCenter = Vector3.zero
        for part in properties {
            totalMass += part.mass
            guard totalMass.isFinite else { throw ModelError.invalidMass }
            weightedCenter = try weightedCenter.adding(part.centerOfMass.scaled(by: part.mass))
        }
        let center = try weightedCenter.scaled(by: 1 / totalMass)
        var inertia = Matrix3.zero
        for part in properties {
            let displacement = try part.centerOfMass.subtracting(center)
            inertia = try inertia.adding(InertiaTransformer().shifted(part.inertiaAtCenter, mass: part.mass,
                                                                      displacement: displacement))
        }
        return try MassProperties3D(mass: totalMass, centerOfMass: center, inertiaAtCenter: inertia, policy: policy,
                                    origin: .compound(overlapPolicy: overlap))
    }

    private func boundingBox(of part: CompoundPart3D) throws -> (Vector3, Vector3) {
        let r = try part.primitiveToCompound.rotation.matrix()
        let half: Vector3
        // Outward rounding preserves conservative admission even at large coordinates.
        func boxExtent(_ a: Double, _ b: Double, _ c: Double, _ x: Double, _ y: Double, _ z: Double) -> Double {
            let first = (abs(a) * (x / 2).nextUp).nextUp
            let second = (abs(b) * (y / 2).nextUp).nextUp
            let third = (abs(c) * (z / 2).nextUp).nextUp
            return ((first + second).nextUp + third).nextUp
        }
        func cylinderExtent(_ a: Double, _ b: Double, _ c: Double, _ radius: Double, _ height: Double) -> Double {
            let radial = ((a * a).nextUp + (b * b).nextUp).nextUp.squareRoot().nextUp
            return ((radial * radius).nextUp + (abs(c) * (height / 2).nextUp).nextUp).nextUp
        }
        switch part.primitive {
        case .box(let x, let y, let z):
            half = try Vector3(boxExtent(r.m00, r.m01, r.m02, x, y, z),
                               boxExtent(r.m10, r.m11, r.m12, x, y, z),
                               boxExtent(r.m20, r.m21, r.m22, x, y, z))
        case .sphere(let radius): half = try Vector3(radius.nextUp, radius.nextUp, radius.nextUp)
        case .cylinder(let radius, let height):
            half = try Vector3(cylinderExtent(r.m00, r.m01, r.m02, radius, height),
                               cylinderExtent(r.m10, r.m11, r.m12, radius, height),
                               cylinderExtent(r.m20, r.m21, r.m22, radius, height))
        }
        let center = part.primitiveToCompound.translation
        let lower = try Vector3((center.x - half.x).nextDown, (center.y - half.y).nextDown, (center.z - half.z).nextDown)
        let upper = try Vector3((center.x + half.x).nextUp, (center.y + half.y).nextUp, (center.z + half.z).nextUp)
        return (lower, upper)
    }
}
