import SwiftMechanics
import Foundation

struct ToothMaterialOracle {
    let separation: Double
    let point: Vector3
    let relative: Vector3
    let angular: Vector3
    let force: Vector3
    let couple: Vector3
    let torqueA: Vector3
    let torqueB: Vector3
    let acceleration: [Double]
    let kinetic: Double
    let kineticRate: Double
    let normal: Double
    let tangent: Double
    let cohesion: Double
    let dn: Double
    let dr: Double
    let dt: Double
    let z1: Double
    let z2: Double
    let trialStaticUtilization: Double
    private struct V {
        var x: Double; var y: Double; var z: Double
        init(_ x: Double,_ y: Double,_ z: Double) { self.x=x; self.y=y; self.z=z }
        static func + (a: V,b: V) -> V { V(a.x+b.x,a.y+b.y,a.z+b.z) }
        static func - (a: V,b: V) -> V { V(a.x-b.x,a.y-b.y,a.z-b.z) }
        static func * (a: V,b: Double) -> V { V(a.x*b,a.y*b,a.z*b) }
        func dot(_ b: V) -> Double { x*b.x+y*b.y+z*b.z }
        func cross(_ b: V) -> V { V(y*b.z-z*b.y,z*b.x-x*b.z,x*b.y-y*b.x) }
        var norm: Double { sqrt(dot(self)) }
        var unit: V { self*(1/norm) }
        var value: Vector3 { get throws { try Vector3(x,y,z) } }
    }
    static func evaluate(model: ToothContactModel, q: [Double], v: [Double], history: ContactHistory,
                         step: Double? = nil, mixed: Bool = false) throws -> ToothMaterialOracle {
        let (ia,ib)=try ToothFixtures.indices(model), qa=q[ia], qb=q[ib], wa=v[ia], wb=v[ib]
        let axisA=V(0,0,1), axisB=mixed ? V(0,1,0) : V(0,0,1)
        func rotate(_ p: V,_ axis: V,_ angle: Double) -> V {
            p*cos(angle)+axis.cross(p)*sin(angle)+axis*(axis.dot(p)*(1-cos(angle)))
        }
        let centerA=rotate(V(1,0.25,0),axisA,qa)
        let centerB=V(2,0,0)+rotate(V(-1,-0.25,0),axisB,qb)
        let firstIsA=model.teeth[model.contacts[0].firstProxy].proxy.geometry.bodyID.key == "tooth-a"
        let sign=firstIsA ? 1.0 : -1.0
        let delta=centerB-centerA, s=delta.norm-0.6, n=delta.unit*sign, p=(centerA+centerB)*0.5
        let omegaA=axisA*wa, omegaB=axisB*wb, angular=(omegaB-omegaA)*sign
        let relative=(omegaB.cross(p-V(2,0,0))-omegaA.cross(p))*sign
        let material=model.contacts[0].firstMaterialTangent?.directionInCollider ?? .unitZ
        let direction=rotate(V(material.x,material.y,material.z),firstIsA ? axisA : axisB,firstIsA ? qa : qb)
        let e1=(direction-n*n.dot(direction)).unit, e2=n.cross(e1)
        let vn=n.dot(relative), vt1=e1.dot(relative), vt2=e2.dot(relative), deltaN=max(-s,0)
        let pair=model.contacts[0].law.parameters
        let fe: Double, fn: Double, un: Double
        switch pair.normal {
        case .linear(let k,let damping,_,_):
            fe=k*deltaN; fn=deltaN == 0 ? 0 : max(fe-damping*vn,0); un=0.5*k*deltaN*deltaN
        case .hertz(let k,_,_,_):
            fe=k*deltaN*sqrt(deltaN); fn=fe; un=0.4*fe*deltaN
        case .huntCrossley(let k,let alpha,_,_,_):
            fe=k*deltaN*sqrt(deltaN); fn=fe*max(1-alpha*vn,0); un=0.4*fe*deltaN
        }
        var fc=0.0, uc=0.0
        if case .reversibleLinear(let tensile,let range)=pair.cohesion {
            if s < 0 { uc = -tensile*range/2 }
            else if s < range { fc = -tensile*(1-s/range); uc = -tensile*range/2*pow(1-s/range,2) }
        }
        var staticUtilization=0.0
        var z1=history.firstBristleDisplacement, z2=history.secondBristleDisplacement, ft1=0.0, ft2=0.0, ut=0.0, dt=0.0
        if case .elasticCoulomb(let friction)=pair.friction {
            let k=friction.tangentialStiffness, old=0.5*k*(z1*z1+z2*z2)
            if let step {
                if fn == 0 { z1=0; z2=0; dt=old }
                else {
                    z1 += step*vt1; z2 += step*vt2
                    let norm=sqrt(pow(k*z1/(fn*friction.staticFirst),2)+pow(k*z2/(fn*friction.staticSecond),2))
                    staticUtilization=norm
                    if norm > 1 {
                        let blend=friction.transitionSpeed/(friction.transitionSpeed+hypot(vt1,vt2))
                        let mu1=friction.dynamicFirst+(friction.staticFirst-friction.dynamicFirst)*blend
                        let mu2=friction.dynamicSecond+(friction.staticSecond-friction.dynamicSecond)*blend
                        let scale=1/sqrt(pow(k*z1/(fn*mu1),2)+pow(k*z2/(fn*mu2),2))
                        z1 *= scale; z2 *= scale
                    }
                }
                ft1 = -k*z1; ft2 = -k*z2; ut=0.5*k*(z1*z1+z2*z2)
                if fn != 0 { dt = -ft1*step*vt1-ft2*step*vt2-(ut-old) }
            } else { ft1 = -k*z1; ft2 = -k*z2; ut=old }
        }
        let w1=e1.dot(angular), w2=e2.dot(angular), wn=n.dot(angular), resistance=pair.resistance
        let rollFactor = -resistance.rollingCoefficient*fn*pair.resistanceRadius/sqrt(w1*w1+w2*w2+pow(resistance.angularRegularization,2))
        let spin = -resistance.spinningCoefficient*fn*pair.resistanceRadius*wn/sqrt(wn*wn+pow(resistance.angularRegularization,2))
        let force=n*(fn+fc)+e1*ft1+e2*ft2, couple=e1*(rollFactor*w1)+e2*(rollFactor*w2)+n*spin
        let physicalForceB=force*sign, physicalCoupleB=couple*sign
        let ta=p.cross(physicalForceB*(-1))-physicalCoupleB, tb=(p-V(2,0,0)).cross(physicalForceB)+physicalCoupleB
        var acceleration=[Double](repeating:0,count:2)
        let inertiaA=model.inertias.first(where:{$0.body.key == "tooth-a"})!.properties.inertiaAtCenter.m22
        let inertiaB=model.inertias.first(where:{$0.body.key == "tooth-b"})!.properties.inertiaAtCenter.m22
        acceleration[ia]=(model.driveForce[ia]+axisA.dot(ta))/inertiaA
        acceleration[ib]=(model.driveForce[ib]+axisB.dot(tb))/inertiaB
        let rotation=model.tree.bodies[0].referencePose.rotation
        func world(_ p: V) -> V {
            let u=V(rotation.x,rotation.y,rotation.z)
            return p+u.cross(p)*(2*rotation.w)+u.cross(u.cross(p))*2
        }
        return try ToothMaterialOracle(separation:s,point:world(p).value,relative:world(relative).value,angular:world(angular).value,
            force:world(force).value,couple:world(couple).value,torqueA:world(firstIsA ? ta : tb).value,torqueB:world(firstIsA ? tb : ta).value,acceleration:acceleration,
            kinetic:0.5*(inertiaA*wa*wa+inertiaB*wb*wb),kineticRate:inertiaA*wa*acceleration[ia]+inertiaB*wb*acceleration[ib],
            normal:un,tangent:ut,cohesion:uc,dn:(fe-fn)*vn,dr:-couple.dot(angular),dt:dt,z1:z1,z2:z2,trialStaticUtilization:staticUtilization)
    }
}
