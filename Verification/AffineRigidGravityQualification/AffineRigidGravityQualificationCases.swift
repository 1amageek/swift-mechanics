import SwiftMechanics

public enum AffineRigidGravityQualificationCases {
    private static func require(_ condition: Bool, _ message: String) throws(AffineRigidGravityQualificationError) {
        guard condition else { throw .assertion(message) }
    }
    private static func close(_ actual: Double, _ expected: Double, _ message: String,
                              tolerance: Double = 2e-9) throws(AffineRigidGravityQualificationError) {
        try require(actual.isFinite && expected.isFinite && abs(actual-expected) <= tolerance*max(1,abs(expected)), message)
    }
    private static func close(_ actual: Vector3, _ expected: Vector3, _ message: String,
                              tolerance: Double = 2e-9) throws(AffineRigidGravityQualificationError) {
        try close(actual.x,expected.x,message+" x",tolerance: tolerance)
        try close(actual.y,expected.y,message+" y",tolerance: tolerance)
        try close(actual.z,expected.z,message+" z",tolerance: tolerance)
    }
    private static func expect(_ expected: AffineRigidGravityFailure,
                               _ operation: () throws(AffineRigidGravityFailure) -> Void) throws(AffineRigidGravityQualificationError) {
        do throws(AffineRigidGravityFailure) { try operation() }
        catch {
            guard error == expected else { throw .unexpectedFailure(error) }
            return
        }
        throw .unexpectedSuccess("Expected original typed refusal")
    }
    private static func evaluate(_ input: AffineRigidGravityInput) throws -> AffineRigidGravityResponse {
        var work = try AffineRigidGravityQualificationFixture.work()
        let operation: any AffineRigidGravityEvaluating = ReferenceAffineRigidGravityEvaluator()
        return try operation.evaluate(input,policy: AffineRigidGravityQualificationFixture.policy(),work: &work)
    }
    private static func compare(_ fixture: AffineRigidGravityQualificationFixture,
                                _ response: AffineRigidGravityResponse) throws {
        let body = try response.input.snapshot.body(fixture.body)
        let atOrigin = try fixture.integral(response.input,reference: body.motion.pose.translation)
        let atCenter = try fixture.integral(response.input,reference: response.centerOfMassWorld)
        try close(response.force,atOrigin.force,"independent point resultant")
        try close(response.torqueAtCenterOfMass,atCenter.torque,"independent gradient COM moment")
        try close(response.wrenchAtBodyOrigin.torque,atOrigin.torque,"independent shifted origin moment")
        try close(response.potentialEnergy,atOrigin.potential,"complete point-integrated potential")
        try close(response.diagnostics.mechanicalPower,atOrigin.mechanicalPower,"point velocity power")
        try close(response.diagnostics.bodyOriginPower,atOrigin.mechanicalPower,"point origin work")
        try close(response.diagnostics.explicitPotentialTimeDerivative,atOrigin.explicitRate,"explicit point potential rate")
        try close(response.diagnostics.originTransportResidual,0,"original origin work residual")
        try close(response.diagnostics.conservativePowerResidual,0,"original continuum energy residual")
        let moment = try fixture.worldMomentIntegral(response.input,differentiated: false)
        let rate = try fixture.worldMomentIntegral(response.input,differentiated: true)
        for row in 0..<3 { for column in 0..<3 {
            try close(response.diagnostics.secondMomentWorld.element(row: row,column: column),
                      moment.element(row: row,column: column),"point-integrated world second moment")
            try close(response.diagnostics.secondMomentWorldRate.element(row: row,column: column),
                      rate.element(row: row,column: column),"point-velocity second moment rate")
        } }
    }

