import SwiftMechanics
#if canImport(Darwin)
import Darwin
#elseif canImport(WASILibc)
import WASILibc
#elseif canImport(Glibc)
import Glibc
#else
#error("No admitted scalar mathematics platform module is available.")
#endif

struct PlanarRuntimeFixtures {
    static let pi = 3.14159265358979323846
    static func grid(revision: UInt64 = 1, viscosity: Double = 0.1) throws -> PlanarGrid {
        try PlanarGrid(id: "periodic-runtime", revision: revision, frame: EntityID(kind: .frame, key: "world"),
            source: SourceProvenance(source: "planar-runtime-fixture", revision: 1), nx: 6, ny: 6,
            lengthX: 2*pi, lengthY: 2*pi, depth: 0.5, density: 1, viscosity: viscosity,
            limits: PlanarLimits(maximumCells: 64, maximumMetadataBytes: 1024, maximumSpeed: 10,
                maximumPressure: 10000, maximumAcceleration: 10, maximumStep: 1))
    }
    static func source() throws -> PlanarSource { try PlanarSource(accelerationX: 0, accelerationY: 0) }
    static func state(_ g: PlanarGrid, time: Double = 0, sequence: UInt64 = 0, shear: Bool = false) throws -> PlanarState {
        var u = [Double](repeating: 0, count: g.count), v = u
        for j in 0..<g.ny { for i in 0..<g.nx {
            let k = j*g.nx+i
            u[k] = shear ? sin((Double(j)+0.5)*g.dy) : sin(Double(i)*g.dx)*cos((Double(j)+0.5)*g.dy)
            v[k] = shear ? 0 : -cos((Double(i)+0.5)*g.dx)*sin(Double(j)*g.dy)
        } }
        return try PlanarState(grid: g, time: time, sequence: sequence, u: u, v: v,
                               pressure: [Double](repeating: 0, count: g.count), source: source())
    }
    static func policy(cancel: @escaping @Sendable () -> Bool = { false }) throws -> PlanarPolicy {
        try PlanarPolicy(divergenceAbsolute: 1e-9, pressureAbsolute: 1e-8, pressureRelative: 1e-9,
            forceAbsolute: 1e-8, forceRelative: 1e-9, energyAbsolute: 1e-9, energyRelative: 1e-9,
            courantLimit: 0.9, linearTolerance: LinearTolerance(absoluteResidual: 1e-9, relativeResidual: 1e-11, pivotThreshold: 1e-14),
            isCancelled: cancel)
    }
    static func numerical(iterations: Int = 10000) throws -> NumericalWork {
        NumericalWork(budget: try NumericalBudget(scalarStorage: 100000, arithmeticOperations: 10000000, iterations: iterations))
    }
    static func bytes(storage: Int = 30000, units: Int = 100000,
                      cancel: @escaping @Sendable () -> Bool = { false }) throws -> PlanarContinuationWork {
        try PlanarContinuationWork(maximumStorageBytes: storage, maximumWorkUnits: units, isCancelled: cancel)
    }
    static func model(revision: UInt64 = 1) throws -> CompiledMechanicalModel {
        let tolerance = try NumericalTolerance(absolute: 1e-12, relative: 1e-12)
        let inertiaPolicy = try InertiaValidationPolicy(symmetry: tolerance, physicalityRelative: 0)
        let source = try SourceProvenance(source: "runtime-carrier", revision: revision)
        let inertia = try InertialRepresentation3D(properties: MassProperties3D(mass: 1, centerOfMass: .zero,
            inertiaAtCenter: .identity, policy: inertiaPolicy), provenance: source, quality: .exact)
        let root = try BodyRecord3D(id: EntityID(kind: .body, key: "root"), frame: EntityID(kind: .frame, key: "root-frame"),
            mode: .static, bodyToWorld: .identity, representations: BodyRepresentations(), inertia: inertia)
        let descriptor = try MechanicalDescriptor(identity: "planar-carrier", revision: revision, bodies: [.spatial(root)], joints: [],
            root: root.id, rootBase: .fixed, rootAuthority: .fixed, worldFrame: EntityID(kind: .frame, key: "world"),
            initialState: KinematicState(revision: revision, time: 0, q: [], v: [], acceleration: []),
            representationRequirements: [], features: [], extensions: [])
        let policy = try CompilationPolicy(kinematicCapacity: KinematicCapacity(maximumBodies: 8, maximumVelocities: 32, maximumJacobianScalars: 1536),
            jointPolicy: JointEvaluationPolicy(quaternionTolerance: tolerance, chartRankRelative: 1e-9, characteristicLengthMeters: 1),
            inertiaPolicy: inertiaPolicy, translationTolerance: tolerance, rotationTolerance: tolerance, maximumRecords: 100,
            maximumIdentifierBytes: 10000, maximumSparsityEntries: 1000, maximumDependencyEntries: 1000,
            maximumExtensionRecords: 8, maximumDiagnostics: 8,
            extensionBudget: NumericalBudget(scalarStorage: 100, arithmeticOperations: 1000, iterations: 10), target: .nativeCPU)
        return try ReferenceMechanicalCompiler(extensions: NoMechanicalExtensions()).compile(descriptor, policy: policy)
    }
    static func codec(grid: PlanarGrid, model: ModelStamp) throws -> FixedPlanarContinuationCodec {
        try FixedPlanarContinuationCodec(grid: grid, model: model, contributorID: "planar-fluid", maximumBytes: 8192, divergenceTolerance: 1e-9)
    }
    static func changed(_ record: RuntimeContributorState, offset: Int, value: UInt64) throws -> RuntimeContributorState {
        var bytes = record.bytes
        for i in 0..<8 { bytes[offset+i] = UInt8(truncatingIfNeeded: value >> (8*i)) }
        return try RuntimeContributorState(id: record.id, category: record.category, version: record.version, bytes: bytes)
    }
    static func dynamicOffset(_ codec: FixedPlanarContinuationCodec) -> Int { codec.encodedSize-8*(4+3*codec.grid.count) }
    static func divergence(_ s: PlanarState, k: Int) -> Double {
        let g = s.grid, i = k % g.nx, j = k / g.nx
        return (s.u[j*g.nx+(i+1)%g.nx]-s.u[k])/g.dx+(s.v[((j+1)%g.ny)*g.nx+i]-s.v[k])/g.dy
    }
}
