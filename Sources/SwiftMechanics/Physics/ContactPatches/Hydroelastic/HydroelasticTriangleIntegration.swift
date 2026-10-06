internal enum HydroelasticTriangleIntegration {
    private typealias A = HydroelasticArithmetic
    static func integrate(_ x0: Vector3,_ x1: Vector3,_ x2: Vector3,first: HydroelasticAffineCell,second: HydroelasticAffineCell?,
                          plane: RigidPressurePlane?,normal: Vector3,origin: Vector3,policy: HydroelasticPolicy,firstLoads: inout [Vector3],
                          secondLoads: inout [Vector3],integral: inout HydroelasticIntegral,work: inout NumericalWork) throws(HydroelasticError) -> HydroelasticTriangle {
        try A.check(policy)
        let e1=try A.sub(x1,x0,&work), e2=try A.sub(x2,x0,&work), cross=try A.cross(e1,e2,&work)
        guard try A.dot(cross,normal,&work) > 0 else { throw .boundaryDegeneracy }
        let area=try A.finite(0.5*A.norm(cross,&work)); try A.charge(1,&work)
        guard area >= policy.minimumTriangleArea else { throw .boundaryDegeneracy }
        let p0=try validate(x0,first:first,second:second,plane:plane,policy:policy,integral:&integral,work:&work)
        let p1=try validate(x1,first:first,second:second,plane:plane,policy:policy,integral:&integral,work:&work)
        let p2=try validate(x2,first:first,second:second,plane:plane,policy:policy,integral:&integral,work:&work)
        try A.charge(8,&work)
        let pressure=try A.finite(area*(p0+p1+p2)/3)
        let positionPressure=try weighted(x0,x1,x2,p0:p0,p1:p1,p2:p2,area:area,work:&work)
        let force=try A.scale(normal,pressure,&work)
        let originPressure=try A.scale(origin,pressure,&work), lever=try A.sub(positionPressure,originPressure,&work)
        let moment=try A.cross(lever,normal,&work)
        integral.force=try A.add(integral.force,force,&work); integral.moment=try A.add(integral.moment,moment,&work)
        integral.area=try A.finite(integral.area+area); integral.pressure=try A.finite(integral.pressure+pressure)
        try loads(x0,x1,x2,cell:first,normal:normal,sign:-1,p0:p0,p1:p1,p2:p2,area:area,output:&firstLoads,work:&work)
        if let second { try loads(x0,x1,x2,cell:second,normal:normal,sign:1,p0:p0,p1:p1,p2:p2,area:area,output:&secondLoads,work:&work) }
        // Independent degree-two surface quadrature, not assembled nodal-load contraction.
        for i in 0..<3 {
            try A.check(policy)
            let point=try quadraturePoint(x0,x1,x2,largeIndex:i,work:&work)
            let p=try validate(point,first:first,second:second,plane:plane,policy:policy,integral:&integral,work:&work)
            let n=try first.coordinates(point,&work), velocity=try first.interpolate(n,velocities:true,&work)
            let vn=try A.dot(normal,velocity,&work)
            try A.charge(4,&work); integral.surfacePowerFirst=try A.finite(integral.surfacePowerFirst-area*p*vn/3)
            if let second {
                let m=try second.coordinates(point,&work), otherVelocity=try second.interpolate(m,velocities:true,&work)
                let otherVN=try A.dot(normal,otherVelocity,&work)
                try A.charge(4,&work); integral.surfacePowerSecond=try A.finite(integral.surfacePowerSecond+area*p*otherVN/3)
            } else if let plane {
                let offset=try A.sub(point,plane.point,&work)
                let drift=try A.cross(plane.velocityAboutPoint.angular,offset,&work)
                let rigidVelocity=try A.add(plane.velocityAboutPoint.linear,drift,&work)
                let rigidVN=try A.dot(normal,rigidVelocity,&work)
                try A.charge(4,&work); integral.surfacePowerSecond=try A.finite(integral.surfacePowerSecond+area*p*rigidVN/3)
            }
        }
        return HydroelasticTriangle(first:x0,second:x1,third:x2,firstPressurePascals:p0,secondPressurePascals:p1,thirdPressurePascals:p2,area:area)
    }
    private static func loads(_ x0: Vector3,_ x1: Vector3,_ x2: Vector3,cell: HydroelasticAffineCell,normal: Vector3,sign: Double,
                              p0: Double,p1: Double,p2: Double,area: Double,output: inout [Vector3],work: inout NumericalWork) throws(HydroelasticError) {
        let a=try cell.coordinates(x0,&work), b=try cell.coordinates(x1,&work), c=try cell.coordinates(x2,&work)
        try A.charge(2,&work); let sum=try A.finite(p0+p1+p2)
        for i in 0..<4 {
            try A.charge(14,&work)
            let pressureShape=try A.finite(area*((a.value(i)+b.value(i)+c.value(i))*sum+a.value(i)*p0+b.value(i)*p1+c.value(i)*p2)/12)
            let load=try A.scale(normal,sign*pressureShape,&work), node=cell.cell.nodes[i]
            output[node]=try A.add(output[node],load,&work)
        }
    }
    private static func validate(_ point: Vector3,first: HydroelasticAffineCell,second: HydroelasticAffineCell?,plane: RigidPressurePlane?,policy: HydroelasticPolicy,
                                 integral: inout HydroelasticIntegral,work: inout NumericalWork) throws(HydroelasticError) -> Double {
        let pressure=try original(point,cell:first,policy:policy,integral:&integral,work:&work)
        if let second {
            let other=try original(point,cell:second,policy:policy,integral:&integral,work:&work)
            try A.charge(2,&work); let difference=try A.finite(abs(pressure-other))
            integral.pressureDifference=max(integral.pressureDifference,difference)
            guard difference <= policy.pressureTolerance else { throw .residualRejected }
        }
        if let plane {
            let offset=try A.sub(point,plane.point,&work), distance=try A.dot(plane.normal,offset,&work)
            try A.charge(2,&work)
            let residual=try A.finite(abs(distance)/policy.distanceTolerance)
            integral.geometryResidual=max(integral.geometryResidual,residual)
            guard residual <= 1 else { throw .residualRejected }
        }
        return pressure
    }
    private static func original(_ point: Vector3,cell: HydroelasticAffineCell,policy: HydroelasticPolicy,
                                 integral: inout HydroelasticIntegral,work: inout NumericalWork) throws(HydroelasticError) -> Double {
        let weights=try cell.coordinates(point,&work)
        var nodalPressure=0.0, sum=0.0
        for i in 0..<4 {
            try A.charge(7,&work); let weight=weights.value(i)
            guard weight >= -policy.barycentricTolerance, weight <= 1+policy.barycentricTolerance else { throw .residualRejected }
            sum=try A.finite(sum+weight)
            nodalPressure=try A.finite(nodalPressure+weight*cell.field.pressurePascals[cell.cell.nodes[i]])
        }
        let reconstructed=try cell.interpolate(weights,velocities:false,&work), delta=try A.sub(reconstructed,point,&work)
        let reconstruction=try A.norm(delta,&work)
        try A.charge(6,&work)
        let geometry=max(try A.finite(reconstruction/policy.distanceTolerance),try A.finite(abs(sum-1)/policy.barycentricTolerance))
        integral.geometryResidual=max(integral.geometryResidual,geometry)
        guard geometry <= 1 else { throw .residualRejected }
        let pressure=try cell.pressure(point,&work)
        guard pressure >= 0, pressure <= policy.maximumPressure else { throw .invalidInput }
        let difference=try A.finite(abs(pressure-nodalPressure)); try A.charge(2,&work)
        integral.pressureDifference=max(integral.pressureDifference,difference)
        guard difference <= policy.pressureTolerance else { throw .residualRejected }
        return pressure
    }
    private static func quadraturePoint(_ a: Vector3,_ b: Vector3,_ c: Vector3,largeIndex: Int,work: inout NumericalWork) throws(HydroelasticError) -> Vector3 {
        let wa=try A.scale(a,largeIndex == 0 ? 2.0/3 : 1.0/6,&work)
        let wb=try A.scale(b,largeIndex == 1 ? 2.0/3 : 1.0/6,&work)
        let wc=try A.scale(c,largeIndex == 2 ? 2.0/3 : 1.0/6,&work)
        let ab=try A.add(wa,wb,&work); return try A.add(ab,wc,&work)
    }
    private static func weighted(_ a: Vector3,_ b: Vector3,_ c: Vector3,p0: Double,p1: Double,p2: Double,area: Double,work: inout NumericalWork) throws(HydroelasticError) -> Vector3 {
        try A.charge(3,&work); let sum=try A.finite(p0+p1+p2)
        let ab=try A.add(a,b,&work), points=try A.add(ab,c,&work)
        let ap=try A.scale(a,p0,&work), bp=try A.scale(b,p1,&work), cp=try A.scale(c,p2,&work)
        let abp=try A.add(ap,bp,&work), diagonal=try A.add(abp,cp,&work), all=try A.scale(points,sum,&work)
        let combined=try A.add(all,diagonal,&work); return try A.scale(combined,area/12,&work)
    }
}