    public static func continuumPointIntegral() throws {
        let fixture = try AffineRigidGravityQualificationFixture()
        let input = try fixture.input(position: Vector3(0.8,-0.6,0.3),rotation: UnitQuaternion(axis: Vector3(1,2,-1),angle: 0.7),
                                      linearVelocity: Vector3(0.3,-0.4,0.2),bodyAngularVelocity: Vector3(0.7,-0.2,0.5))
        let response = try evaluate(input)
        try require(input.inertia.properties.inertiaAtCenter.m01 != 0 && input.inertia.properties.inertiaAtCenter.m02 != 0,
                    "Independent distribution must produce an original offdiagonal COM tensor")
        try compare(fixture,response)
        var q = Matrix3.zero
        for point in fixture.points {
            let r = try point.position.subtracting(fixture.center)
            q = try q.adding(Matrix3(r.x*r.x,r.x*r.y,r.x*r.z,r.y*r.x,r.y*r.y,r.y*r.z,
                                    r.z*r.x,r.z*r.y,r.z*r.z).scaled(by: point.mass))
        }
        for row in 0..<3 { for column in 0..<3 {
            try close(response.diagnostics.secondMomentBody.element(row: row,column: column),
                      q.element(row: row,column: column),"independent point second moment")
        } }
        let spherical = try MassProperties3D(mass: input.inertia.properties.mass,centerOfMass: fixture.center,
            inertiaAtCenter: .identity,policy: InertiaValidationPolicy(symmetry: NumericalTolerance(absolute: 0,relative: 0),physicalityRelative: 0))
        let alternate = AffineRigidGravityInput(snapshot: input.snapshot,
            inertia: try RigidBodyInertia(body: fixture.body,frame: input.inertia.frame,properties: spherical),field: input.field,
            expectedRevision: 1,expectedTimeSeconds: 2,gradientTimeDerivative: .zero)
        let isotropic = try evaluate(alternate)
        try close(isotropic.torqueAtCenterOfMass,.zero,"isotropic moment has zero gradient torque")
        try require(try response.torqueAtCenterOfMass.magnitude() > 0.01,"Gradient torque must detect actual complete tensor")
    }

    public static func properRotationCovariance() throws {
        let fixture = try AffineRigidGravityQualificationFixture()
        let rotation = try UnitQuaternion(axis: Vector3(1,2,-1),angle: 0.7)
        let position = try Vector3(0.8,-0.6,0.3), linear = try Vector3(0.3,-0.4,0.2), angular = try Vector3(0.7,-0.2,0.5)
        let first = try evaluate(fixture.input(position: position,rotation: rotation,linearVelocity: linear,bodyAngularVelocity: angular))
        let axes = try UnitQuaternion(axis: Vector3(1,-1,2),angle: 0.5), s = try axes.matrix()
        let raw = try s.multiplied(by: first.input.field.gradient).multiplied(by: s.transposed())
        let declared = try Matrix3(raw.m00,raw.m01,raw.m02,raw.m01,raw.m11,raw.m12,raw.m02,raw.m12,raw.m22)
        for row in 0..<3 { for column in 0..<3 {
            try close(raw.element(row: row,column: column),declared.element(row: row,column: column),"rotated field symmetry roundoff")
        } }
        let field = try AffineGravity(frame: first.input.field.frame,
            accelerationAtOrigin: axes.rotating(first.input.field.accelerationAtOrigin),gradient: declared)
        let second = try evaluate(fixture.input(position: axes.rotating(position),rotation: axes.multiplied(by: rotation),
            linearVelocity: axes.rotating(linear),bodyAngularVelocity: angular,field: field))
        try compare(fixture,second)
        try close(second.force,axes.rotating(first.force),"proper rotation force covariance")
        try close(second.torqueAtCenterOfMass,axes.rotating(first.torqueAtCenterOfMass),"proper rotation COM torque covariance")
        try close(second.wrenchAtBodyOrigin.torque,axes.rotating(first.wrenchAtBodyOrigin.torque),"proper rotation origin covariance")
        try close(second.potentialEnergy,first.potentialEnergy,"proper rotation potential invariant")
        try close(second.diagnostics.mechanicalPower,first.diagnostics.mechanicalPower,"proper rotation power invariant")
        let expected = try s.multiplied(by: first.diagnostics.secondMomentWorld).multiplied(by: s.transposed())
        for row in 0..<3 { for column in 0..<3 {
            try close(second.diagnostics.secondMomentWorld.element(row: row,column: column),
                      expected.element(row: row,column: column),"complete world moment covariance")
        } }
    }

