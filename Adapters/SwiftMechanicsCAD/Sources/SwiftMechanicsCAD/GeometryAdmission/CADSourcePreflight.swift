import CADCore
import CADIR
import SwiftMechanics

struct CADSourcePreflight {
    let limits: CADGeometryLimits
    private var nodes = 0
    private var metadata = 0

    init(limits: CADGeometryLimits) { self.limits = limits }

    mutating func validate(_ document: CADDocument, requests: [CADOccurrenceRequest],
                           work: inout CADAdapterWork) throws(CADAdapterError) {
        try work.charge()
        guard document.designGraph.nodes.count <= limits.maximumFeatures,
              document.designGraph.order.count <= limits.maximumFeatures,
              document.parameters.parameters.count <= limits.maximumParameters,
              requests.count <= limits.maximumOccurrences else { throw .capacityExceeded }
        guard !document.designGraph.nodes.isEmpty, !requests.isEmpty,
              document.designGraph.dependencies.isEmpty,
              document.selectionDimensions.isEmpty else { throw .unsupportedSource }
        try string(document.metadata.name, work: &work)
        for parameter in document.parameters.parameters.values {
            try work.charge()
            try string(parameter.name, work: &work)
            try expression(parameter.expression, in: document.parameters, work: &work)
        }
        for (_, feature) in document.designGraph.nodes {
            try work.charge()
            guard !feature.isSuppressed, feature.inputs.isEmpty else { throw .unsupportedSource }
            guard feature.outputs.count <= limits.maximumTopologyRecords else { throw .capacityExceeded }
            try work.charge(feature.outputs.count)
            try string(feature.name, work: &work)
            switch feature.operation {
            case .primitive(let primitive):
                switch primitive.definition {
                case .box(let b):
                    try expression(b.width, in: document.parameters, work: &work)
                    try expression(b.depth, in: document.parameters, work: &work)
                    try expression(b.height, in: document.parameters, work: &work)
                case .cylinder(let c):
                    try expression(c.radius, in: document.parameters, work: &work)
                    try expression(c.height, in: document.parameters, work: &work)
                case .cone(let c):
                    try expression(c.baseRadius, in: document.parameters, work: &work)
                    try expression(c.height, in: document.parameters, work: &work)
                case .sphere(let s): try expression(s.radius, in: document.parameters, work: &work)
                case .torus(let t):
                    try expression(t.majorRadius, in: document.parameters, work: &work)
                    try expression(t.minorRadius, in: document.parameters, work: &work)
                }
            case .involuteGear(let gear):
                guard gear.dimensions.count <= limits.maximumExpressionNodes else { throw .capacityExceeded }
                for value in gear.dimensions.values {
                    try expression(value, in: document.parameters, work: &work)
                }
            default: throw .unsupportedSource
            }
        }
        var occurrenceIDs = Set<String>(), bodyIDs = Set<SwiftMechanics.EntityID>(), frameIDs = Set<SwiftMechanics.EntityID>()
        for request in requests {
            try work.charge()
            guard !request.id.isEmpty, request.body.kind == .body, request.frame.kind == .frame else { throw .invalidInput }
            try string(request.id, work: &work)
            try string(request.body.key, work: &work)
            try string(request.frame.key, work: &work)
            try string(request.material.name, work: &work)
            guard occurrenceIDs.insert(request.id).inserted,
                  bodyIDs.insert(request.body).inserted,
                  frameIDs.insert(request.frame).inserted else { throw .duplicateOccurrence }
            guard document.designGraph.nodes[request.sourceFeature] != nil else { throw .missingBody }
            try cadCall { try request.material.validate() }
            guard let density = request.material.density, density.isFinite, density > 0 else { throw .missingDensity }
        }
    }

    private mutating func string(_ value: String?, work: inout CADAdapterWork) throws(CADAdapterError) {
        guard let value else { return }
        let count = value.utf8.count
        let sum = metadata.addingReportingOverflow(count)
        guard !sum.overflow, sum.partialValue <= limits.maximumMetadataBytes else { throw .capacityExceeded }
        try work.charge(count)
        metadata = sum.partialValue
    }

    private mutating func expression(_ value: CADExpression, in table: ParameterTable,
                                     work: inout CADAdapterWork) throws(CADAdapterError) {
        // Iterative traversal bounds recursive original expression/parameter validation first.
        var pending: [(CADExpression, Int, [ParameterID])] = []
        func checkedDepth(_ depth: Int) throws(CADAdapterError) {
            guard depth <= limits.maximumExpressionDepth else { throw .capacityExceeded }
        }
        try checkedDepth(1)
        pending.append((value, 1, []))
        while let (value, depth, path) = pending.popLast() {
            try work.charge()
            guard nodes < limits.maximumExpressionNodes else { throw .capacityExceeded }
            nodes += 1
            var children: [CADExpression] = []
            var childPath = path
            switch value {
            case .constant: break
            case .variable(let name, _): try string(name, work: &work)
            case .reference(let id):
                guard !path.contains(id) else { throw .unsupportedSource }
                guard let parameter = table.parameters[id] else { throw .parameter(.unknownReference(id)) }
                guard depth < limits.maximumExpressionDepth else { throw .capacityExceeded }
                childPath.append(id)
                children = [parameter.expression]
            case .add(let a, let b), .subtract(let a, let b), .multiply(let a, let b),
                 .divide(let a, let b), .hypot(let a, let b): children = [a, b]
            case .sin(let a), .cos(let a), .tan(let a): children = [a]
            case .bezierNaturalExtension(let coordinates, let length, _),
                 .bezierShapedExtension(_, let coordinates, let length, _):
                guard coordinates.count < limits.maximumExpressionNodes else { throw .capacityExceeded }
                children = coordinates
                children.append(length)
            }
            if !children.isEmpty {
                guard depth < limits.maximumExpressionDepth else { throw .capacityExceeded }
                let required = pending.count.addingReportingOverflow(children.count)
                guard !required.overflow, required.partialValue <= limits.maximumExpressionNodes - nodes else { throw .capacityExceeded }
                for child in children { pending.append((child, depth + 1, childPath)) }
            }
        }
    }
}
