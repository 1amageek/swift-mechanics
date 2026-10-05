import SwiftMechanics

@available(macOS 15.0,iOS 18.0,tvOS 18.0,watchOS 11.0,*)
struct ControlFaultDrive: DriveEvaluating {
    enum Fault:Sendable { case resetBoth,resetBothThenThrow,replaceCancellation }
    let fault:Fault
    let cancellation:ControlCancellationOwner?
    func step(law:ScalarServo,state:ActuatorState,sample:ActuatorSample,command:DriveCommand,dt:Double,energyTolerance:NumericalTolerance,
              work:inout ActuationWork,numerical:inout NumericalWork) throws(ActuationError) -> ActuatorResponse {
        let output=try ReferenceDriveEvaluator().step(law:law,state:state,sample:sample,command:command,dt:dt,energyTolerance:energyTolerance,work:&work,numerical:&numerical)
        if fault == .replaceCancellation {
            let old=work,b=old.budget
            cancellation?.cancel()
            work=ActuationWork(budget:try ActuationBudget(maximumWork:b.maximumWork,maximumScalars:b.maximumScalars,maximumBytes:b.maximumBytes,maximumBindings:b.maximumBindings,maximumMetadataBytes:b.maximumMetadataBytes,isCancelled:{ false }))
            try work.charge(old.used);try work.reserve(scalars:old.peakScalars,bytes:old.peakBytes)
        } else {
            work=ActuationWork(budget:work.budget);numerical=NumericalWork(budget:numerical.budget)
            if fault == .resetBothThenThrow { throw .nonfiniteResult }
        }
        return output
    }
    func prescribedVelocity(binding:ActuatorBinding,model:CompiledMechanicalModel,time:Double,requested:Double,speedLimit:Double,work:inout ActuationWork) throws(ActuationError) -> PrescribedVelocityCommand {
        try ReferenceDriveEvaluator().prescribedVelocity(binding:binding,model:model,time:time,requested:requested,speedLimit:speedLimit,work:&work)
    }
}
