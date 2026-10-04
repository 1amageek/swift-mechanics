import SwiftMechanics

@available(macOS 999.0, *)
struct FutureMachine: Machine {
    let record: BodyRecord3D
    var body: some Machine { MachineBody(record) }
}
