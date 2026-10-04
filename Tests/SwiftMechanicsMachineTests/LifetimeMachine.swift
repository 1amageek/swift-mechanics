import SwiftMechanics

@available(macOS 15.0, *)
final class LifetimeMachine: Machine {
    let counter: MachineCounter
    let record: BodyRecord3D
    init(counter: MachineCounter, record: BodyRecord3D) { self.counter = counter; self.record = record }
    deinit { counter.release() }
    var body: some Machine { MachineBody(record) }
}