    public static func potentialFiniteDifferences() throws {
        let fixture = try AffineRigidGravityQualificationFixture(), h = 1e-5
        let p = try Vector3(0.8,-0.6,0.3), r = try UnitQuaternion(axis: Vector3(1,2,-1),angle: 0.7)
        let current = try evaluate(fixture.input(position: p,rotation: r))
        for axis in [Vector3.unitX,.unitY,.unitZ] {
            let plus = try evaluate(fixture.input(position: p.adding(axis.scaled(by: h)),rotation: r))
            let minus = try evaluate(fixture.input(position: p.subtracting(axis.scaled(by: h)),rotation: r))
            try compare(fixture,plus); try compare(fixture,minus)
            try close(-(plus.potentialEnergy-minus.potentialEnergy)/(2*h),current.force.dot(axis),
                      "translation potential gradient",tolerance: 2e-7)
            let rotatedPlus = try evaluate(fixture.input(position: p,rotation: UnitQuaternion(axis: axis,angle: h).multiplied(by: r)))
            let rotatedMinus = try evaluate(fixture.input(position: p,rotation: UnitQuaternion(axis: axis,angle: -h).multiplied(by: r)))
            try compare(fixture,rotatedPlus); try compare(fixture,rotatedMinus)
            try close(-(rotatedPlus.potentialEnergy-rotatedMinus.potentialEnergy)/(2*h),current.wrenchAtBodyOrigin.torque.dot(axis),
                      "active world rotation potential gradient at body origin",tolerance: 2e-7)
        }
        let adot = try Vector3(0.2,-0.3,0.5), field = try fixture.field(timeDerivative: adot)
        let center = try evaluate(fixture.input(position: p,rotation: r,field: field))
        func shifted(_ dt: Double) throws -> AffineRigidGravityResponse {
            let sampled = try AffineGravity(frame: field.frame,accelerationAtOrigin: field.accelerationAtOrigin.adding(adot.scaled(by: dt)),
                gradient: field.gradient,uniformTimeDerivative: adot)
            return try evaluate(fixture.input(position: p,rotation: r,time: 2+dt,field: sampled))
        }
        let plus = try shifted(h), minus = try shifted(-h)
        try compare(fixture,plus); try compare(fixture,minus)
        try close((plus.potentialEnergy-minus.potentialEnergy)/(2*h),center.diagnostics.explicitPotentialTimeDerivative,
                  "explicit uniform time derivative",tolerance: 2e-7)
    }

    public static func independentInstantaneousPower() throws {
        let fixture = try AffineRigidGravityQualificationFixture(), h = 1e-5
        let p = try Vector3(0.8,-0.6,0.3), r = try UnitQuaternion(axis: Vector3(1,2,-1),angle: 0.7)
        let v = try Vector3(0.3,-0.4,0.2), omegaBody = try Vector3(0.7,-0.2,0.5), adot = try Vector3(0.2,-0.3,0.5)
        let field = try fixture.field(timeDerivative: adot)
        let response = try evaluate(fixture.input(position: p,rotation: r,linearVelocity: v,bodyAngularVelocity: omegaBody,field: field))
        try compare(fixture,response)
        let original = try fixture.integral(response.input,reference: p)
        try close(response.diagnostics.potentialTimeDerivative,original.explicitRate-original.mechanicalPower,
                  "point-integrated total potential rate")
        func alongMotion(_ dt: Double) throws -> AffineRigidGravityResponse {
            let sampledRotation = try r.multiplied(by: UnitQuaternion(rotationVector: omegaBody.scaled(by: dt)))
            let sampledField = try AffineGravity(frame: field.frame,accelerationAtOrigin: field.accelerationAtOrigin.adding(adot.scaled(by: dt)),
                gradient: field.gradient,uniformTimeDerivative: adot)
            return try evaluate(fixture.input(position: p.adding(v.scaled(by: dt)),rotation: sampledRotation,time: 2+dt,field: sampledField))
        }
        let plus = try alongMotion(h), minus = try alongMotion(-h)
        try close((plus.potentialEnergy-minus.potentialEnergy)/(2*h),response.diagnostics.potentialTimeDerivative,
                  "actual pose/field total rate finite difference",tolerance: 2e-7)
    }

