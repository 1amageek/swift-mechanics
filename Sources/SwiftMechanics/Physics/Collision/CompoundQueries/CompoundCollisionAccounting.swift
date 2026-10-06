internal enum CompoundCollisionAccounting {
    static func run<Value>(_ operation: () throws(CollisionError) -> Value) throws(CompoundCollisionError) -> Value {
        do { return try operation() } catch { throw .collision(error) }
    }

    static func storage(children: Int, outputs: Int, work: inout CollisionWork) throws(CompoundCollisionError) {
        try run { () throws(CollisionError) in
            // Retained local/world proxies, result wrappers, and complete analytic scratch coexist.
            // Output slots cover reserved declared capacity, not just populated records.
            let count = try CollisionWork.sum(256, CollisionWork.sum(CollisionWork.product(160, children), CollisionWork.product(512, outputs)))
            try work.requireStorage(count)
        }
    }

    static func text(_ value: String, bytes: inout Int, policy: CompoundCollisionPolicy,
                     work: inout CollisionWork) throws(CompoundCollisionError) {
        for _ in value.utf8 {
            try run { () throws(CollisionError) in try work.charge(1) }
            guard bytes < policy.maximumMetadataBytes else { throw .metadataLimit(limit: policy.maximumMetadataBytes) }
            bytes += 1
        }
    }

    static func child<Value>(first: EntityID, second: EntityID?,
                             _ operation: () throws(CollisionError) -> Value) throws(CompoundCollisionError) -> Value {
        do { return try operation() } catch { throw .child(first: first, second: second, cause: error) }
    }
}
