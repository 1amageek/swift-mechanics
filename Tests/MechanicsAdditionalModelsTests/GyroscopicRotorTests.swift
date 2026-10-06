import Testing
import SwiftMechanics

@Suite struct GyroscopicRotorTests {
    let service: any GyroscopicRotorEvaluating = GyroscopicRotorEvaluator()
    func rotor() throws -> GyroscopicRotor {
        try GyroscopicRotor(transverseInertia: 2, polarInertia: 3, maximumSpeed: 1000, maximumAcceleration: 1000)
    }
    @Test func precessionAndReciprocalBearingTorque() throws {
        var work = try AdditionalModelFixture.loadWork()
        let r = try service.evaluate(rotor: rotor(), axis: .unitZ, carrierSpeed: Vector3(2,0,0),
            carrierAcceleration: .zero, spinSpeed: 100, spinAcceleration: 0, work: &work)
        #expect(try AdditionalModelFixture.vectorNear(r.requiredTorque, try Vector3(0,-600,0)))
        #expect(r.motorTorque == .zero && r.bearingTorque == r.requiredTorque)
        #expect(try AdditionalModelFixture.vectorNear(r.bearingReaction, try r.bearingTorque.scaled(by: -1)))
        #expect(AdditionalModelFixture.near(r.kineticEnergy, 15004))
        #expect(AdditionalModelFixture.near(r.powerResidual, 0))
    }
    @Test func originalPowerAndRotationCovariance() throws {
        var work = try AdditionalModelFixture.loadWork()
        let p = try rotor(), omega = try Vector3(2,-3,5), alpha = try Vector3(-1,4,2)
        let r = try service.evaluate(rotor: p, axis: .unitZ, carrierSpeed: omega, carrierAcceleration: alpha,
                                     spinSpeed: 7, spinAcceleration: -2, work: &work)
        #expect(AdditionalModelFixture.near(r.kineticEnergy, 229))
        #expect(AdditionalModelFixture.near(r.energyRate, -28))
        #expect(AdditionalModelFixture.near(r.powerResidual, 0))
        #expect(r.motorTorque == .zero)
        let rotation = try UnitQuaternion(axis: Vector3(1,2,3), angle: 0.7)
        let rotated = try service.evaluate(rotor: p, axis: rotation.rotating(.unitZ), carrierSpeed: rotation.rotating(omega),
            carrierAcceleration: rotation.rotating(alpha), spinSpeed: 7, spinAcceleration: -2, work: &work)
        #expect(try AdditionalModelFixture.vectorNear(rotated.requiredTorque, try rotation.rotating(r.requiredTorque)))
        #expect(AdditionalModelFixture.near(rotated.kineticEnergy, r.kineticEnergy))
        #expect(AdditionalModelFixture.near(rotated.energyRate, r.energyRate))
        #expect(AdditionalModelFixture.near(rotated.powerResidual, 0))
    }
    @Test func motorAccelerationAndFailureContracts() throws {
        var work = try AdditionalModelFixture.loadWork()
        let p = try rotor()
        let r = try service.evaluate(rotor: p, axis: .unitZ, carrierSpeed: .zero,
            carrierAcceleration: .zero, spinSpeed: 10, spinAcceleration: 2, work: &work)
        #expect(try AdditionalModelFixture.vectorNear(r.motorTorque, try Vector3(0,0,6)))
        #expect(r.bearingTorque == .zero)
        #expect(r.relativeMotorPower == 60 && r.energyRate == 60)
        #expect(throws: LoadError.invalidShape) {
            try service.evaluate(rotor: p, axis: Vector3(0,0,2), carrierSpeed: .zero,
                carrierAcceleration: .zero, spinSpeed: 0, spinAcceleration: 0, work: &work)
        }
        var cancelled = try AdditionalModelFixture.loadWork(cancelled: true)
        #expect(throws: LoadError.cancelled) {
            try service.evaluate(rotor: p, axis: .unitZ, carrierSpeed: .zero,
                carrierAcceleration: .zero, spinSpeed: 0, spinAcceleration: 0, work: &cancelled)
        }
        var exhausted = try AdditionalModelFixture.loadWork(maximumWork: 79)
        #expect(throws: LoadError.workExhausted) {
            try service.evaluate(rotor: p, axis: .unitZ, carrierSpeed: .zero,
                carrierAcceleration: .zero, spinSpeed: 0, spinAcceleration: 0, work: &exhausted)
        }
        #expect(throws: LoadError.invalidInput) {
            try GyroscopicRotor(transverseInertia: 1, polarInertia: 3, maximumSpeed: 10, maximumAcceleration: 10)
        }
    }
}
