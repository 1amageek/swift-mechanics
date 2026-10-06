internal struct HydroelasticAffineCell: Sendable {
    let selection: HydroelasticCellSelection
    let reference: ReferenceTetrahedron
    let field: NodalPressureField
    let inverse: Matrix3
    let gradient: Vector3
    let basePressure: Double
    var state: NodalState { selection.representation.state }
    var cell: TetrahedronCell { reference.cell }
    var basePoint: Vector3 { state.positions[cell.nodes[0]] }
    func coordinates(_ point: Vector3,_ work: inout NumericalWork) throws(HydroelasticError) -> HydroelasticCoordinates {
        let delta=try HydroelasticArithmetic.sub(point,basePoint,&work)
        let q=try HydroelasticArithmetic.core({ () throws(CoreError) in try inverse.applying(to:delta) },&work)
        try HydroelasticArithmetic.charge(3,&work)
        return HydroelasticCoordinates(n0:try HydroelasticArithmetic.finite(1-q.x-q.y-q.z),n1:q.x,n2:q.y,n3:q.z)
    }
    func pressure(_ point: Vector3,_ work: inout NumericalWork) throws(HydroelasticError) -> Double {
        let delta=try HydroelasticArithmetic.sub(point,basePoint,&work)
        let linear=try HydroelasticArithmetic.dot(gradient,delta,&work)
        try HydroelasticArithmetic.charge(1,&work); return try HydroelasticArithmetic.finite(basePressure+linear)
    }
    func interpolate(_ weights: HydroelasticCoordinates, velocities: Bool,_ work: inout NumericalWork) throws(HydroelasticError) -> Vector3 {
        var value=Vector3.zero
        for i in 0..<4 {
            let node=cell.nodes[i], x=velocities ? state.velocities[node] : state.positions[node]
            let term=try HydroelasticArithmetic.scale(x,weights.value(i),&work)
            value=try HydroelasticArithmetic.add(value,term,&work)
        }
        return value
    }
}
