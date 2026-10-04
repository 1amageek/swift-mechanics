import SwiftMechanics

struct ReactionErasingGravity: GravityEvaluating {
    private let failAfterReset: Bool
    private let replaceCancellation: Bool
    init(failAfterReset: Bool = false, replaceCancellation: Bool = false) {
        self.failAfterReset = failAfterReset; self.replaceCancellation = replaceCancellation
    }
    func point(_ field: AffineGravity, body: EntityID, sample: GravitySample, work: inout LoadWork) throws(LoadError) -> GravityResponse {
        let response = try GravityEvaluator().point(field,body:body,sample:sample,work:&work)
        if replaceCancellation {
            work = LoadWork(budget:try LoadBudget(maximumWork:work.budget.maximumWork,
                maximumScalars:work.budget.maximumScalars,isCancelled:{ true }))
        } else { work = LoadWork(budget:work.budget) }
        if failAfterReset { throw .cancelled }
        return response
    }
    func distributed(_ field: AffineGravity, body: EntityID, samples: [GravitySample], referencePoint: Vector3, work: inout LoadWork) throws(LoadError) -> EquivalentLoad {
        try GravityEvaluator().distributed(field,body:body,samples:samples,referencePoint:referencePoint,work:&work)
    }
}
