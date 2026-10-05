public struct MatrixFreeSpatialPressureSolver: SpatialPressureSolving, Sendable {
    public init() {}
    public func solve(grid:SpatialGrid,rightHandSide:[Double],tolerance:LinearTolerance<Double>,budget:NumericalBudget,
                      isCancelled:@Sendable ()->Bool) throws(NumericalError)->SpatialPressureSolution {
        let n=grid.count
        guard rightHandSide.count == n else { throw .invalidDimensions }
        var work=NumericalWork(budget:budget)
        try poll(isCancelled)
        try work.requireStorage(try NumericalWork.product(6,n))
        // Three zero-filled vectors plus the residual COW copy materialized by removeMean.
        // Charge the checked upper bound before any vector allocation or copy occurs.
        try work.chargeOperations(try NumericalWork.product(4,n))
        var x=[Double](repeating:0,count:n),residual=rightHandSide
        var direction=[Double](repeating:0,count:n),image=[Double](repeating:0,count:n)
        var rhsNorm=0.0
        for k in 0..<n {
            try poll(isCancelled);try work.chargeOperations(4)
            guard rightHandSide[k].isFinite else { throw .nonFiniteInput }
            rhsNorm=max(rhsNorm,abs(rightHandSide[k]))
        }
        let threshold=try tolerance.threshold(scale:rhsNorm)
        try removeMean(&residual,work:&work,isCancelled:isCancelled)
        for k in 0..<n { try poll(isCancelled);try work.chargeOperations(1);direction[k]=residual[k] }
        var rr=try dot(residual,residual,work:&work,isCancelled:isCancelled)
        while true {
            try poll(isCancelled)
            try apply(x,into:&image,grid:grid,work:&work,isCancelled:isCancelled)
            var original=0.0,productNorm=0.0
            for k in 0..<n {
                try poll(isCancelled);try work.chargeOperations(1)
                original=max(original,abs(image[k]-rightHandSide[k]));productNorm=max(productNorm,abs(image[k]))
            }
            let originalThreshold=try tolerance.threshold(scale:max(rhsNorm,productNorm))
            if original <= originalThreshold {
                try removeMean(&x,work:&work,isCancelled:isCancelled)
                // Gauge normalization is rechecked against the original equation.
                try apply(x,into:&image,grid:grid,work:&work,isCancelled:isCancelled)
                var finalResidual=0.0,finalScale=rhsNorm
                for k in 0..<n {
                    try poll(isCancelled);try work.chargeOperations(1)
                    finalResidual=max(finalResidual,abs(image[k]-rightHandSide[k]));finalScale=max(finalScale,abs(image[k]))
                }
                let finalBound=try tolerance.threshold(scale:finalScale)
                guard finalResidual.isFinite,finalResidual <= finalBound else { throw .residualRejected(value:finalResidual,threshold:finalBound) }
                try poll(isCancelled)
                return SpatialPressureSolution(pressure:x,work:work,originalResidual:finalResidual)
            }
            guard rr.isFinite,rr > 0 else { throw .nonConvergence(iterations:work.iterations,residual:original) }
            try work.advanceIteration()
            try apply(direction,into:&image,grid:grid,work:&work,isCancelled:isCancelled)
            let curvature=try dot(direction,image,work:&work,isCancelled:isCancelled)
            guard curvature > tolerance.pivotThreshold else { throw .nonPositiveDefinite(pivot:work.iterations-1) }
            try work.chargeOperations(1)
            let alpha=rr/curvature
            guard alpha.isFinite else { throw .nonFiniteResult }
            for k in 0..<n {
                try poll(isCancelled);try work.chargeOperations(4)
                x[k] += alpha*direction[k];residual[k] -= alpha*image[k]
                guard x[k].isFinite,residual[k].isFinite else { throw .nonFiniteResult }
            }
            try removeMean(&residual,work:&work,isCancelled:isCancelled)
            let next=try dot(residual,residual,work:&work,isCancelled:isCancelled)
            try work.chargeOperations(1)
            let beta=next/rr
            guard beta.isFinite else { throw .nonFiniteResult }
            for k in 0..<n {
                try poll(isCancelled);try work.chargeOperations(2)
                direction[k]=residual[k]+beta*direction[k]
                guard direction[k].isFinite else { throw .nonFiniteResult }
            }
            try removeMean(&direction,work:&work,isCancelled:isCancelled)
            rr=next
            // Recursive residual alone cannot certify the original singular equation.
            if next == 0,original > threshold {
                try apply(x,into:&image,grid:grid,work:&work,isCancelled:isCancelled)
                for k in 0..<n { try poll(isCancelled);try work.chargeOperations(1);residual[k]=rightHandSide[k]-image[k] }
                try removeMean(&residual,work:&work,isCancelled:isCancelled)
                for k in 0..<n { try poll(isCancelled);try work.chargeOperations(1);direction[k]=residual[k] }
                rr=try dot(residual,residual,work:&work,isCancelled:isCancelled)
            }
        }
    }
    private func apply(_ values:[Double],into output:inout [Double],grid:SpatialGrid,work:inout NumericalWork,
                       isCancelled:@Sendable ()->Bool) throws(NumericalError) {
        for k in 0..<grid.count {
            try poll(isCancelled);try work.chargeOperations(24)
            let value = -SpatialGeometry.laplacian(values,grid:grid,at:k)
            guard value.isFinite else { throw .nonFiniteResult };output[k]=value
        }
    }
    private func removeMean(_ values:inout [Double],work:inout NumericalWork,isCancelled:@Sendable ()->Bool) throws(NumericalError) {
        var sum=0.0
        for k in values.indices { try poll(isCancelled);try work.chargeOperations(1);sum += values[k];guard sum.isFinite else { throw .nonFiniteResult } }
        try work.chargeOperations(1);let mean=sum/Double(values.count)
        for k in values.indices { try poll(isCancelled);try work.chargeOperations(1);values[k] -= mean;guard values[k].isFinite else { throw .nonFiniteResult } }
    }
    private func dot(_ a:[Double],_ b:[Double],work:inout NumericalWork,isCancelled:@Sendable ()->Bool) throws(NumericalError)->Double {
        var result=0.0
        for k in a.indices { try poll(isCancelled);try work.chargeOperations(2);result += a[k]*b[k];guard result.isFinite else { throw .nonFiniteResult } }
        return result
    }
    private func poll(_ isCancelled:@Sendable ()->Bool) throws(NumericalError) {
        guard !Task.isCancelled,!isCancelled() else { throw .cancelled }
    }
}
