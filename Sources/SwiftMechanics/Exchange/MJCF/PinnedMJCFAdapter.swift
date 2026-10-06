public struct PinnedMJCFAdapter: MJCFSemanticCoding, MJCFModelEvaluating, Sendable {
    public let xml: any XMLDocumentCoding
    public let compiler: any MechanicalModelCompiling
    public let native: any NativeModelCoding
    public let transmitter: any ActuationTransmitting
    public let constraints: any ConstraintEvaluating
    public init(xml: any XMLDocumentCoding, compiler: any MechanicalModelCompiling, native: any NativeModelCoding,
                transmitter: any ActuationTransmitting, constraints: any ConstraintEvaluating) {
        self.xml = xml; self.compiler = compiler; self.native = native; self.transmitter = transmitter; self.constraints = constraints
    }
    public func importModel(bytes: [UInt8], context: MJCFImportContext, work: inout MJCFWork,
                            xmlWork: inout XMLWork, actuationWork: inout ActuationWork, numericalWork: inout NumericalWork) throws(MJCFError) -> MJCFImportedModel {
        try work.charge(0)
        let document: XMLDocument
        do { document = try xml.decode(bytes: bytes, work: &xmlWork) } catch { throw .xml(error) }
        return try interpret(document, context: context, work: &work, actuationWork: &actuationWork, numericalWork: &numericalWork)
    }
    internal func interpret(_ document: XMLDocument, context: MJCFImportContext, work: inout MJCFWork,
                            actuationWork: inout ActuationWork, numericalWork: inout NumericalWork) throws(MJCFError) -> MJCFImportedModel {
        let table = try MJCFElementTable(document, work: &work)
        var builder = try MJCFBodyBuilder(table: table, context: context, work: &work)
        let descriptor = try builder.descriptor(table: table, context: context, work: &work)
        try work.compilerCall()
        let compiled: CompiledMechanicalModel
        do { compiled = try compiler.compile(descriptor, policy: context.compilationPolicy) } catch { throw .compilation(error) }
        let joints = try builder.scalarJoints(compiled: compiled, work: &work)
        var features = MJCFModelFeatures()
        try features.build(table: table, defaults: builder.defaults, sections: builder.sections, context: context,
                           compiled: compiled, joints: joints, losses: &builder.losses, constraints: constraints,
                           work: &work, actuationWork: &actuationWork, numericalWork: &numericalWork)
        try work.charge(0)
        return MJCFImportedModel(context: context, document: document, compiled: compiled, bodies: builder.bindings,
                                 joints: joints, features: features, gravity: builder.gravity, losses: builder.losses)
    }
    public func exportModel(_ model: MJCFImportedModel, expectedStamp: ModelStamp, work: inout MJCFWork,
                            xmlWork: inout XMLWork, actuationWork: inout ActuationWork, numericalWork: inout NumericalWork) throws(MJCFError) -> [UInt8] {
        try identity(model, expectedStamp, work: &work)
        let replay = try interpret(model.document, context: model.context, work: &work, actuationWork: &actuationWork, numericalWork: &numericalWork)
        guard replay.nativeDocument == model.nativeDocument, replay.losses.count == model.losses.count else { throw .identityMismatch }
        for i in replay.losses.indices {
            try work.charge(1)
            let a = replay.losses[i], b = model.losses[i]
            guard a.node == b.node, a.field == b.field, a.category == b.category, a.reason == b.reason, a.source == b.source else { throw .identityMismatch }
        }
        do { return try xml.encode(document: model.document, work: &xmlWork) } catch { throw .xml(error) }
    }
    public func exportNativeStructure(_ model: MJCFImportedModel, expectedStamp: ModelStamp, work: inout MJCFWork,
                                      exchangeWork: inout ExchangeWork) throws(MJCFError) -> MJCFNativeExport {
        try identity(model, expectedStamp, work: &work)
        let loss = try MJCFBodyBuilder.loss(.nativeSidecars, node: model.document.rootIndex, field: "MJCF sidecars",
                                          reason: "Native structural encoding omits MJCF defaults, gravity, ports, sensors, materials and equality sidecars; original XML remains owned by the imported result.",
                                          source: model.context.source, work: &work)
        let bytes: [UInt8]
        do { bytes = try native.encode(document: model.nativeDocument, work: &exchangeWork) } catch { throw .native(error) }
        try work.charge(0)
        return MJCFNativeExport(bytes: bytes, loss: loss, originalSource: model.context.source)
    }
    internal func identity(_ model: MJCFImportedModel, _ stamp: ModelStamp, work: inout MJCFWork) throws(MJCFError) {
        try work.charge(1)
        guard stamp == model.compiled.stamp, stamp.identity == model.context.identity, stamp.revision == model.context.source.revision,
              model.nativeDocument.descriptor == model.compiled.descriptor else { throw .identityMismatch }
    }
    public func sample(_ model: MJCFImportedModel, state: CompiledKinematicState, controls: [Double], tolerance: NumericalTolerance,
                       work: inout MJCFWork, actuationWork: inout ActuationWork, numericalWork: inout NumericalWork) throws(MJCFError) -> MJCFModelSample {
        try identity(model, state.stamp, work: &work)
        return try MJCFModelSampler.evaluate(model, state: state, controls: controls, tolerance: tolerance, transmitter: transmitter,
                                            constraints: constraints, work: &work, actuationWork: &actuationWork, numericalWork: &numericalWork)
    }
}