    public static func originalKernelPrescribedPower() throws {
        let fixture = try AffineRigidGravityQualificationFixture(prescribed: true), input = try fixture.input()
        let response = try evaluate(input), operation: any AffineRigidGravityEvaluating = ReferenceAffineRigidGravityEvaluator()
        try compare(fixture,response)
        var loads = try AffineRigidGravityQualificationFixture.work(), work = try AffineRigidGravityQualificationFixture.numericalWork()
        let load = try operation.staticBodyWrench(response,otherGravityAppliedToBody: false,work: &loads)
        let dynamics = try RigidDynamicsInput(snapshot: input.snapshot,velocity: [0.7],inertias: fixture.inertias,gravity: nil,bodyWrenches: [load])
        let tolerance = try NumericalTolerance(absolute: 1e-10,relative: 1e-10)
        let admission = DynamicsAdmission(capacity: try DynamicsCapacity(maximumBodies: 2,maximumVelocities: 1,
            maximumBodyWrenches: 1,maximumGeneralizedContributions: 0),angularVelocityTolerance: tolerance,linearVelocityTolerance: tolerance)
        let kernel: any RigidEquationComputing = RigidEquationKernel()
        let system = try kernel.assemble(dynamics,admission: admission,loadWork: &loads,work: &work)
        let body = try input.snapshot.body(fixture.body), columns = try input.snapshot.geometricColumns(body: fixture.body)
        var jt = 0.0
        for point in fixture.points {
            let offset = try body.motion.pose.transforming(direction: point.position)
            let x = try body.motion.pose.translation.adding(offset)
            let force = try input.field.accelerationAtOrigin.adding(input.field.gradient.applying(to: x)).scaled(by: point.mass)
            jt += try force.dot(columns[columns.startIndex].velocity(at: offset))
        }
        let drift = try fixture.integral(input,reference: body.motion.pose.translation,drift: true)
        try close(system.forces.applied[0],jt,"original kernel point-force JT")
        try close(system.forces.actualPower,response.diagnostics.mechanicalPower,"original kernel actual power")
        try close(system.forces.prescribedPower,drift.mechanicalPower,"original point prescribed-anchor power")
        try close(system.forces.virtualPower,jt*0.7,"original generalized virtual power")
        try close(response.diagnostics.prescribedPower,drift.mechanicalPower,"returned original drift power")
        try close(response.diagnostics.virtualPower,jt*0.7,"returned original virtual power")
        let energy = try kernel.energy(system,acceleration: [0],angularMomentumReference: .zero,requireComplete: true,work: &work)
        guard let potential = energy.potentialEnergy else { throw AffineRigidGravityQualificationError.assertion("Static complete bridge lost potential") }
        try close(potential,response.potentialEnergy,"original kernel complete potential")
        try close(energy.gravityExplicitPotentialTimeDerivative,0,"static bridge introduces no temporal power")
        try require(system.forces.gravity == [0],"Bridge must not double-count the old gravity input")
    }

