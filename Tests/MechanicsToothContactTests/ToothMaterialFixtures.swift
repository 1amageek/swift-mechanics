import SwiftMechanics
import Foundation

enum ToothMaterialFixtures {
    static func law(normal: Int = 0, friction: Bool = true, cohesion: Bool = true, resistance: Bool = true,
                    stiffness: Double = 10) throws -> ContactLawPair {
        let axis=try ContactFrictionParameters(staticFirst:0.9,staticSecond:0.6,dynamicFirst:0.5,dynamicSecond:0.3,
            tangentialStiffness:20,transitionSpeed:0.1)
        let resist=try ContactResistanceParameters(rollingCoefficient:resistance ? 0.1 : 0,spinningCoefficient:resistance ? 0.2 : 0,angularRegularization:0.1)
        let cohesive: ContactCohesionLaw=cohesion ? .reversibleLinear(tensileLimit:0.3,range:0.2) : .none
        let f: ContactFrictionLaw=friction ? .elasticCoulomb(axis) : .none
        func material(_ key: String) throws -> ContactMaterial {
            try ContactMaterial(reference:ModelReference(id:ToothFixtures.id(.material,key),revision:1),youngModulus:200,poissonsRatio:0,
                linearStiffness:2*stiffness,normalDamping:normal == 1 ? 2 : 0,huntCrossleyAlpha:normal == 3 ? 0.2 : 0,
                friction:f,resistance:resist,cohesion:cohesive)
        }
        let selection: ContactNormalSelection
        switch normal {
        case 2: selection = .hertz(effectiveRadius:1,maximumPenetration:0.8,maximumNormalSpeed:100)
        case 3: selection = .huntCrossley(effectiveRadius:1,maximumPenetration:0.8,maximumNormalSpeed:100)
        default: selection = .linear(maximumPenetration:0.8,maximumNormalSpeed:100)
        }
        var work=ContactWork(budget:try ContactBudget(operations:100_000,scalarStorage:10_000,records:1))
        return try SeriesContactPairing().combine(first:material("material-a"),second:material("material-b"),selection:selection,
            lossPolicy:.compliantDampingOnly,resistanceRadius:0.3,override:nil,work:&work)
    }
    static func model(normal: Int = 0, friction: Bool = true, cohesion: Bool = true, resistance: Bool = true,
                      stiffness: Double = 10, rotated: Bool = false, mixed: Bool = false, inertia: Double = 1,
                      direction: Vector3 = .unitZ) throws -> ToothContactModel {
        try ToothFixtures.model(inertia:inertia,lawOverride:law(normal:normal,friction:friction,cohesion:cohesion,resistance:resistance,stiffness:stiffness),
            materialDirection:direction,secondAxis:mixed ? .unitY : .unitZ,
            worldRotation:rotated ? UnitQuaternion(axis:Vector3(1,2,3),angle:0.4) : .identity)
    }
    static func service(_ model: ToothContactModel) -> ReferenceToothContactEvolution {
        ReferenceToothContactEvolution(model:model,current:CompliantContactCurrentEvaluator())
    }
    static func initial(_ model: ToothContactModel, q: [Double] = [0,0], v: [Double] = [0.4,-0.2]) throws -> MaterialToothContactState {
        var work=try ToothFixtures.work()
        return try service(model).initialMaterial(time:0,q:q,v:v,policy:ToothFixtures.policy(defect:100),work:&work)
    }
    static func advance(_ model: ToothContactModel, initial: MaterialToothContactState, step: Double, end: Double = 0.02) throws -> MaterialToothContactState {
        var work=try ToothFixtures.work()
        return try service(model).advanceMaterial(accepted:initial,to:end,timeStep:step,policy:ToothFixtures.policy(defect:100),work:&work).accepted
    }
}
