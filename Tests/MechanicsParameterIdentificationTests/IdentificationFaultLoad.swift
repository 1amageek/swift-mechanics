import SwiftMechanics

struct IdentificationFaultLoad: ScalarLoadEvaluating {
    enum Mode:Sendable { case resetLedger,wrongPower }
    let mode:Mode
    func evaluate(_ law:PolynomialSpringDamper,coordinate:Double,rate:Double,work:inout LoadWork) throws(LoadError) -> ScalarLoadResponse {
        let result=try ScalarLoadEvaluator().evaluate(law,coordinate:coordinate,rate:rate,work:&work)
        switch mode {
        case .resetLedger: work=LoadWork(budget:work.budget);return result
        case .wrongPower:
            return try ScalarLoadResponse(conservative:result.conservative,dissipative:result.dissipative,
                coordinateDerivative:result.coordinateDerivative,rateDerivative:result.rateDerivative,
                potentialEnergy:result.potentialEnergy,dissipatedPower:result.dissipatedPower+1)
        }
    }
}
