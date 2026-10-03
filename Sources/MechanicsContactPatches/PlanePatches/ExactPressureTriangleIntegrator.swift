import MechanicsCore
import MechanicsFlexible
import MechanicsNumerics
internal enum ExactPressureTriangleIntegrator {
    @inline(never)
    static func integrate(_ a: PatchVertex,_ b: PatchVertex,_ c: PatchVertex,cell: TetrahedronCell,state: NodalState,plane: RigidPressurePlane,origin: Vector3,
                          policy: PatchPolicy,nodal: inout [Vector3],integral: inout PatchIntegral,work: inout NumericalWork) throws(PatchError) -> PressureTriangle {
        let cross=try PatchArithmetic.cross(PatchArithmetic.sub(b.point,a.point,&work),PatchArithmetic.sub(c.point,a.point,&work),&work)
        guard try PatchArithmetic.dot(cross,plane.normal,&work) > 0 else { throw .degenerateCut }
        try PatchArithmetic.charge(5,&work)
        let area=try PatchArithmetic.finite(0.5*PatchArithmetic.norm(cross,&work))
        guard area >= policy.minimumTriangleArea else { throw .degenerateCut }
        let sum=try PatchArithmetic.finite(a.pressure+b.pressure+c.pressure), pressure=try PatchArithmetic.finite(area*sum/3)
        let xp=try weighted(a.point,b.point,c.point,p0:a.pressure,p1:b.pressure,p2:c.pressure,area:area,work:&work)
        let force=try PatchArithmetic.scale(plane.normal,pressure,&work)
        let moment=try PatchArithmetic.cross(PatchArithmetic.sub(xp,PatchArithmetic.scale(origin,pressure,&work),&work),plane.normal,&work)
        integral.force=try PatchArithmetic.add(integral.force,force,&work); integral.moment=try PatchArithmetic.add(integral.moment,moment,&work)
        try PatchArithmetic.charge(2,&work); integral.area=try PatchArithmetic.finite(integral.area+area); integral.pressure=try PatchArithmetic.finite(integral.pressure+pressure)
        for i in 0..<4 {
            try PatchArithmetic.charge(12,&work)
            let load=try PatchArithmetic.finite(area*((a.weights.value(i)+b.weights.value(i)+c.weights.value(i))*sum+a.weights.value(i)*a.pressure+b.weights.value(i)*b.pressure+c.weights.value(i)*c.pressure)/12)
            let node=cell.nodes[i]
            nodal[node]=try PatchArithmetic.sub(nodal[node],PatchArithmetic.scale(plane.normal,load,&work),&work)
        }
        // Independent surface velocity interpolation path, separate from assembled nodal load power.
        let va=try velocity(a.weights,cell:cell,state:state,work:&work), vb=try velocity(b.weights,cell:cell,state:state,work:&work), vc=try velocity(c.weights,cell:cell,state:state,work:&work)
        let vp=try weighted(va,vb,vc,p0:a.pressure,p1:b.pressure,p2:c.pressure,area:area,work:&work)
        integral.pressureVelocity=try PatchArithmetic.add(integral.pressureVelocity,vp,&work)
        return PressureTriangle(cellIdentifier:cell.identifier,first:a.point,second:b.point,third:c.point,firstPressure:a.pressure,secondPressure:b.pressure,thirdPressure:c.pressure,area:area)
    }
    private static func weighted(_ a: Vector3,_ b: Vector3,_ c: Vector3,p0: Double,p1: Double,p2: Double,area: Double,work: inout NumericalWork) throws(PatchError) -> Vector3 {
        try PatchArithmetic.charge(3,&work)
        let sum=try PatchArithmetic.finite(p0+p1+p2), scale=try PatchArithmetic.finite(area/12)
        let points=try PatchArithmetic.add(PatchArithmetic.add(a,b,&work),c,&work)
        let diagonal=try PatchArithmetic.add(PatchArithmetic.add(PatchArithmetic.scale(a,p0,&work),PatchArithmetic.scale(b,p1,&work),&work),PatchArithmetic.scale(c,p2,&work),&work)
        return try PatchArithmetic.scale(PatchArithmetic.add(PatchArithmetic.scale(points,sum,&work),diagonal,&work),scale,&work)
    }
    private static func velocity(_ weights: PatchBarycentricWeights,cell: TetrahedronCell,state: NodalState,work: inout NumericalWork) throws(PatchError) -> Vector3 {
        var value=Vector3.zero
        for i in 0..<4 { value=try PatchArithmetic.add(value,PatchArithmetic.scale(state.velocities[cell.nodes[i]],weights.value(i),&work),&work) }
        return value
    }
}
