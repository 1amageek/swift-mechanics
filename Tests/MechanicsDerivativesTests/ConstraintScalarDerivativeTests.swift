import SwiftMechanics
import Testing
@Suite struct ConstraintScalarDerivativeTests {
    @Test func exactScalarChainAndDomain() throws {
        var w=try DerivativeFixtures.work()
        let service:any ScalarDifferentiating=ExactScalarDifferentiator()
        let x=try DirectionalScalar(value:2,direction:3)
        let square=try service.evaluate(.multiply,left:x,right:x,work:&w)
        let root=try service.evaluate(.squareRoot,left:square,right:nil,work:&w)
        #expect(root.value == 2); #expect(root.direction == 3)
        do { _=try service.evaluate(.squareRoot,left:DirectionalScalar(value:0,direction:1),right:nil,work:&w); Issue.record("Expected nonsmooth square root failure") }
        catch let error as DerivativeError { guard case .derivativeUnavailable=error else { throw error } }
        do { _=try service.evaluate(.divide,left:x,right:DirectionalScalar(value:0,direction:0),work:&w); Issue.record("Expected division domain failure") }
        catch let error as DerivativeError { guard case .derivativeUnavailable=error else { throw error } }
    }
    @Test func physicalScalingExplicitTimeAndCoefficientDirections() throws {
        let layout=try ConstraintCoordinateLayout(coordinateIDs:[1,2],dimensions:[.length,.angle],scales:[2,4],timeScale:5,revision:9)
        let row=QuadraticConstraint(id:11,constant:1,linear:[2,-1],hessian:[4,1,1,6],timeLinear:3,timeQuadratic:2,mixedTime:[5,-2])
        let system=try QuadraticConstraintSystem(layout:layout,rows:[row],minimumPosition:[-10,-10],maximumPosition:[10,10],minimumTime:-10,maximumTime:10)
        let zero=ConstraintCoefficientDirection(rowID:11,constant:0,linear:[0,0],hessian:[0,0,0,0],timeLinear:0,timeQuadratic:0,mixedTime:[0,0])
        var w=try DerivativeFixtures.work()
        let service:any ConstraintDifferentiating=ExactConstraintDifferentiator()
        let out=try service.direction(system,position:[1,2],velocity:[0.3,0.4],time:2,
            direction:ConstraintDirection(layoutRevision:9,position:[0.2,-0.4],velocity:[0.02,0.08],time:0.5,coefficients:[zero]),
            evaluationPolicy:ConstraintEvaluationPolicy(maximumCoordinates:2,maximumRows:1,expectedLayoutRevision:9),policy:DerivativeFixtures.policy(),work:&w)
        #expect(DerivativeFixtures.close(out.values[0],1.01))
        #expect(DerivativeFixtures.close(out.normalizedJacobian[0],0.8)); #expect(DerivativeFixtures.close(out.normalizedJacobian[1],-0.7))
        #expect(DerivativeFixtures.close(out.physicalJacobian[0],0.4)); #expect(DerivativeFixtures.close(out.physicalJacobian[1],-0.175))
        #expect(DerivativeFixtures.close(out.timeDerivative[0],0.9)); #expect(DerivativeFixtures.close(out.accelerationBias[0],1.2))
        let dc=ConstraintCoefficientDirection(rowID:11,constant:2,linear:[0,0],hessian:[2,0,0,0],timeLinear:3,timeQuadratic:0,mixedTime:[0,0])
        let parameter=try service.direction(system,position:[1,2],velocity:[0.3,0.4],time:2,
            direction:ConstraintDirection(layoutRevision:9,position:[0,0],velocity:[0,0],time:0,coefficients:[dc]),
            evaluationPolicy:ConstraintEvaluationPolicy(maximumCoordinates:2,maximumRows:1,expectedLayoutRevision:9),policy:DerivativeFixtures.policy(),work:&w)
        #expect(DerivativeFixtures.close(parameter.values[0],3.45))
        #expect(DerivativeFixtures.close(parameter.accelerationBias[0],1.125))
    }
    @Test func badCoefficientAndOriginalDomainFailure() throws {
        let layout=try ConstraintCoordinateLayout(coordinateIDs:[1,2],dimensions:[.length,.length],scales:[1,1],timeScale:1,revision:9)
        let row=QuadraticConstraint(id:11,constant:0,linear:[1,0],hessian:[0,0,0,0],timeLinear:0,timeQuadratic:0,mixedTime:[0,0])
        let system=try QuadraticConstraintSystem(layout:layout,rows:[row],minimumPosition:[-1,-1],maximumPosition:[1,1],minimumTime:0,maximumTime:1)
        let dc=ConstraintCoefficientDirection(rowID:11,constant:0,linear:[0,0],hessian:[0,1,0,0],timeLinear:0,timeQuadratic:0,mixedTime:[0,0])
        let d=ConstraintDirection(layoutRevision:9,position:[0,0],velocity:[0,0],time:0,coefficients:[dc])
        var w=try DerivativeFixtures.work()
        do { _=try ExactConstraintDifferentiator().direction(system,position:[0,0],velocity:[0,0],time:0,direction:d,
            evaluationPolicy:ConstraintEvaluationPolicy(maximumCoordinates:2,maximumRows:1,expectedLayoutRevision:9),policy:DerivativeFixtures.policy(),work:&w); Issue.record("Expected asymmetric derivative rejection") }
        catch let error as DerivativeError { guard case .invalidInput=error else { throw error } }
        do { _=try ExactConstraintDifferentiator().direction(system,position:[2,0],velocity:[0,0],time:0,direction:d,
            evaluationPolicy:ConstraintEvaluationPolicy(maximumCoordinates:2,maximumRows:1,expectedLayoutRevision:9),policy:DerivativeFixtures.policy(),work:&w); Issue.record("Expected original domain rejection") }
        catch let error as DerivativeError { guard case .constraints(.outsideDomain,failedSupplierWorkUnavailable:false)=error else { throw error } }
    }
}
