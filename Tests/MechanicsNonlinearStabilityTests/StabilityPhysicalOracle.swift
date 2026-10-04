import SwiftMechanics
import Testing

struct StabilityPhysicalOracle {
    static func check(_ point: NonlinearStabilityPoint, tolerance: Double=1e-7) {
        let q=point.position,u=(q[0]+q[1])/2,v=(q[0]-q[1])/2,p=point.parameter
        #expect(abs(q[2]-2*u)<tolerance)
        #expect(abs(p-(u+u*u*u+3*u*v*v))<tolerance)
        #expect(abs(v*(-1+3*u*u+v*v))<tolerance)
        let g=[-q[0]+q[0]*q[0]*q[0]-p,-q[1]+q[1]*q[1]*q[1]-p,q[2]],R=[-2*u,-2*u,2*u]
        let E = -0.5*(q[0]*q[0]+q[1]*q[1])+0.25*(q[0]*q[0]*q[0]*q[0]+q[1]*q[1]*q[1]*q[1])+0.5*q[2]*q[2]-p*(q[0]+q[1])
        #expect(abs(point.energy-E)<tolerance)
        #expect(abs(point.rowMultipliers[0]+2*u)<tolerance)
        for i in 0..<3 { #expect(abs(point.physicalGradient[i]-g[i])<tolerance);#expect(abs(point.generalizedReaction[i]-R[i])<tolerance);#expect(abs(g[i]-R[i])<tolerance) }
        let a=3*q[0]*q[0],c=3*q[1]*q[1],b=2-2*(a+c),det=a*c-1
        let discriminant=b*b-12*det
        let expected=[(-b-discriminant.squareRoot())/6,(-b+discriminant.squareRoot())/6]
        for mode in 0..<2 {
            let lambda=point.stiffnessEigenvalues[mode],offset=3*mode,phi=Array(point.modes[offset..<offset+3])
            #expect(abs(lambda-expected[mode])<tolerance)
            #expect(abs(phi[2]-phi[0]-phi[1])<tolerance)
            #expect(abs(phi[0]*phi[0]+phi[1]*phi[1]+phi[2]*phi[2]-1)<tolerance)
            // Independent original H=diag(-1+3q1²,-1+3q2²,1), M=I, constrained physical virtual work.
            let r=[(-1+a-lambda)*phi[0],(-1+c-lambda)*phi[1],(1-lambda)*phi[2]]
            #expect(abs(r[0]+r[2])<tolerance);#expect(abs(r[1]+r[2])<tolerance)
        }
        #expect(point.maximumProjectedResidual<tolerance);#expect(point.maximumMassError<tolerance)
    }
}
