import SwiftMechanics

@available(macOS 15.0, *)
public struct SpatialBeamsQualificationCases: SpatialBeamsQualifying, Sendable {
    private typealias F = SpatialBeamsQualificationFixtures
    private typealias E = SpatialBeamsQualificationError
    public init() {}
    public func run(_ selected: SpatialBeamsQualificationCase) throws(SpatialBeamsQualificationError) {
        switch selected {
        case .axialAndTorsion: try axialAndTorsion()
        case .bendingAndShear: try bendingAndShear()
        case .massAndDamping: try massAndDamping()
        case .frameFieldsAndPower: try frameFieldsAndPower()
        case .originalRefusals: try originalRefusals()
        case .resourcesAndCancellation: try resourcesAndCancellation()
        }
    }
    private func axialAndTorsion() throws(E) {
        for formulation in [SpatialBeamFormulation.eulerBernoulli, .timoshenko] {
            let beam = try F.beam(formulation: formulation), assembly = try F.assemble(beam)
            try F.require(assembly.beam == beam, "assembly source retained")
            try F.near(assembly.frame.length, 2, "physical reference length")
            try F.near(assembly.elasticStiffness, F.stiffness(timoshenko: formulation == .timoshenko), "closed12DOF stiffness")
            var q = [Double](repeating: 0, count: 12), v = q
            q[6] = 0.002; q[9] = 0.004; v[6] = 0.003; v[9] = 0.006
            let state = try F.state(beam, q, v), response = try F.response(assembly, state)
            var gradient = [Double](repeating: 0, count: 12)
            gradient[0] = -0.024; gradient[6] = 0.024; gradient[3] = -0.00003; gradient[9] = 0.00003
            try F.near(response.energyGradient, gradient, "axial/torsional gradient")
            try F.near(response.elasticRestoringForce, gradient.map { -$0 }, "restoring sign")
            try F.near(response.strainEnergy, 0.00002406, "axial/torsional original energy")
            try F.near(response.elasticPower, 0.00007218, "axial/torsional power")
            try F.near(response.positiveEnergyTangent, F.stiffness(timoshenko: formulation == .timoshenko), "energy tangent")
            let field = try F.field(assembly, state, xi: 0.5)
            try F.near(field.sectionEngineeringStrain, [0.001, 0, 0, 0.002, 0, 0], "axial/twist strain")
            try F.near(field.sectionForceInLocal.x, 0.024, "axial resultant")
            try F.near(field.sectionMomentInLocal.x, 0.00003, "torsional resultant")
            try F.near(field.fiberAxialCauchyStress, 1.2, "linear axial Cauchy stress")
            for mode in 0..<6 {
                var rigid = [Double](repeating: 0, count: 12)
                if mode < 3 { rigid[mode] = 0.01; rigid[mode + 6] = 0.01 }
                else {
                    rigid[mode] = 0.01; rigid[mode + 6] = 0.01
                    if mode == 4 { rigid[8] = -0.02 }
                    if mode == 5 { rigid[7] = 0.02 }
                }
                try F.near(F.action(assembly.elasticStiffness, rigid), [Double](repeating: 0, count: 12), "rigid null action")
                let result = try F.response(assembly, F.state(beam, rigid))
                try F.near(result.strainEnergy, 0, "rigid strain energy")
            }
        }
    }
    private func bendingAndShear() throws(E) {
        let p = 1e-5
        for formulation in [SpatialBeamFormulation.eulerBernoulli, .timoshenko] {
            let beam = try F.beam(formulation: formulation), assembly = try F.assemble(beam)
            for plane in 0..<2 {
                let ei = plane == 0 ? 0.048 : 0.024, shear = plane == 0 ? 8.0 : 6.0
                let displacement = p * 8 / (3 * ei) + (formulation == .timoshenko ? p * 2 / shear : 0)
                let rotation = p * 4 / (2 * ei), sign = plane == 0 ? 1.0 : -1.0
                var q = [Double](repeating: 0, count: 12)
                q[plane + 7] = displacement; q[plane == 0 ? 11 : 10] = sign * rotation
                let state = try F.state(beam, q, q.map { 2 * $0 }), response = try F.response(assembly, state)
                var gradient = [Double](repeating: 0, count: 12)
                gradient[plane + 1] = -p; gradient[plane + 7] = p
                gradient[plane == 0 ? 5 : 4] = -sign * 2 * p
                try F.near(response.energyGradient, gradient, "cantilever force/moment")
                try F.near(response.strainEnergy, 0.5 * p * displacement, "independent cantilever compliance energy")
                try F.near(response.elasticPower, 2 * p * displacement, "independent cantilever power")
                for xi in [0.0, 0.25, 0.5, 1.0] {
                    let x = 2 * xi, field = try F.field(assembly, state, xi: xi)
                    let gamma = formulation == .timoshenko ? p / shear : 0
                    try F.near(field.sectionEngineeringStrain[plane + 1], gamma, "selected constant shear")
                    try F.near(field.sectionEngineeringStrain[plane == 0 ? 5 : 4], sign * p * (2 - x) / ei, "cantilever moment curvature")
                    let force = plane == 0 ? field.sectionForceInLocal.y : field.sectionForceInLocal.z
                    let moment = plane == 0 ? field.sectionMomentInLocal.z : field.sectionMomentInLocal.y
                    try F.near(force, p, "physical section shear")
                    try F.near(moment, sign * p * (2 - x), "physical section moment")
                    let transverse = plane == 0 ? field.rigidSectionFiberDisplacementInReference.y : field.rigidSectionFiberDisplacementInReference.z
                    let physical = p * x * x * (6 - x) / (6 * ei) + gamma * x
                    try F.near(transverse, physical, "independent cantilever centerline displacement")
                    try F.require(field.transverseShearResultantProjection == (formulation == .eulerBernoulli ? .equilibriumMomentGradient : .unaveragedConstitutive), "shear projection authority")
                }
            }
        }
    }
    private func massAndDamping() throws(E) {
        for formulation in [SpatialBeamFormulation.eulerBernoulli, .timoshenko] {
            for mass in [SpatialBeamMassForm.consistent, .endpointLumped] {
                let beam = try F.beam(formulation: formulation, mass: mass), assembly = try F.assemble(beam)
                let q = [Double](repeating: 0, count: 12); var v = q
                v[0] = 0.02; v[6] = 0.04; v[3] = 0.03; v[9] = 0.06
                let translational = mass == .consistent ? 0.5 * 0.12 / 3 * (0.0004 + 0.0008 + 0.0016) : 0.5 * 0.12 / 2 * (0.0004 + 0.0016)
                let rotary = mass == .consistent ? 0.5 * 0.00036 / 3 * (0.0009 + 0.0018 + 0.0036) : 0.5 * 0.00036 / 2 * (0.0009 + 0.0036)
                try F.near(F.response(assembly, F.state(beam, q, v)).kineticEnergy, translational + rotary, "linear axial/twist kinetic integral")
                v = q; v[7] = 0.04; v[5] = 0.02; v[11] = 0.02
                let expected = mass == .consistent ? 0.000032048 : 0.000048048
                let response = try F.response(assembly, F.state(beam, q, v))
                try F.near(response.kineticEnergy, expected, "rigid Z-rotation distributed or endpoint kinetic integral")
                try F.near(F.dot(v, F.action(assembly.mass, v)), 2 * expected, "physical mass action")
                for i in 0..<12 { for k in 0..<12 {
                    try F.near(assembly.mass[i * 12 + k], assembly.mass[k * 12 + i], "mass symmetry")
                    if mass == .endpointLumped && i != k { try F.near(assembly.mass[i * 12 + k], 0, "endpoint diagonal") }
                } }
            }
        }
        let beam = try F.beam(alpha: 0.2, beta: 0.3), assembly = try F.assemble(beam)
        var q = [Double](repeating: 0, count: 12), v = q; q[6] = 0.002; v[6] = 0.003
        let response = try F.response(assembly, F.state(beam, q, v))
        try F.near(response.kineticEnergy, 0.00000018, "independent axial kinetic energy")
        try F.near(response.dampingDissipation, 0.000032472, "independent Rayleigh dissipation")
        var force = [Double](repeating: 0, count: 12); force[0] = 0.010788; force[6] = -0.010824
        try F.near(response.dampingForce, force, "physical damping nodal force")
        try F.near(-F.dot(force, v), 0.000032472, "damping force power")
        let elastic = F.stiffness(timoshenko: false)
        for i in 0..<144 { try F.near(assembly.damping[i], 0.2 * assembly.mass[i] + 0.3 * elastic[i], "reference Rayleigh identity") }
        v = [Double](repeating: 0, count: 12); v[0] = 0.01; v[6] = 0.01
        let rigid = try F.response(assembly, F.state(beam, [Double](repeating: 0, count: 12), v))
        try F.near(rigid.dampingDissipation, 0.0000024, "mass damping of rigid translation is explicit")
    }
    private func frameFieldsAndPower() throws(E) {
        let virtual = [-0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9, 1, 1.1, 1.2]
        var local = [Double](repeating: 0, count: 12)
        local[6] = 0.002; local[7] = 0.002; local[9] = 0.004; local[11] = 0.002
        for formulation in [SpatialBeamFormulation.eulerBernoulli, .timoshenko] {
            let original = try F.beam(formulation: formulation), originalAssembly = try F.assemble(original)
            let originalResult = try F.response(originalAssembly, F.state(original, local, local.map { 2 * $0 }))
            let beam = try F.beam(formulation: formulation, rotated: true), assembly = try F.assemble(beam)
            let q = F.rotate(local), v = q.map { 2 * $0 }, state = try F.state(beam, q, v)
            let response = try F.response(assembly, state), field = try F.field(assembly, state, xi: 0.25, y: 0.05, z: 0.04)
            try F.require(response.beam == beam && field.beam == beam, "exact field/source/location")
            let expectedLocation = try F.producer { () throws(SpatialBeamError) in try SpatialBeamLocation(xi: 0.25, y: 0.05, z: 0.04) }
            try F.require(field.location == expectedLocation, "exact field/source/location")
            try F.near(response.energyGradient, F.rotate(originalResult.energyGradient), "force/moment covariance")
            try F.near(response.strainEnergy, 0.000024108, "constant strain energy")
            try F.near(response.elasticPower, 0.000096432, "constant strain physical power")
            try F.near(F.dot(response.energyGradient, F.rotate(virtual)), 0.0192468, "arbitrary original virtual work")
            try F.near(F.dot(originalResult.energyGradient, virtual), 0.0192468, "local virtual work")
            try F.near(field.sectionEngineeringStrain, [0.001, 0, 0, 0.002, 0, 0.001], "constant original strain")
            try F.near(field.fiberAxialEngineeringStrain, 0.00095, "fiber axial strain")
            try F.near(field.fiberAxialCauchyStress, 1.14, "fiber linear Cauchy stress")
            try F.near(field.strainEnergyPerReferenceLength, 0.000012054, "constitutive energy per length")
            try F.near([field.sectionForceInReference.x, field.sectionForceInReference.y, field.sectionForceInReference.z], [0, 0.024, 0], "field reference force")
            try F.near([field.sectionMomentInReference.x, field.sectionMomentInReference.y, field.sectionMomentInReference.z], [0, 0.00003, 0.000048], "field reference moment")
            try F.near([field.fiberReferencePosition.x, field.fiberReferencePosition.y, field.fiberReferencePosition.z], [0.95, 2.5, 3.04], "identified original fiber position")
            try F.near([field.rigidSectionFiberDisplacementInReference.x, field.rigidSectionFiberDisplacementInReference.y, field.rigidSectionFiberDisplacementInReference.z], [-0.000085, 0.000475, 0.00005], "rigid section displacement")
            try F.require(field.axialStressMeasure == .linearAxialCauchyStress && field.axialStressProjection == .unaveragedConstitutive && field.displacementProjection == .unaveragedRigidSectionKinematics, "explicit field fidelity")
            let permutation = [1, 0, 2], sign = [-1.0, 1, 1]
            for i in 0..<12 { for k in 0..<12 {
                let a = i / 3 * 3 + permutation[i % 3], b = k / 3 * 3 + permutation[k % 3]
                try F.near(assembly.elasticStiffness[i * 12 + k], sign[i % 3] * sign[k % 3] * originalAssembly.elasticStiffness[a * 12 + b], "independent stiffness covariance")
                try F.near(assembly.mass[i * 12 + k], sign[i % 3] * sign[k % 3] * originalAssembly.mass[a * 12 + b], "independent mass covariance")
            } }
        }
    }
    private func originalRefusals() throws(E) {
        let beam = try F.beam(), assembly = try F.assemble(beam), admission = try F.admission()
        let assembler: any SpatialBeamAssembling = ReferenceSpatialBeamAssembler()
        let evaluator: any SpatialBeamEvaluating = ReferenceSpatialBeamEvaluator()
        var work = try F.work(); let zero = [Double](repeating: 0, count: 12), state = try F.state(beam, zero)
        let finiteRotation = try F.beam(formulation: .finiteRotation)
        try F.expect(.unsupportedFiniteRotation, "finite rotation") { () throws(SpatialBeamError) in _ = try assembler.assemble(finiteRotation, admission: admission, work: &work) }
        let location = try F.producer { () throws(SpatialBeamError) in try SpatialBeamLocation(xi: 0.5, y: 0, z: 0) }
        try F.expect(.unsupportedResolvedSectionStress, "resolved section stress") { () throws(SpatialBeamError) in _ = try evaluator.field(assembly, state: state, location: location, stress: .resolvedSection, admission: admission, work: &work) }
        let stale = try F.state(F.beam(revision: 8), zero)
        try F.expect(.invalidInput(parameter: "stateSource"), "stale source") { () throws(SpatialBeamError) in _ = try evaluator.evaluate(assembly, state: stale, admission: admission, work: &work) }
        let degenerate = try F.beam(zeroLength: true)
        try F.expect(.invalidInput(parameter: "zeroLength"), "degenerate geometry") { () throws(SpatialBeamError) in _ = try assembler.assemble(degenerate, admission: admission, work: &work) }
        let collinear = try F.beam(collinear: true)
        try F.expect(.invalidInput(parameter: "principalDirectionCondition"), "collinear orientation") { () throws(SpatialBeamError) in _ = try assembler.assemble(collinear, admission: admission, work: &work) }
        let slender = try F.admission(minimumSlenderness: 100)
        try F.domain("minimumSlenderness") { () throws(SpatialBeamError) in _ = try assembler.assemble(beam, admission: slender, work: &work) }
        let upper = try F.admission(maximumSlenderness: 10)
        try F.domain("maximumSlenderness") { () throws(SpatialBeamError) in _ = try assembler.assemble(beam, admission: upper, work: &work) }
        var q = zero; q[6] = 2; let strained = try F.state(beam, q)
        try F.domain("fiberAxialStrainBound") { () throws(SpatialBeamError) in _ = try evaluator.evaluate(assembly, state: strained, admission: admission, work: &work) }
        q = zero; q[7] = 0.8; let interior = try F.state(beam, q)
        try F.domain("rotationL1Bound") { () throws(SpatialBeamError) in _ = try evaluator.evaluate(assembly, state: interior, admission: admission, work: &work) }
        let outside = try F.producer { () throws(SpatialBeamError) in try SpatialBeamLocation(xi: 0.5, y: 0.101, z: 0) }
        try F.expect(.invalidInput(parameter: "sectionLocationBounds"), "section location") { () throws(SpatialBeamError) in _ = try evaluator.field(assembly, state: state, location: outside, stress: .axialNormal, admission: admission, work: &work) }
        try F.expect(.invalidInput(parameter: "fieldLocation"), "nonfinite location") { () throws(SpatialBeamError) in _ = try SpatialBeamLocation(xi: .nan, y: 0, z: 0) }
        try F.expect(.invalidInput(parameter: "beamState"), "count") { () throws(SpatialBeamError) in _ = try SpatialBeamState(beam: beam, displacement: [], velocity: zero) }
        var nonfinite = zero; nonfinite[3] = .infinity
        try F.expect(.invalidInput(parameter: "beamState"), "nonfinite coordinates") { () throws(SpatialBeamError) in _ = try SpatialBeamState(beam: beam, displacement: nonfinite, velocity: zero) }
        try F.expect(.invalidInput(parameter: "isotropicModulusRatio"), "isotropic material domain") { () throws(SpatialBeamError) in _ = try SpatialBeamMaterial(identity: beam.material.identity, source: beam.material.source, youngModulus: 1500, shearModulus: 500, density: 3) }
        try F.expect(.invalidInput(parameter: "sectionMomentBounds"), "section physical bounds") { () throws(SpatialBeamError) in _ = try SpatialBeamSection(source: beam.section.source, area: 0.02, secondMomentY: 1, secondMomentZ: 0.00004, torsionConstant: 0.00003, shearFactorY: 0.8, shearFactorZ: 0.6, outerHalfY: 0.1, outerHalfZ: 0.1) }
        try F.expect(.material(.invalidParameter(name: "bulkModulus")), "original material supplier failure") { () throws(SpatialBeamError) in _ = try SpatialBeamMaterial(identity: beam.material.identity, source: beam.material.source, youngModulus: 1e308, shearModulus: 1e308 / 2.999, density: 3) }
        var velocity = zero; velocity[6] = 1e308; let overflow = try F.state(beam, zero, velocity)
        try F.expect(.nonFiniteResult, "physical form overflow") { () throws(SpatialBeamError) in _ = try evaluator.evaluate(assembly, state: overflow, admission: admission, work: &work) }
    }
    private func resourcesAndCancellation() throws(E) {
        let beam = try F.beam(), assembler: any SpatialBeamAssembling = ReferenceSpatialBeamAssembler()
        let evaluator: any SpatialBeamEvaluating = ReferenceSpatialBeamEvaluator()
        let normal = try F.admission(), bytes = F.metadataBytes(beam)
        var work = try F.work(); let assembly = try F.producer { () throws(SpatialBeamError) in try assembler.assemble(beam, admission: normal, work: &work) }
        try F.require(work.operations == bytes + 50_020 && work.peakScalarStorage == 2304, "independent assembly work reservations")
        let state = try F.state(beam, [Double](repeating: 0, count: 12))
        work = try F.work(); _ = try F.producer { () throws(SpatialBeamError) in try evaluator.evaluate(assembly, state: state, admission: normal, work: &work) }
        try F.require(work.operations == bytes + 20_180 && work.peakScalarStorage == 4096, "independent response work reservations")
        let small = try F.admission(bytes: bytes - 1); work = try F.work()
        try F.expect(.capacityExceeded, "metadata byte cap") { () throws(SpatialBeamError) in _ = try assembler.assemble(beam, admission: small, work: &work) }
        try F.require(work.operations == bytes - 1, "metadata spent prefix")
        work = try F.work(storage: 2303)
        try F.expect(.numerical(.resourceLimit(resource: .scalarStorage, limit: 2303)), "assembly storage cap") { () throws(SpatialBeamError) in _ = try assembler.assemble(beam, admission: normal, work: &work) }
        work = try F.work(storage: 4095)
        try F.expect(.numerical(.resourceLimit(resource: .scalarStorage, limit: 4095)), "response storage cap") { () throws(SpatialBeamError) in _ = try evaluator.evaluate(assembly, state: state, admission: normal, work: &work) }
        let limit = bytes + 50_019; work = try F.work(operations: limit)
        try F.expect(.numerical(.resourceLimit(resource: .arithmeticOperations, limit: limit)), "operation cap") { () throws(SpatialBeamError) in _ = try assembler.assemble(beam, admission: normal, work: &work) }
        try F.require(work.operations > 0 && work.operations < limit, "operation spent prefix retained")
        let early = try F.admission(cancelled: { true }); work = try F.work()
        try F.expect(.cancelled, "early cancel") { () throws(SpatialBeamError) in _ = try assembler.assemble(beam, admission: early, work: &work) }
        try F.require(work.operations == 0 && work.peakScalarStorage == 0, "cancel before allocation")
        let counter = SpatialBeamsCancellationCounter(), counted = try F.admission(cancelled: { counter.checkpoint() })
        work = try F.work(); _ = try F.producer { () throws(SpatialBeamError) in try assembler.assemble(beam, admission: counted, work: &work) }
        let last = SpatialBeamsCancellationCounter(limit: counter.count), late = try F.admission(cancelled: { last.checkpoint() })
        work = try F.work()
        try F.expect(.cancelled, "last assembly checkpoint") { () throws(SpatialBeamError) in _ = try assembler.assemble(beam, admission: late, work: &work) }
        try F.require(work.operations == bytes + 50_020 && last.count == counter.count, "assembly no partial publication")
        let responseCounter = SpatialBeamsCancellationCounter(), countedResponse = try F.admission(cancelled: { responseCounter.checkpoint() })
        work = try F.work(); _ = try F.producer { () throws(SpatialBeamError) in try evaluator.evaluate(assembly, state: state, admission: countedResponse, work: &work) }
        let final = SpatialBeamsCancellationCounter(limit: responseCounter.count), finalAdmission = try F.admission(cancelled: { final.checkpoint() }); work = try F.work()
        try F.expect(.cancelled, "last response checkpoint") { () throws(SpatialBeamError) in _ = try evaluator.evaluate(assembly, state: state, admission: finalAdmission, work: &work) }
        try F.require(work.operations == bytes + 20_180 && final.count == responseCounter.count, "response no partial publication")
    }
    public func taskCancellationEntry() throws(SpatialBeamsQualificationError) -> @Sendable () throws(SpatialBeamsQualificationError) -> Void {
        let beam = try F.beam(), assembly = try F.assemble(beam)
        let state = try F.state(beam, [Double](repeating: 0, count: 12))
        return { () throws(E) in
            let admission = try F.admission(cancelled: { Task.isCancelled })
            var work = try F.work(); let evaluator: any SpatialBeamEvaluating = ReferenceSpatialBeamEvaluator()
            try F.expect(.cancelled, "actual awaited Task cancellation") { () throws(SpatialBeamError) in
                _ = try evaluator.evaluate(assembly, state: state, admission: admission, work: &work)
            }
            try F.require(work.operations == 0, "Task cancellation preserves zero prefix")
        }
    }
}
