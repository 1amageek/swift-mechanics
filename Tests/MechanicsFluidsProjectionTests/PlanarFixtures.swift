import Testing
import CMechanicsMath
import MechanicsCore
import MechanicsModel
import MechanicsNumerics
import MechanicsFluids
struct PlanarFixtures {
    static let pi=3.14159265358979323846
    static func grid(nx:Int=6,ny:Int=6,lengthX:Double=2*pi,lengthY:Double=2*pi,rho:Double=1,mu:Double=0.1) throws -> PlanarGrid {
        try PlanarGrid(id:"periodic-MAC",revision:1,frame:EntityID(kind:.frame,key:"fixed-world"),source:SourceProvenance(source:"projection-fixture",revision:1),
            nx:nx,ny:ny,lengthX:lengthX,lengthY:lengthY,depth:0.5,density:rho,viscosity:mu,
            limits:PlanarLimits(maximumCells:256,maximumMetadataBytes:1024,maximumSpeed:10,maximumPressure:10000,maximumAcceleration:10,maximumStep:1))
    }
    static func source(_ x:Double=0,_ y:Double=0) throws -> PlanarSource { try PlanarSource(accelerationX:x,accelerationY:y) }
    static func policy(cancel:@escaping @Sendable ()->Bool={false}) throws -> PlanarPolicy {
        try PlanarPolicy(divergenceAbsolute:1e-9,pressureAbsolute:1e-8,pressureRelative:1e-9,forceAbsolute:1e-8,
            forceRelative:1e-9,energyAbsolute:1e-9,energyRelative:1e-9,courantLimit:0.9,
            linearTolerance:LinearTolerance(absoluteResidual:1e-9,relativeResidual:1e-11,pivotThreshold:1e-14),isCancelled:cancel)
    }
    static func work() throws -> NumericalWork { NumericalWork(budget:try NumericalBudget(scalarStorage:1000000,arithmeticOperations:200000000,iterations:100000)) }
    static func solver()->any PlanarFlowOperating { ReferencePlanarFlowSolver(linear:ReferenceLinearSolver<Double>()) }
    static func state(_ g:PlanarGrid,u:[Double],v:[Double]) throws -> PlanarState {
        try PlanarState(grid:g,time:0,sequence:0,u:u,v:v,pressure:[Double](repeating:0,count:g.count),source:source())
    }
    static func vortex(_ g:PlanarGrid) throws -> PlanarState {
        var u=[Double](repeating:0,count:g.count),v=[Double](repeating:0,count:g.count)
        for j in 0..<g.ny { for i in 0..<g.nx {
            let k=j*g.nx+i
            u[k]=sm_sin(Double(i)*g.dx)*sm_cos((Double(j)+0.5)*g.dy)
            v[k] = -sm_cos((Double(i)+0.5)*g.dx)*sm_sin(Double(j)*g.dy)
        } }
        return try state(g,u:u,v:v)
    }
    static func failure(_ expected:PlanarFluidError,_ body:() throws(PlanarFluidError)->Void) {
        do throws(PlanarFluidError) { try body();Issue.record("Expected planar fluid failure") } catch { #expect(error == expected) }
    }
    static func divergence(_ s:PlanarState,at k:Int)->Double {
        let g=s.grid,i=k%g.nx,j=k/g.nx,right=j*g.nx+(i+1)%g.nx,top=((j+1)%g.ny)*g.nx+i
        return (s.u[right]-s.u[k])/g.dx+(s.v[top]-s.v[k])/g.dy
    }
}
