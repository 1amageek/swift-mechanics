import SwiftMechanics

/// Native Task-aware caller cancellation is separate from the synchronous portable cases.
public enum TireLawsQualificationNativeCases {
    public static func taskCancellation() async throws {
        let law:any TireRoadEvaluating=RadialBrushTireLaw()
        let sample=try TireLawsQualificationFixtures.sample(),frame=try TireLawsQualificationFixtures.frame()
        let calibration=try TireLawsQualificationFixtures.calibration(),policy=try TireLawsQualificationFixtures.policy()
        let preparedWork=try TireLawsQualificationFixtures.work(cancelled:{Task.isCancelled})
        let gate=AsyncStream<Void>.makeStream(bufferingPolicy:.bufferingNewest(1))
        defer {gate.continuation.finish()}
        let task=Task { () -> (TireLawError?,Int,Int) in
            for await _ in gate.stream {break}
            var work=preparedWork
            do throws(TireLawError) {
                _=try law.evaluate(sample:sample,frame:frame,calibration:calibration,policy:policy,work:&work)
                return (nil,work.consumed,work.peakScalars)
            } catch {return (error,work.consumed,work.peakScalars)}
        }
        task.cancel();gate.continuation.yield(())
        let (error,consumed,scalars)=await task.value
        guard let error else {throw TireLawsQualificationError.unexpectedSuccess("cancelled Native caller callback")}
        guard error == .load(.cancelled),consumed==0,scalars==0 else {throw TireLawsQualificationError.originalFailure(error)}
    }
}
