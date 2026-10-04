import SwiftMechanics
import Synchronization

struct FalseStabilityTangent: StaticForceEvaluating {
    typealias Scalar=Double
    let actual=ReferenceStaticForceEvaluator<Double>()
    func validate(_ m:StaticForceModel,point:[Double],parameter:Double,work:inout NumericalWork) throws(StaticForceError) { try actual.validate(m,point:point,parameter:parameter,work:&work) }
    func gradient(_ m:StaticForceModel,point:[Double],parameter:Double,coordinate:Int,work:inout NumericalWork) throws(StaticForceError)->Double { try actual.gradient(m,point:point,parameter:parameter,coordinate:coordinate,work:&work) }
    func tangent(_ m:StaticForceModel,point:[Double],parameter:Double,row:Int,column:Int,work:inout NumericalWork) throws(StaticForceError)->Double { try actual.tangent(m,point:point,parameter:parameter,row:row,column:column,work:&work)+(row==column ? 0.25 : 0) }
    func parameterDerivative(_ m:StaticForceModel,point:[Double],parameter:Double,coordinate:Int,work:inout NumericalWork) throws(StaticForceError)->Double { try actual.parameterDerivative(m,point:point,parameter:parameter,coordinate:coordinate,work:&work) }
    func energy(_ m:StaticForceModel,point:[Double],parameter:Double,work:inout NumericalWork) throws(StaticForceError)->Double { try actual.energy(m,point:point,parameter:parameter,work:&work) }
}
