import SwiftMechanics

public enum WheeledAssembliesQualificationNativeCases {
    public static func taskCancellation() async throws {
        let fixture=try WheeledAssembliesQualificationFixture()
        let driver=try WheeledAssembliesQualificationFixture.driver(),road=try fixture.road()
        let preparedWork=try WheeledAssembliesQualificationFixture.work()
        let gate=AsyncStream<Void>.makeStream(bufferingPolicy:.bufferingNewest(1))
        defer {gate.continuation.finish()}
        let task=Task { () -> (WheeledAssemblyFailure?,Int) in
            for await _ in gate.stream {break}
            var work=preparedWork
            do throws(WheeledAssemblyFailure) {
                _=try fixture.assembly.query(state:fixture.state,driver:driver,road:road,work:&work)
                return (nil,work.numerical.operations)
            } catch {return (error,work.numerical.operations)}
        }
        task.cancel();gate.continuation.yield(())
        let (error,operations)=await task.value
        guard let error else {throw WheeledAssembliesQualificationError.unexpectedSuccess("cancelled Native query")}
        guard case .refusal(.cancelled)=error,operations==0 else {throw WheeledAssembliesQualificationError.originalFailure(error)}
    }
}
