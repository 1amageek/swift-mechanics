import SwiftMechanics
import Testing
import Darwin

struct NonlinearTransmissionFixture {
    static func domain() throws -> TransmissionInputDomain { try TransmissionInputDomain(minimum: -20*Double.pi,maximum: 20*Double.pi) }
    static func near(_ a: Double, _ b: Double, absolute: Double = 1e-12, relative: Double = 1e-9) -> Bool {
        abs(a-b) <= absolute+relative*max(abs(a),abs(b))
    }
    static func work(scalars: Int = 8, cancelled: Bool = false) throws -> ActuationWork {
        ActuationWork(budget: try ActuationBudget(maximumWork: 1000, maximumScalars: scalars,
            maximumBytes: 64, maximumBindings: 1, maximumMetadataBytes: 128, isCancelled: { cancelled }))
    }
    static func numerical() throws -> NumericalWork { NumericalWork(budget: try NumericalBudget(scalarStorage: 8,arithmeticOperations: 1000,iterations: 0)) }
    static func frame() throws -> EntityID { try EntityID(kind: .frame,key: "nonlinear-world") }
    static func model() -> ModelStamp { ModelStamp(identity: "nonlinear-model",revision: 1) }
    static func derivatives(_ law: any NonlinearTransmissionEvaluating, at q: Double) throws {
        let original=try law.evaluate(inputCoordinate: q)
        for h in [1e-4,5e-5] {
            let plus=try law.evaluate(inputCoordinate: q+h), minus=try law.evaluate(inputCoordinate: q-h)
            #expect(near(original.derivative,(plus.outputCoordinate-minus.outputCoordinate)/(2*h),absolute: 1e-8,relative: 2e-6))
            #expect(near(original.curvature,(plus.derivative-minus.derivative)/(2*h),absolute: 1e-8,relative: 2e-6))
        }
    }
    static func originalMotionAndPower(_ law: any NonlinearTransmissionEvaluating, at q: Double) throws {
        let sample=try law.evaluate(inputCoordinate: q), velocity=2.3, acceleration = -0.7
        let motion=try sample.motion(inputRate: velocity,inputAcceleration: acceleration)
        for h in [1e-3,5e-4] {
            let plus=try law.evaluate(inputCoordinate: q+velocity*h+acceleration*h*h/2)
            let minus=try law.evaluate(inputCoordinate: q-velocity*h+acceleration*h*h/2)
            #expect(near(motion.outputRate,(plus.outputCoordinate-minus.outputCoordinate)/(2*h),absolute: 3e-6,relative: 2e-5))
            #expect(near(motion.outputAcceleration,(plus.outputCoordinate-2*sample.outputCoordinate+minus.outputCoordinate)/(h*h),absolute: 3e-6,relative: 2e-5))
        }
        for sign in [-1.0,1.0] {
            let rate=sign*velocity, effort = -17.0
            let response=try sample.pullBack(outputEffort: effort,inputRate: rate)
            #expect(near(response.inputEffort,sample.derivative*effort))
            #expect(near(response.inputPower,response.outputPower))
            #expect(near(response.balanceResidual,0))
            #expect(near(try sample.inputRate(forOutputRate: sample.derivative*rate,minimumAbsoluteDerivative: 0),rate))
            #expect(near(try sample.outputEffort(forInputEffort: sample.derivative*effort,minimumAbsoluteDerivative: 0),effort))
        }
    }
    static func actualAffine(_ law: any NonlinearTransmissionEvaluating, at q: Double) throws {
        let sample=try law.evaluate(inputCoordinate: q), model=model(), frame=try frame()
        var work=try work(), numerical=try numerical()
        let row=try sample.instantaneousAffine(model: model,frame: frame,work: &work)
        #expect(row.inputCoordinates == [.rotation] && row.outputCoordinate == sample.outputKind)
        #expect(row.gradient == [sample.derivative] && row.prescribedRate == 0)
        let service: any ActuationTransmitting=ReferenceActuationTransmitter(mapper: LoadMapper())
        let output=try service.affine(row,model: model,frame: frame,effort: -17,rate: [2.3],
            tolerance: NumericalTolerance(absolute: 1e-10,relative: 1e-10),work: &work,numerical: &numerical)
        let original=try sample.pullBack(outputEffort: -17,inputRate: 2.3)
        #expect(output.efforts.count == 1)
        #expect(near(output.efforts[0],original.inputEffort))
        #expect(near(output.actualPower,original.outputPower))
        #expect(near(output.virtualPower,original.inputPower) && output.prescribedPower == 0)
        #expect(near(output.balanceResidual,0) && work.peakScalars == 1 && work.used > 0)
    }
    static func queryRefusals(_ law: any NonlinearTransmissionEvaluating, at q: Double, minimum: Double, maximum: Double) throws {
        let before=try law.evaluate(inputCoordinate: q)
        #expect(throws: NonlinearTransmissionError.self) { try law.evaluate(inputCoordinate: minimum-1) }
        #expect(throws: NonlinearTransmissionError.self) { try law.evaluate(inputCoordinate: maximum+1) }
        #expect(throws: NonlinearTransmissionError.invalidInput(name: "inputCoordinate")) { try law.evaluate(inputCoordinate: .nan) }
        #expect(throws: NonlinearTransmissionError.self) { try law.evaluate(inputCoordinate: .infinity) }
        #expect(try law.evaluate(inputCoordinate: q) == before)
    }
}
