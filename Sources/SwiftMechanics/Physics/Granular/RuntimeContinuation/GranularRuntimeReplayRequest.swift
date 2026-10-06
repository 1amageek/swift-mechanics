internal final class GranularRuntimeReplayRequest: Sendable {
    let record: RuntimeContributorState
    let time: UInt64
    let steps: UInt64
    let seed: UInt64
    let state: UInt64
    let draws: UInt64
    let count: Int
    let cursor: Int
    init(record: RuntimeContributorState,time: UInt64,steps: UInt64,seed: UInt64,state: UInt64,draws: UInt64,count: Int,cursor: Int) {
        self.record=record;self.time=time;self.steps=steps;self.seed=seed;self.state=state;self.draws=draws;self.count=count;self.cursor=cursor
    }
}
