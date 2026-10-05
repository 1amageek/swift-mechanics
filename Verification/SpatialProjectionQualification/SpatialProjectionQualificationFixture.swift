import SwiftMechanics

struct SpatialProjectionQualificationFixture: Sendable {
    struct Predictor: Sendable {
        let fields: [[Double]]
        let rates: [[Double]]
        let viscousPower: Double
        let donorPower: Double
        let sourcePower: Double
        let divergencePower: Double
        let injection: Double
    }
    let grid: SpatialGrid
    static func makeGrid(nx: Int = 4, ny: Int = 3, nz: Int = 5,
                         maximumStep: Double = 1) throws -> SpatialGrid {
        try SpatialGrid(id: "periodic3d", revision: 3, frame: EntityID(kind: .frame, key: "flow-inertial"),
            source: SourceProvenance(source: "independent-periodic3d", revision: 2), nx: nx, ny: ny, nz: nz,
            lengthX: Double(nx)/2, lengthY: Double(ny), lengthZ: Double(nz), density: 2, viscosity: 0.4,
            limits: SpatialLimits(maximumCells: 60, maximumMetadataBytes: 128, maximumSpeed: 100,
                maximumPressure: 1e6, maximumAcceleration: 10, maximumStep: maximumStep))
    }
    static func policy(cancelled: @escaping @Sendable () -> Bool = { false }) throws -> SpatialPolicy {
        try SpatialPolicy(pressureGaugeAbsolute: 1e-9, divergenceAbsolute: 1e-9, pressureAbsolute: 1e-8,
            pressureRelative: 1e-10, forceAbsolute: 1e-8, forceRelative: 1e-10, energyAbsolute: 1e-8,
            energyRelative: 1e-10, courantLimit: 0.5,
            linearTolerance: LinearTolerance(absoluteResidual: 1e-10, relativeResidual: 1e-12, pivotThreshold: 0),
            isCancelled: cancelled)
    }
    static func budget(storage: Int = 10000, operations: Int = 1000000,
                       iterations: Int = 100) throws -> NumericalBudget {
        try NumericalBudget(scalarStorage: storage, arithmeticOperations: operations, iterations: iterations)
    }
    static func source(_ x: Double = 0, _ y: Double = 0, _ z: Double = 0) throws -> SpatialSource {
        try SpatialSource(accelerationX: x, accelerationY: y, accelerationZ: z)
    }
    func index(_ i: Int, _ j: Int, _ k: Int) -> Int {
        let a = (i % grid.nx + grid.nx) % grid.nx
        let b = (j % grid.ny + grid.ny) % grid.ny
        let c = (k % grid.nz + grid.nz) % grid.nz
        return (c*grid.ny+b)*grid.nx+a
    }
    func at(_ field: [Double], _ i: Int, _ j: Int, _ k: Int) -> Double { field[index(i,j,k)] }
    func spacing(_ axis: Int) -> Double { [grid.dx,grid.dy,grid.dz][axis] }
    func gradient(_ field: [Double], _ axis: Int, _ i: Int, _ j: Int, _ k: Int) -> Double {
        let a = axis == 0 ? 1 : 0, b = axis == 1 ? 1 : 0, c = axis == 2 ? 1 : 0
        return (at(field,i,j,k)-at(field,i-a,j-b,k-c))/spacing(axis)
    }
    func laplacian(_ field: [Double], _ i: Int, _ j: Int, _ k: Int) -> Double {
        let center=at(field,i,j,k)
        return (at(field,i-1,j,k)-2*center+at(field,i+1,j,k))/(grid.dx*grid.dx)
             + (at(field,i,j-1,k)-2*center+at(field,i,j+1,k))/(grid.dy*grid.dy)
             + (at(field,i,j,k-1)-2*center+at(field,i,j,k+1))/(grid.dz*grid.dz)
    }
    func divergence(_ fields: [[Double]], _ i: Int, _ j: Int, _ k: Int) -> Double {
        (at(fields[0],i+1,j,k)-at(fields[0],i,j,k))/grid.dx
        + (at(fields[1],i,j+1,k)-at(fields[1],i,j,k))/grid.dy
        + (at(fields[2],i,j,k+1)-at(fields[2],i,j,k))/grid.dz
    }
    func state(_ fields: [[Double]], pressure: [Double]? = nil,
               time: Double = 2, sequence: UInt64 = 7, source: SpatialSource? = nil) throws -> SpatialState {
        try SpatialState(grid: grid, time: time, sequence: sequence, u: fields[0], v: fields[1], w: fields[2],
            pressure: pressure ?? [Double](repeating: 31, count: grid.count), source: source ?? Self.source())
    }
    func potentialAndSolenoidal() -> (potential: [Double], solenoidal: [[Double]]) {
        let x=[1.0,0,-1,0],y=[1.0,-0.5,-0.5],z=[2.0,-1,0,1,-2]
        var p=[Double](repeating: 0,count: grid.count),f=(0..<3).map { _ in [Double](repeating: 0,count: grid.count) }
        for k in 0..<grid.nz { for j in 0..<grid.ny { for i in 0..<grid.nx {
            let row=index(i,j,k)
            p[row]=x[i]+y[j]+z[k]+0.1*x[i]*y[j]*z[k]
            f[0][row]=0.04*y[j]+0.02*z[k]
            f[1][row]=0.03*z[k]+0.01*x[i]
            f[2][row]=0.02*x[i]+0.02*y[j]
        } } }
        return (p,f)
    }
    func momentum(_ fields: [[Double]]) -> [Double] {
        fields.map { $0.reduce(0,+)*grid.cellMass }
    }
    func energy(_ fields: [[Double]]) -> Double {
        var result=0.0
        for field in fields { for value in field { result += grid.cellMass*value*value/2 } }
        return result
    }
    /// Independent conservative finite-volume face quadrature in explicit3D coordinates.
    func predictor(_ state: SpatialState, source: SpatialSource, dt: Double) -> Predictor {
        let fields=[state.u,state.v,state.w],sourceValues=[source.accelerationX,source.accelerationY,source.accelerationZ]
        var updated=fields,rates=(0..<3).map { _ in [Double](repeating: 0,count: grid.count) }
        var loss=0.0,donor=0.0,power=0.0,leak=0.0,injection=0.0
        for k in 0..<grid.nz { for j in 0..<grid.ny { for i in 0..<grid.nx {
            let row=index(i,j,k)
            for component in 0..<3 {
                let original=fields[component],center=at(original,i,j,k)
                var advection=0.0,dualDivergence=0.0
                for axis in 0..<3 {
                    let da=axis == 0 ? 1 : 0,db=axis == 1 ? 1 : 0,dc=axis == 2 ? 1 : 0
                    let ca=component == 0 ? 1 : 0,cb=component == 1 ? 1 : 0,cc=component == 2 ? 1 : 0
                    let advector=fields[axis]
                    let right: Double, left: Double
                    if axis == component {
                        right=(at(advector,i,j,k)+at(advector,i+da,j+db,k+dc))/2
                        left=(at(advector,i-da,j-db,k-dc)+at(advector,i,j,k))/2
                    } else {
                        right=(at(advector,i+da,j+db,k+dc)+at(advector,i+da-ca,j+db-cb,k+dc-cc))/2
                        left=(at(advector,i,j,k)+at(advector,i-ca,j-cb,k-cc))/2
                    }
                    let rightValue=at(original,i+da,j+db,k+dc),leftValue=at(original,i-da,j-db,k-dc)
                    let fluxRight=right*(right >= 0 ? center : rightValue)
                    let fluxLeft=left*(left >= 0 ? leftValue : center)
                    advection -= (fluxRight-fluxLeft)/spacing(axis)
                    dualDivergence += (right-left)/spacing(axis)
                    let delta=rightValue-center
                    loss += grid.cellMass*grid.nu*delta*delta/(spacing(axis)*spacing(axis))
                    donor += grid.cellMass*abs(right)*delta*delta/(2*spacing(axis))
                }
                let rate=advection+grid.nu*laplacian(original,i,j,k)+sourceValues[component]
                rates[component][row]=rate;updated[component][row]=center+dt*rate
                power += grid.cellMass*center*sourceValues[component]
                leak -= grid.cellMass*center*center*dualDivergence/2
                injection += grid.cellMass*dt*dt*rate*rate/2
            }
        } } }
        return Predictor(fields: updated,rates: rates,viscousPower: loss,donorPower: donor,
            sourcePower: power,divergencePower: leak,injection: injection)
    }
}
