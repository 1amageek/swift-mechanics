@available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
internal final class StationaryMotionSource:Sendable {
    let physical:AffineMotionPhysical
    let catalog:StationaryLoadCatalog
    let selection:StationaryLoadSelection
    let execution:any StationaryLoadExecuting
    let drive:[Double]
    init(physical:KinematicState,catalog:StationaryLoadCatalog,selection:StationaryLoadSelection,execution:any StationaryLoadExecuting,drive:[Double]) {
        self.physical=AffineMotionPhysical(physical);self.catalog=catalog;self.selection=selection;self.execution=execution;self.drive=drive
    }
}
