import SwiftMechanics
import Testing

@Suite(.timeLimit(.minutes(1))) struct NonlinearTransmissionCommonTests {
    func sample(at q: Double = 0.8) throws -> NonlinearTransmissionSample {
        try HarmonicCamTransmission(lift: 0.03,inputDomain: NonlinearTransmissionFixture.domain()).evaluate(inputCoordinate: q)
    }
    @Test func explicitFiniteDomainAdmission() throws {
        #expect(throws: NonlinearTransmissionError.self) { try TransmissionInputDomain(minimum: 1,maximum: 1) }
        #expect(throws: NonlinearTransmissionError.self) { try TransmissionInputDomain(minimum: .nan,maximum: 1) }
        #expect(throws: NonlinearTransmissionError.self) { try TransmissionInputDomain(minimum: 0,maximum: .infinity) }
        let d=try TransmissionInputDomain(minimum: -1,maximum: 1)
        try d.validate(-1);try d.validate(1)
        #expect(throws: NonlinearTransmissionError.outsideInputDomain(value: 2,minimum: -1,maximum: 1)) { try d.validate(2) }
    }
    @Test func zeroDerivativeForwardMotionAndPowerRemainValid() throws {
        let r=try sample(at: 0), motion=try r.motion(inputRate: 2,inputAcceleration: 7)
        #expect(motion.outputRate == 0 && motion.outputAcceleration == 0.06)
        let power=try r.pullBack(outputEffort: -20,inputRate: 2)
        #expect(power.inputEffort == 0 && power.inputPower == 0 && power.outputPower == 0)
        #expect(throws: NonlinearTransmissionError.singularInverse(derivative: 0,minimumAbsoluteDerivative: 0)) { try r.inputRate(forOutputRate: 0,minimumAbsoluteDerivative: 0) }
        #expect(throws: NonlinearTransmissionError.self) { try r.outputEffort(forInputEffort: 0,minimumAbsoluteDerivative: 0) }
    }
    @Test func localInverseThresholdIsCallerPolicy() throws {
        let r=try sample()
        #expect(throws: NonlinearTransmissionError.singularInverse(derivative: r.derivative,minimumAbsoluteDerivative: abs(r.derivative))) { try r.inputRate(forOutputRate: 1,minimumAbsoluteDerivative: abs(r.derivative)) }
        #expect(throws: NonlinearTransmissionError.invalidInput(name: "localInverse")) { try r.inputRate(forOutputRate: 1,minimumAbsoluteDerivative: -1) }
        #expect(throws: NonlinearTransmissionError.self) { try r.outputEffort(forInputEffort: .nan,minimumAbsoluteDerivative: 0) }
        #expect(throws: NonlinearTransmissionError.self) { try r.inputRate(forOutputRate: 1,minimumAbsoluteDerivative: .infinity) }
    }
    @Test func originalAffineRejectsStationaryGradient() throws {
        let r=try sample(at: 0), frame=try NonlinearTransmissionFixture.frame()
        var work=try NonlinearTransmissionFixture.work()
        #expect(throws: ActuationError.outsideDomain) { try r.instantaneousAffine(model: NonlinearTransmissionFixture.model(),frame: frame,work: &work) }
        #expect(r.derivative == 0 && work.peakScalars == 1)
    }
    @Test func affineCapacityAndCancellationBeforeArrayBoundary() throws {
        let r=try sample(), frame=try NonlinearTransmissionFixture.frame()
        var limited=try NonlinearTransmissionFixture.work(scalars: 0)
        #expect(throws: ActuationError.capacityExceeded) { try r.instantaneousAffine(model: NonlinearTransmissionFixture.model(),frame: frame,work: &limited) }
        #expect(limited.peakScalars == 0)
        var cancelled=try NonlinearTransmissionFixture.work(cancelled: true)
        #expect(throws: ActuationError.cancelled) { try r.instantaneousAffine(model: NonlinearTransmissionFixture.model(),frame: frame,work: &cancelled) }
        #expect(cancelled.peakScalars == 0)
    }
    @Test func supplierModelAndFrameAuthorityRemainOriginal() throws {
        let r=try sample(), frame=try NonlinearTransmissionFixture.frame(), model=NonlinearTransmissionFixture.model()
        var work=try NonlinearTransmissionFixture.work(), numerical=try NonlinearTransmissionFixture.numerical()
        let row=try r.instantaneousAffine(model: model,frame: frame,work: &work)
        let service: any ActuationTransmitting=ReferenceActuationTransmitter(mapper: LoadMapper())
        let tolerance=try NumericalTolerance(absolute: 1e-10,relative: 1e-10)
        #expect(throws: ActuationError.staleBinding) { try service.affine(row,model: ModelStamp(identity: "other",revision: 1),frame: frame,effort: 1,rate: [1],tolerance: tolerance,work: &work,numerical: &numerical) }
        #expect(throws: ActuationError.frameMismatch) { try service.affine(row,model: model,frame: EntityID(kind: .frame,key: "other"),effort: 1,rate: [1],tolerance: tolerance,work: &work,numerical: &numerical) }
    }
    @Test func motionPowerAndGeometryArithmeticFailuresAreExplicit() throws {
        let r=try sample(at: 0)
        #expect(throws: NonlinearTransmissionError.self) { try r.motion(inputRate: 1e308,inputAcceleration: 0) }
        #expect(throws: NonlinearTransmissionError.invalidInput(name: "inputMotion")) { try r.motion(inputRate: .infinity,inputAcceleration: 0) }
        #expect(throws: NonlinearTransmissionError.invalidInput(name: "inputPower")) { try r.pullBack(outputEffort: .nan,inputRate: 0) }
        let large=try SliderCrankTransmission(crankRadius: 1e308,rodLength: 1e308,assembly: .positiveRodProjection,inputDomain: TransmissionInputDomain(minimum: -1,maximum: 1))
        #expect(throws: NonlinearTransmissionError.self) { try large.evaluate(inputCoordinate: 0) }
        #expect(try sample(at: 0) == r)
    }
}
