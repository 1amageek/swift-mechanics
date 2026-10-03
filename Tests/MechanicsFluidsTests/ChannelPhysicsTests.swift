import Testing
import MechanicsCore
import MechanicsModel
import MechanicsCompiler
import MechanicsNumerics
import MechanicsFluids
struct ChannelPhysicsTests {
    @Test func hydrostaticOriginalGradientAndGauge() throws {
        let c=try FluidFixtures.channel(cells:16,rho:1000,gy:-9.81),b=try FluidFixtures.boundary(pressure:100000)
        let state=try FluidFixtures.state(channel:c,boundary:b)
        for j in 0...c.cells { #expect(abs(state.pressureFaces[j]-(100000-9810*Double(j)/16)) < 1e-8) }
        for i in 0..<c.cells {
            let pressureForce=c.wallArea*(state.pressureFaces[i+1]-state.pressureFaces[i])
            let gravityForce=c.cellMass*c.accelerationY
            #expect(abs(pressureForce-gravityForce) < 1e-8)
        }
    }
    @Test func couetteShearPowerAndPoiseuilleRefinement() throws {
        for n in [1,4,16] {
            let c=try FluidFixtures.channel(cells:n),b=try FluidFixtures.boundary(lower:-1,upper:3),old=try FluidFixtures.state(channel:c,boundary:b)
            var w=try FluidFixtures.work(); let result=try FluidFixtures.solver().steady(state:old,boundary:b,policy:FluidFixtures.policy(),work:&w)
            for i in 0..<n { #expect(abs(result.state.velocities[i]-(-1+4*(Double(i)+0.5)/Double(n))) < 1e-10) }
            #expect(abs(result.balance.viscousPower-32) < 1e-9)
            #expect(abs(result.balance.boundaryPower-32) < 1e-9)
            #expect(result.balance.numericalDissipation == 0)
        }
        var previous=Double.infinity
        for n in [2,4,8,16] {
            let c=try FluidFixtures.channel(cells:n),b=try FluidFixtures.boundary(gradient:-2),old=try FluidFixtures.state(channel:c,boundary:b)
            var w=try FluidFixtures.work(); let result=try FluidFixtures.solver().steady(state:old,boundary:b,policy:FluidFixtures.policy(),work:&w)
            var error=0.0
            for i in 0..<n { let y=(Double(i)+0.5)/Double(n); error=max(error,abs(result.state.velocities[i]-y*(1-y))) }
            #expect(abs(error-0.25/Double(n*n)) < 1e-10)
            #expect(error < previous/3.9); previous=error
            #expect(result.balance.maximumMomentumResidual < 1e-9)
            #expect(abs(result.balance.sourcePower-result.balance.viscousPower) < 1e-9)
        }
    }
    @Test func domainsCapacityAndOverflowRejectBeforeFieldPublication() throws {
        let c=try FluidFixtures.channel(),b=try FluidFixtures.boundary(upper:101)
        var w=try FluidFixtures.work(); let p=try FluidFixtures.policy()
        FluidFixtures.failure(.domain) { () throws(FluidError) in _=try ReferenceFluidFieldBuilder().makeState(channel:c,boundary:b,time:0,velocities:[Double](repeating:0,count:8),policy:p,work:&w) }
        let zero=try FluidFixtures.boundary(),old=try FluidFixtures.state(channel:c,boundary:zero)
        FluidFixtures.failure(.domain) { () throws(FluidError) in _=try FluidFixtures.solver().step(state:old,boundary:zero,duration:0,policy:p,work:&w) }
        FluidFixtures.failure(.domain) { () throws(FluidError) in _=try FluidFixtures.solver().step(state:old,boundary:zero,duration:11,policy:p,work:&w) }
        #expect(throws:FluidError.self) { _=try FluidFixtures.channel(cells:65) }
        #expect(throws:FluidError.self) { _=try FluidFixtures.channel(mu:0) }
        #expect(throws:FluidError.self) { _=try FluidFixtures.channel(mu:Double.greatestFiniteMagnitude) }
        #expect(throws:FluidError.self) { _=try FluidBoundary(lowerSpeed:.nan,upperSpeed:0,pressureGradientX:0,lowerGaugePressure:0) }
    }
}
