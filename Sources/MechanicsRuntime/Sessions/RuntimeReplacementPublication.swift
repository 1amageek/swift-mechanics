@available(macOS 15.0,iOS 18.0,tvOS 18.0,watchOS 11.0,*)
internal final class RuntimeReplacementPublication: Sendable {
    let context: RuntimeSessionContext
    let workspace: RuntimeTrial
    let scalarSlots: Int
    init(context: RuntimeSessionContext, workspace: RuntimeTrial, scalarSlots: Int) {
        self.context=context;self.workspace=workspace;self.scalarSlots=scalarSlots
    }
}
