import SwiftMechanics

public enum InertialParametersQualificationOracle {
    public static func require(_ condition: Bool, _ label: String) throws {
        guard condition else { throw InertialParametersQualificationError.assertion(label) }
    }
    public static func close(_ actual: Double, _ expected: Double, _ label: String,
                             finiteDifference: Bool = false) throws {
        let absolute = finiteDifference ? 2e-7 : 2e-10
        let relative = finiteDifference ? 2e-6 : 2e-10
        try require(actual.isFinite && expected.isFinite && abs(actual-expected) <= absolute+relative*max(abs(actual), abs(expected)), label)
    }
    public static func array(_ actual: [Double], _ expected: [Double], _ label: String,
                             finiteDifference: Bool = false) throws {
        try require(actual.count == expected.count, label + " shape")
        for i in actual.indices { try close(actual[i], expected[i], label + " slot \(i)", finiteDifference: finiteDifference) }
    }

    /// Explicit parameter-chart endpoint construction; no derivative conversion is used.
    public static func endpoint(_ input: MechanicalDerivativeInput, bindings: [RigidInertialParameterBinding],
                                direction: [RigidInertialParameterDirection], delta: Double) throws -> MechanicalDerivativeInput {
        var inertias: [RigidBodyInertia] = []
        for i in bindings.indices {
            let b = bindings[i], d = direction[i], m = b.representation.properties.mass + delta*d.mass
            let hx = b.firstMoment.x + delta*d.firstMoment.x
            let hy = b.firstMoment.y + delta*d.firstMoment.y
            let hz = b.firstMoment.z + delta*d.firstMoment.z
            let x = hx/m, y = hy/m, z = hz/m
            let a = b.inertiaAtOrigin, da = d.inertiaAtOrigin
            let central = try Matrix3(
                a.m00+delta*da.m00-m*(y*y+z*z), a.m01+delta*da.m01+m*x*y, a.m02+delta*da.m02+m*x*z,
                a.m10+delta*da.m10+m*x*y, a.m11+delta*da.m11-m*(x*x+z*z), a.m12+delta*da.m12+m*y*z,
                a.m20+delta*da.m20+m*x*z, a.m21+delta*da.m21+m*y*z, a.m22+delta*da.m22-m*(x*x+y*y))
            let properties = try MassProperties3D(mass: m, centerOfMass: Vector3(x, y, z), inertiaAtCenter: central,
                policy: InertialParametersQualificationFixture.validation())
            inertias.append(try RigidBodyInertia(body: input.inertias[i].body, frame: input.inertias[i].frame, properties: properties))
        }
        return MechanicalDerivativeInput(tree: input.tree, state: input.state, inertias: inertias, gravity: input.gravity,
            bodyWrenches: input.bodyWrenches, generalizedForces: input.generalizedForces, drive: input.drive)
    }

    public static func primal(_ input: MechanicalDerivativeInput, fixture: InertialParametersQualificationFixture) throws
        -> (system: RigidDynamicsSystem, inverse: DynamicsSolution, forward: DynamicsSolution, energy: MechanicalEnergy) {
        let kinematics: any TreeKinematicsComputing = TreeKinematicsEvaluator()
        let snapshot = try kinematics.evaluate(input.tree, state: input.state, policy: fixture.jointPolicy)
        let equations: any RigidEquationComputing = RigidEquationKernel()
        let solver: any RigidDynamicsSolving = DenseRigidDynamics(equations: equations)
        var work = try InertialParametersQualificationFixture.work(), loads = try InertialParametersQualificationFixture.loads()
        let assembled = try equations.assemble(RigidDynamicsInput(snapshot: snapshot, velocity: input.state.v,
            inertias: input.inertias, gravity: input.gravity, bodyWrenches: input.bodyWrenches, generalizedForces: input.generalizedForces),
            admission: fixture.admission, loadWork: &loads, work: &work)
        let inverse = try solver.inverse(assembled, acceleration: input.state.acceleration, policy: fixture.solvePolicy, work: &work)
        let forward = try solver.forward(assembled, driveForce: input.drive, policy: fixture.solvePolicy, work: &work)
        let energy = try equations.energy(assembled, acceleration: input.state.acceleration, angularMomentumReference: .zero,
            requireComplete: false, work: &work)
        try require(inverse.originalPhysicalResidual.isAccepted && forward.originalPhysicalResidual.isAccepted,
            "Independent original physical residual")
        var inertialPower = 0.0, loadPower = 0.0
        for i in input.state.v.indices {
            var required = assembled.inertialBias[i]
            for j in input.state.v.indices { required += assembled.massMatrix[i*input.state.v.count+j]*input.state.acceleration[j] }
            inertialPower += required*input.state.v[i]
            loadPower += try assembled.forces.total(at: i)*input.state.v[i]
        }
        try close(energy.kineticEnergyRate, inertialPower, "Original kinetic power")
        try close(energy.requiredVirtualPower, inertialPower, "Original virtual power")
        try close(energy.requiredPrescribedPower, 0, "Fixed-root prescribed power")
        try close(assembled.forces.actualPower, loadPower, "Original actual load power")
        try close(assembled.forces.virtualPower, loadPower, "Original virtual load power")
        return (assembled, inverse, forward, energy)
    }

