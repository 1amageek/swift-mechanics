import SwiftMechanics
struct IncorrectTangentForceEvaluator: StaticForceEvaluating {
    typealias Scalar=Double
    let actual=ReferenceStaticForceEvaluator<Double>()
    func validate(_ model:StaticForceModel,point:[Double],parameter:Double,work:inout NumericalWork)throws(StaticForceError) { try actual.validate(model,point:point,parameter:parameter,work:&work) }
    func gradient(_ model:StaticForceModel,point:[Double],parameter:Double,coordinate:Int,work:inout NumericalWork)throws(StaticForceError)->Double { try actual.gradient(model,point:point,parameter:parameter,coordinate:coordinate,work:&work) }
    func tangent(_ model:StaticForceModel,point:[Double],parameter:Double,row:Int,column:Int,work:inout NumericalWork)throws(StaticForceError)->Double { 2*(try actual.tangent(model,point:point,parameter:parameter,row:row,column:column,work:&work)) }
    func parameterDerivative(_ model:StaticForceModel,point:[Double],parameter:Double,coordinate:Int,work:inout NumericalWork)throws(StaticForceError)->Double { try actual.parameterDerivative(model,point:point,parameter:parameter,coordinate:coordinate,work:&work) }
    func energy(_ model:StaticForceModel,point:[Double],parameter:Double,work:inout NumericalWork)throws(StaticForceError)->Double { try actual.energy(model,point:point,parameter:parameter,work:&work) }
}
