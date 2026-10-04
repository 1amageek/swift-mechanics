import SwiftMechanics
import Testing
struct FluidCodecTests {
    @Test func exactPhysicalBindingAndMalformedRecords() throws {
        let c=try FluidFixtures.channel(cells:4),b=try FluidFixtures.boundary(gradient:-2)
        let codec=try FixedFluidContinuationCodec(channel:c,contributorID:"fluid",maximumBytes:4096,pressureGradientTolerance:1e-8)
        let state=try FluidFixtures.state(channel:c,boundary:b,velocities:[1,2,3,4])
        var work=try FluidByteWork(maximumBytes:10000,maximumVisitedBytes:100000)
        let record=try codec.encode(state,work:&work); #expect(try codec.decode(record,work:&work) == state)
        let short=try RuntimeContributorState(id:"fluid",category:.integrator,version:1,bytes:Array(record.bytes.dropLast()))
        FluidFixtures.failure(.staleBinding) { () throws(FluidError) in _=try codec.decode(short,work:&work) }
        let long=try RuntimeContributorState(id:"fluid",category:.integrator,version:1,bytes:record.bytes+[0])
        FluidFixtures.failure(.staleBinding) { () throws(FluidError) in _=try codec.decode(long,work:&work) }
        var changed=record.bytes; changed[0] ^= 1
        let bad=try RuntimeContributorState(id:"fluid",category:.integrator,version:1,bytes:changed)
        FluidFixtures.failure(.staleBinding) { () throws(FluidError) in _=try codec.decode(bad,work:&work) }
        // Corrupt first velocity to NaN without altering identity header.
        let dynamic=record.bytes.count-(2*c.cells+7)*8
        changed=record.bytes; let nan=Double.nan.bitPattern
        for i in 0..<8 { changed[dynamic+48+i]=UInt8(truncatingIfNeeded:nan >> (8*i)) }
        let nonfinite=try RuntimeContributorState(id:"fluid",category:.integrator,version:1,bytes:changed)
        FluidFixtures.failure(.nonfinite) { () throws(FluidError) in _=try codec.decode(nonfinite,work:&work) }
        var tiny=try FluidByteWork(maximumBytes:0,maximumVisitedBytes:100000)
        FluidFixtures.failure(.capacity) { () throws(FluidError) in _=try codec.decode(record,work:&tiny) }
        #expect(throws:FluidError.self) { _=try FixedFluidContinuationCodec(channel:c,contributorID:"fluid",maximumBytes:8,pressureGradientTolerance:1e-8) }
        let other=try FixedFluidContinuationCodec(channel:FluidFixtures.channel(cells:4,mu:2),contributorID:"fluid",maximumBytes:4096,pressureGradientTolerance:1e-8)
        FluidFixtures.failure(.staleBinding) { () throws(FluidError) in _=try other.decode(record,work:&work) }
    }
    @Test func hydrostaticCorruptionCannotPassLocalValidation() throws {
        let c=try FluidFixtures.channel(cells:4,rho:10,gy:-2),b=try FluidFixtures.boundary(pressure:100)
        let codec=try FixedFluidContinuationCodec(channel:c,contributorID:"fluid",maximumBytes:4096,pressureGradientTolerance:1e-8)
        let state=try FluidFixtures.state(channel:c,boundary:b);var work=try FluidByteWork(maximumBytes:10000,maximumVisitedBytes:100000)
        let good=try codec.encode(state,work:&work); var changed=good.bytes
        let last=Double(99).bitPattern; for i in 0..<8 { changed[changed.count-8+i]=UInt8(truncatingIfNeeded:last >> (8*i)) }
        let record=try RuntimeContributorState(id:"fluid",category:.integrator,version:1,bytes:changed)
        FluidFixtures.failure(.originalResidual) { () throws(FluidError) in _=try codec.decode(record,work:&work) }
    }
}