    public static func differences(_ fixture: InertialParametersQualificationFixture,
                                   direction: [RigidInertialParameterDirection], forward: Bool = false) throws {
        let product = try fixture.product(direction)
        try require(product.originalResidual <= product.originalThreshold && product.primalInverse.originalPhysicalResidual.isAccepted,
            "Subject original inverse residual")
        var acceleration: InertialParameterAccelerationProduct?
        if forward { acceleration = try fixture.forward(direction) }
        for h in [1e-5, 5e-6] {
            let plus = try primal(endpoint(fixture.input.primal, bindings: fixture.input.bindings, direction: direction, delta: h), fixture: fixture)
            let minus = try primal(endpoint(fixture.input.primal, bindings: fixture.input.bindings, direction: direction, delta: -h), fixture: fixture)
            let factor = 0.5/h
            try array(product.mechanics.massMatrix, difference(plus.system.massMatrix, minus.system.massMatrix, factor), "FD mass", finiteDifference: true)
            try array(product.mechanics.inertialBias, difference(plus.system.inertialBias, minus.system.inertialBias, factor), "FD bias", finiteDifference: true)
            var df: [Double] = []
            for i in fixture.input.primal.state.v.indices { df.append(try (plus.system.forces.total(at: i)-minus.system.forces.total(at: i))*factor) }
            try array(product.mechanics.totalForce, df, "FD generalized force", finiteDifference: true)
            try array(product.requiredDriveDirection, difference(plus.inverse.driveForce, minus.inverse.driveForce, factor), "FD inverse effort", finiteDifference: true)
            try close(product.mechanics.kineticEnergy, (plus.energy.kineticEnergy-minus.energy.kineticEnergy)*factor, "FD kinetic energy", finiteDifference: true)
            try close(product.mechanics.gravityPotential, (plus.system.gravityPotential-minus.system.gravityPotential)*factor, "FD gravity potential", finiteDifference: true)
            try close(product.mechanics.actualLoadPower, (plus.system.forces.actualPower-minus.system.forces.actualPower)*factor, "FD actual power", finiteDifference: true)
            try close(product.mechanics.virtualLoadPower, (plus.system.forces.virtualPower-minus.system.forces.virtualPower)*factor, "FD virtual power", finiteDifference: true)
            try close(product.mechanics.prescribedLoadPower, (plus.system.forces.prescribedPower-minus.system.forces.prescribedPower)*factor, "FD prescribed power", finiteDifference: true)
            if let acceleration {
                try array(acceleration.dynamics.acceleration, difference(plus.forward.acceleration, minus.forward.acceleration, factor), "FD forward acceleration", finiteDifference: true)
                try require(acceleration.dynamics.originalResidual <= acceleration.dynamics.originalThreshold &&
                    acceleration.dynamics.primal.originalPhysicalResidual.isAccepted, "Subject original forward residual")
            }
        }
    }
    private static func difference(_ plus: [Double], _ minus: [Double], _ factor: Double) -> [Double] {
        var result: [Double] = []
        for i in plus.indices { result.append((plus[i]-minus[i])*factor) }
        return result
    }
}