    public static func sourceAndDomainRefusals() throws {
        let fixture = try AffineRigidGravityQualificationFixture(), input = try fixture.input()
        let operation: any AffineRigidGravityEvaluating = ReferenceAffineRigidGravityEvaluator(), policy = try AffineRigidGravityQualificationFixture.policy()
        let wrongFrame = try EntityID(kind: .frame,key: "other-world")
        let wrongField = try AffineGravity(frame: wrongFrame,accelerationAtOrigin: .unitY,gradient: input.field.gradient)
        let wrongInertia = try RigidBodyInertia(body: input.inertia.body,frame: wrongFrame,properties: input.inertia.properties)
        let attempts: [(AffineRigidGravityInput,AffineRigidGravityFailure)] = [
            (AffineRigidGravityInput(snapshot: input.snapshot,inertia: input.inertia,field: input.field,
                expectedRevision: 2,expectedTimeSeconds: 2,gradientTimeDerivative: .zero),.staleSource),
            (AffineRigidGravityInput(snapshot: input.snapshot,inertia: input.inertia,field: input.field,
                expectedRevision: 1,expectedTimeSeconds: 3,gradientTimeDerivative: .zero),.staleSource),
            (AffineRigidGravityInput(snapshot: input.snapshot,inertia: input.inertia,field: wrongField,
                expectedRevision: 1,expectedTimeSeconds: 2,gradientTimeDerivative: .zero),.frameMismatch),
            (AffineRigidGravityInput(snapshot: input.snapshot,inertia: wrongInertia,field: input.field,
                expectedRevision: 1,expectedTimeSeconds: 2,gradientTimeDerivative: .zero),.frameMismatch),
            (AffineRigidGravityInput(snapshot: input.snapshot,inertia: input.inertia,field: input.field,
                expectedRevision: 1,expectedTimeSeconds: 2,gradientTimeDerivative: .identity),.unsupportedGradientTimeDerivative)]
        for (sample,failure) in attempts {
            var work = try AffineRigidGravityQualificationFixture.work()
            try expect(failure) { () throws(AffineRigidGravityFailure) in _ = try operation.evaluate(sample,policy: policy,work: &work) }
        }
        let dynamic = try evaluate(fixture.input(field: fixture.field(timeDerivative: .unitX)))
        let staticResponse = try evaluate(input)
        var work = try AffineRigidGravityQualificationFixture.work()
        try expect(.unsupportedTemporalWrenchBridge) { () throws(AffineRigidGravityFailure) in
            _ = try operation.staticBodyWrench(dynamic,otherGravityAppliedToBody: false,work: &work)
        }
        try expect(.duplicateGravityOwnership) { () throws(AffineRigidGravityFailure) in
            _ = try operation.staticBodyWrench(staticResponse,otherGravityAppliedToBody: true,work: &work)
        }
    }

    private static func metadataUnits(_ input: AffineRigidGravityInput) throws -> Int {
        let body = try input.snapshot.body(input.inertia.body), treeBody = input.snapshot.tree.bodies[try input.snapshot.tree.bodyIndex(input.inertia.body)]
        return [input.inertia.body.key,input.inertia.frame.key,input.field.frame.key,input.snapshot.tree.worldFrame.key,
                treeBody.frame.key,body.body.key,body.bodyFrame.key,body.worldFrame.key].reduce(0) { $0+$1.utf8.count }
    }

