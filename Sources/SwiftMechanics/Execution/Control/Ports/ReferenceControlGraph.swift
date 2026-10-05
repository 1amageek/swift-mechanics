public struct ReferenceControlGraph: ControlGraphAdmitting, Sendable {
    public init() {}
    public func admit(dimensions:[PhysicalDimension],directFeedthrough:[Bool],connections:[ControlConnection],policy:ControlPolicy,work:inout NumericalWork) throws(ControlFailure) {
        let n=dimensions.count
        guard n > 0,n <= policy.maximumGraphNodes,directFeedthrough.count == n,connections.count <= policy.maximumGraphEdges else { throw ControlFailure(.capacity,phase:"graph") }
        do { try work.requireStorage(try NumericalWork.product(2,n)) } catch { throw ControlFailure(.numerical(error),phase:"graph") }
        var degree=[Int](repeating:0,count:n),removed=[Bool](repeating:false,count:n)
        for (i,edge) in connections.enumerated() {
            try ControlArithmetic.charge(8,work:&work,policy:policy)
            guard edge.source >= 0,edge.source < n,edge.destination >= 0,edge.destination < n,
                  dimensions[edge.source] == edge.dimension,dimensions[edge.destination] == edge.dimension else { throw ControlFailure(.incompatiblePort,phase:"graph") }
            for j in 0..<i {
                try ControlArithmetic.charge(1,work:&work,policy:policy)
                guard connections[j].source != edge.source || connections[j].destination != edge.destination else { throw ControlFailure(.invalidInput,phase:"graph") }
            }
            if directFeedthrough[edge.destination] { degree[edge.destination] += 1 }
        }
        for _ in 0..<n {
            var next:Int?
            for i in 0..<n {
                try ControlArithmetic.charge(1,work:&work,policy:policy)
                if !removed[i],degree[i] == 0 { next=i;break }
            }
            guard let next else { throw ControlFailure(.algebraicLoop,phase:"graph") }
            removed[next]=true
            for edge in connections {
                try ControlArithmetic.charge(1,work:&work,policy:policy)
                if edge.source == next,directFeedthrough[edge.destination] { degree[edge.destination] -= 1 }
            }
        }
    }
}
