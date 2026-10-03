import MechanicsCore

public struct TranslationCollisionSweeper: CollisionSweeping, Sendable {
    public init() {}

    public func timeOfImpact(first: CollisionSweep, second: CollisionSweep, durationSeconds: Double,
                             maximumTimeWidthSeconds: Double, policy: CollisionQueryPolicy,
                             work: inout CollisionWork) throws(CollisionError) -> CollisionTOIBracket? {
        guard durationSeconds.isFinite, durationSeconds > 0, maximumTimeWidthSeconds.isFinite,
              maximumTimeWidthSeconds > 0 else { throw .invalidPolicy }
        try work.requireStorage(768); try work.requireRecords(1); try work.charge(2048)
        switch (first.start.geometry.shape,second.start.geometry.shape) {
        case (.sphere,.sphere),(.sphere,.halfSpace),(.halfSpace,.sphere): break
        // FIXME(INCOMPLETE_IMPLEMENTATION): Other declared shape-pair sweeps are deferred. CCD consumers
        // receive a typed failure until conservative brackets on their original equations are verified.
        default: throw .unsupportedSweep
        }
        let geometry: any CollisionGeometryQuerying = AnalyticCollisionQueries()
        let initial = try geometry.witness(first:first.start,second:second.start,policy:policy,work:&work)
        if initial.separation <= 0 {
            return CollisionTOIBracket(lowerTime:0,upperTime:0,lowerSeparation:initial.separation,
                upperSeparation:initial.separation,upperWitness:initial,initialOverlap:true,iterations:0)
        }
        let minimumFraction: Double
        if case .sphere = first.start.geometry.shape, case .sphere = second.start.geometry.shape {
            let d0 = try collisionCore { () throws(CoreError) in try second.start.pose.translation.subtracting(first.start.pose.translation) }
            let velocity = try collisionCore { () throws(CoreError) in
                try second.end.pose.translation.subtracting(second.start.pose.translation)
                    .subtracting(first.end.pose.translation.subtracting(first.start.pose.translation))
            }
            let squared = try collisionCore { () throws(CoreError) in try velocity.dot(velocity) }
            if squared == 0 { minimumFraction = 0 }
            else {
                let numerator = try collisionCore { () throws(CoreError) in try d0.dot(velocity) }
                minimumFraction = max(0,min(1,try collisionFinite(-numerator/squared)))
            }
        } else {
            let endpoint = try geometry.witness(first:first.end,second:second.end,policy:policy,work:&work)
            minimumFraction = endpoint.separation < initial.separation ? 1 : 0
        }
        let minimum = try geometry.witness(first:first.proxy(at:minimumFraction),second:second.proxy(at:minimumFraction),policy:policy,work:&work)
        if minimum.separation > policy.lengthTolerance { return nil }
        guard minimum.separation <= 0 else { throw .unresolvedMinimum(separation:minimum.separation) }
        var lower = 0.0, upper = minimumFraction
        var lowerSeparation = initial.separation
        var upperWitness = minimum
        let initialIterations = work.iterations
        while try collisionFinite((upper-lower)*durationSeconds) > maximumTimeWidthSeconds {
            try work.advanceIteration(); try work.charge(1024)
            let middle = lower+(upper-lower)/2
            guard middle > lower, middle < upper else { throw .nonConvergence(iterations:work.iterations-initialIterations) }
            let witness = try geometry.witness(first:first.proxy(at:middle),second:second.proxy(at:middle),policy:policy,work:&work)
            // A rounded zero before a zero minimum does not prove that this earlier time is contact.
            // Retaining the minimum endpoint avoids excluding the actual tangent from an accepted bracket.
            if minimum.separation == 0 && witness.separation <= 0 {
                throw .unresolvedMinimum(separation:witness.separation)
            }
            if witness.separation > 0 { lower = middle; lowerSeparation = witness.separation }
            else { upper = middle; upperWitness = witness }
        }
        guard lowerSeparation > 0, upperWitness.separation <= 0 else { throw .nonConvergence(iterations:work.iterations-initialIterations) }
        return CollisionTOIBracket(lowerTime:try collisionFinite(lower*durationSeconds),
            upperTime:try collisionFinite(upper*durationSeconds),lowerSeparation:lowerSeparation,
            upperSeparation:upperWitness.separation,upperWitness:upperWitness,initialOverlap:false,
            iterations:work.iterations-initialIterations)
    }
}