    @available(macOS 15.0, *)
    public static func exactWorkCapacityCancellation() throws {
        let fixture = try AffineRigidGravityQualificationFixture(), input = try fixture.input(), metadata = try metadataUnits(input)
        let total = metadata+1026, policy = try AffineRigidGravityQualificationFixture.policy()
        let operation: any AffineRigidGravityEvaluating = ReferenceAffineRigidGravityEvaluator()
        var exact = try AffineRigidGravityQualificationFixture.work(units: total+13)
        try exact.charge(13)
        let response = try operation.evaluate(input,policy: policy,work: &exact)
        try require(exact.consumed == total+13 && exact.peakScalars == 256,"Exact cumulative original work/storage accounting")
        var bridge = try AffineRigidGravityQualificationFixture.work(units: 16,scalars: 64)
        _ = try operation.staticBodyWrench(response,otherGravityAppliedToBody: false,work: &bridge)
        try require(bridge.consumed == 16 && bridge.peakScalars == 64,"Exact static bridge cost")
        var oneLess = try AffineRigidGravityQualificationFixture.work(units: total-1)
        try expect(.loads(.workExhausted)) { () throws(AffineRigidGravityFailure) in _ = try operation.evaluate(input,policy: policy,work: &oneLess) }
        try require(oneLess.consumed == total-1,"Actual original supplier admission failure retains exact prefix")
        var storage = try AffineRigidGravityQualificationFixture.work(scalars: 255)
        try expect(.loads(.capacityExceeded)) { () throws(AffineRigidGravityFailure) in _ = try operation.evaluate(input,policy: policy,work: &storage) }
        try require(storage.consumed == metadata && storage.peakScalars == 0,"Capacity failure precedes actual arithmetic")
        let short = try AffineRigidGravityQualificationFixture.policy(identityBytes: input.inertia.body.key.utf8.count-1)
        var identifier = try AffineRigidGravityQualificationFixture.work()
        try expect(.loads(.capacityExceeded)) { () throws(AffineRigidGravityFailure) in _ = try operation.evaluate(input,policy: short,work: &identifier) }
        try require(identifier.consumed == input.inertia.body.key.utf8.count-1,"Metadata traversal stops at exact caller bound")
        let pair = try AffineRigidGravityQualificationFixture(prescribed: true), pairInput = try pair.input()
        let small = try AffineRigidGravityQualificationFixture.policy(bodies: 1)
        var bodies = try AffineRigidGravityQualificationFixture.work()
        try expect(.loads(.capacityExceeded)) { () throws(AffineRigidGravityFailure) in _ = try operation.evaluate(pairInput,policy: small,work: &bodies) }
        try require(bodies.consumed == 0,"Body capacity precedes metadata/supplier")
        var cancelled = try AffineRigidGravityQualificationFixture.work(cancelled: { true })
        try expect(.loads(.cancelled)) { () throws(AffineRigidGravityFailure) in _ = try operation.evaluate(input,policy: policy,work: &cancelled) }
        try require(cancelled.consumed == 0,"Pre-admission cancellation consumes no work")
        let counter = AffineRigidGravityQualificationCancellation(cancelAt: metadata+6)
        var late = try AffineRigidGravityQualificationFixture.work(cancelled: { counter.isCancelled() })
        try expect(.loads(.cancelled)) { () throws(AffineRigidGravityFailure) in _ = try operation.evaluate(input,policy: policy,work: &late) }
        try require(late.consumed == total,"Final cancellation retains completed numerical/supplier work")
    }

    public static func originalSupplierAndMomentRefusals() throws {
        let fixture = try AffineRigidGravityQualificationFixture(), input = try fixture.input()
        let policy = try AffineRigidGravityQualificationFixture.policy(), operation: any AffineRigidGravityEvaluating = ReferenceAffineRigidGravityEvaluator()
        let huge = try AffineGravity(frame: input.field.frame,accelerationAtOrigin: Vector3(Double.greatestFiniteMagnitude,0,0))
        let overflow = AffineRigidGravityInput(snapshot: input.snapshot,inertia: input.inertia,field: huge,
            expectedRevision: 1,expectedTimeSeconds: 2,gradientTimeDerivative: .zero)
        var work = try AffineRigidGravityQualificationFixture.work()
        try expect(.loads(.core(.nonFiniteResult))) { () throws(AffineRigidGravityFailure) in _ = try operation.evaluate(overflow,policy: policy,work: &work) }
        try require(work.consumed == (try metadataUnits(input))+1026,"Original gravity overflow retains actual supplier work")
        let properties = try MassProperties3D(mass: 1,centerOfMass: .zero,inertiaAtCenter: Matrix3(10,0,0,0,1,0,0,0,1),
            policy: InertiaValidationPolicy(symmetry: NumericalTolerance(absolute: 0,relative: 0),physicalityRelative: 0.5))
        let invalid = AffineRigidGravityInput(snapshot: input.snapshot,
            inertia: try RigidBodyInertia(body: input.inertia.body,frame: input.inertia.frame,properties: properties),field: input.field,
            expectedRevision: 1,expectedTimeSeconds: 2,gradientTimeDerivative: .zero)
        var moment = try AffineRigidGravityQualificationFixture.work()
        try expect(.nonphysicalSecondMoment) { () throws(AffineRigidGravityFailure) in _ = try operation.evaluate(invalid,policy: policy,work: &moment) }
        try require(moment.consumed == (try metadataUnits(input))+1024,"Physical moment refusal occurs before point supplier")
    }
}
