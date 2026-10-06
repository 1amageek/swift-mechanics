/// One call exclusively owns this mutable tableau and its original-row transform.
internal struct LinearSimplexTableau {
    let rowCount: Int
    let variableCount: Int
    let artificialStart: Int
    let columnCount: Int
    let stride: Int
    let rowSigns: [Double]
    var entries: [Double]
    var transform: [Double]
    var basis: [Int]
    var active: [Bool]
    var costs: [Double]
    var pivots: Int = 0

    init(rows: LinearOriginalRows, policy: LinearProgramPolicy, work: inout NumericalWork) throws(LinearProgramCause) {
        let m = rows.count, n = rows.variableCount
        rowCount = m; variableCount = n
        artificialStart = try LinearProgramArithmetic.sum(try LinearProgramArithmetic.product(2, n), m-rows.equalityCount)
        columnCount = try LinearProgramArithmetic.sum(artificialStart, m)
        stride = try LinearProgramArithmetic.sum(columnCount, 1)
        let tableEntries = try LinearProgramArithmetic.product(m, stride)
        let transformEntries = try LinearProgramArithmetic.product(m, m)
        let initialization = try LinearProgramArithmetic.sum(try LinearProgramArithmetic.sum(tableEntries, transformEntries),
            try LinearProgramArithmetic.sum(try LinearProgramArithmetic.product(4, m), columnCount))
        try LinearProgramArithmetic.charge(initialization, policy: policy, work: &work)
        var signs = [Double](repeating: 1, count: m)
        for r in 0..<m {
            try LinearProgramArithmetic.checkpoint(policy)
            signs[r] = rows.rightHandSide[r] < 0 ? -1 : 1
        }
        rowSigns = signs
        entries = [Double](repeating: 0, count: tableEntries)
        transform = [Double](repeating: 0, count: transformEntries)
        basis = [Int](repeating: 0, count: m); active = [Bool](repeating: true, count: m)
        costs = [Double](repeating: 0, count: columnCount)
        for r in 0..<m {
            try LinearProgramArithmetic.charge(try LinearProgramArithmetic.sum(try LinearProgramArithmetic.product(2, n), 5), policy: policy, work: &work)
            let sign = rowSigns[r]
            for j in 0..<n {
                let coefficient = sign * rows.coefficients[r*n+j]
                entries[r*stride+j] = coefficient; entries[r*stride+n+j] = -coefficient
            }
            if r >= rows.equalityCount { entries[r*stride+2*n+r-rows.equalityCount] = sign }
            basis[r] = artificialStart+r; entries[r*stride+basis[r]] = 1
            entries[r*stride+columnCount] = abs(rows.rightHandSide[r]); transform[r*m+r] = 1
            costs[artificialStart+r] = 1
        }
    }

    mutating func pivot(row: Int, column: Int, policy: LinearProgramPolicy, work: inout NumericalWork) throws(LinearProgramCause) {
        try LinearProgramArithmetic.checkpoint(policy)
        guard pivots < policy.maximumPivots else { throw .pivotLimit }
        let value = entries[row*stride+column]
        guard abs(value) > policy.pivotThreshold else { throw .numericalAmbiguity }
        do { try work.advanceIteration() } catch { throw .numerical(error) }
        pivots += 1
        try LinearProgramArithmetic.charge(try LinearProgramArithmetic.sum(stride, rowCount), policy: policy, work: &work)
        for j in 0..<stride { entries[row*stride+j] = try LinearProgramArithmetic.finite(entries[row*stride+j] / value) }
        for k in 0..<rowCount { transform[row*rowCount+k] = try LinearProgramArithmetic.finite(transform[row*rowCount+k] / value) }
        entries[row*stride+column] = 1
        for r in 0..<rowCount where active[r] && r != row {
            try LinearProgramArithmetic.charge(try LinearProgramArithmetic.product(2, try LinearProgramArithmetic.sum(stride, rowCount)), policy: policy, work: &work)
            let factor = entries[r*stride+column]
            for j in 0..<stride {
                entries[r*stride+j] = try LinearProgramArithmetic.finite(entries[r*stride+j] - factor*entries[row*stride+j])
            }
            for k in 0..<rowCount {
                transform[r*rowCount+k] = try LinearProgramArithmetic.finite(transform[r*rowCount+k] - factor*transform[row*rowCount+k])
            }
            // The selected column has an exact canonical identity after elimination.
            entries[r*stride+column] = 0
            guard entries[r*stride+columnCount] >= 0 else { throw .numericalAmbiguity }
        }
        guard entries[row*stride+columnCount] >= 0 else { throw .numericalAmbiguity }
        basis[row] = column
    }

    mutating func entering(limit: Int, policy: LinearProgramPolicy, work: inout NumericalWork) throws(LinearProgramCause) -> Int? {
        for j in 0..<limit {
            try LinearProgramArithmetic.charge(try LinearProgramArithmetic.sum(try LinearProgramArithmetic.product(4, rowCount), 3), policy: policy, work: &work)
            var value = costs[j], scale = abs(costs[j]), isBasic = false
            for r in 0..<rowCount where active[r] {
                if basis[r] == j { isBasic = true }
                let product = try LinearProgramArithmetic.finite(costs[basis[r]]*entries[r*stride+j])
                value = try LinearProgramArithmetic.finite(value-product); scale = try LinearProgramArithmetic.finite(scale+abs(product))
            }
            if !isBasic, value < -(try LinearProgramArithmetic.threshold(policy.reducedCostTolerance, scale: scale)) { return j }
        }
        return nil
    }

    func leaving(column: Int, policy: LinearProgramPolicy, work: inout NumericalWork) throws(LinearProgramCause) -> Int? {
        var selected: Int?, best: Double = 0
        var tinyPositive = false
        for r in 0..<rowCount where active[r] {
            try LinearProgramArithmetic.charge(5, policy: policy, work: &work)
            let rhs = entries[r*stride+columnCount], coefficient = entries[r*stride+column]
            guard rhs >= 0 else { throw .numericalAmbiguity }
            if coefficient > 0, coefficient <= policy.pivotThreshold { tinyPositive = true; continue }
            if coefficient > policy.pivotThreshold {
                let ratio = try LinearProgramArithmetic.finite(rhs/coefficient)
                if let previous = selected {
                    if ratio < best || (ratio == best && basis[r] < basis[previous]) { selected = r; best = ratio }
                } else { selected = r; best = ratio }
            }
        }
        // An ignored positive coefficient can hide a finite boundary at any ratio.
        guard !tinyPositive else { throw .numericalAmbiguity }
        return selected
    }

    mutating func optimize(limit: Int, policy: LinearProgramPolicy, work: inout NumericalWork) throws(LinearProgramCause) -> Int? {
        while let column = try entering(limit: limit, policy: policy, work: &work) {
            guard let row = try leaving(column: column, policy: policy, work: &work) else { return column }
            try pivot(row: row, column: column, policy: policy, work: &work)
        }
        return nil
    }

    func objective(policy: LinearProgramPolicy, work: inout NumericalWork) throws(LinearProgramCause) -> Double {
        var value: Double = 0
        for r in 0..<rowCount where active[r] {
            try LinearProgramArithmetic.charge(2, policy: policy, work: &work)
            value = try LinearProgramArithmetic.finite(value+costs[basis[r]]*entries[r*stride+columnCount])
        }
        return value
    }

    mutating func removeArtificials(policy: LinearProgramPolicy, work: inout NumericalWork) throws(LinearProgramCause) {
        for r in 0..<rowCount where active[r] && basis[r] >= artificialStart {
            try LinearProgramArithmetic.checkpoint(policy)
            // A nonzero artificial remnant never becomes an original feasible point.
            guard entries[r*stride+columnCount] == 0 else { throw .numericalAmbiguity }
            var column: Int?
            for j in 0..<artificialStart {
                try LinearProgramArithmetic.charge(2, policy: policy, work: &work)
                let coefficient = entries[r*stride+j]
                if coefficient != 0 {
                    guard abs(coefficient) > policy.pivotThreshold else { throw .numericalAmbiguity }
                    column = j; break
                }
            }
            if let column { try pivot(row: r, column: column, policy: policy, work: &work) }
            else { active[r] = false }
        }
    }

    mutating func installCost(_ cost: [Double], policy: LinearProgramPolicy, work: inout NumericalWork) throws(LinearProgramCause) {
        try LinearProgramArithmetic.charge(try LinearProgramArithmetic.sum(columnCount, try LinearProgramArithmetic.product(2, variableCount)), policy: policy, work: &work)
        for j in 0..<columnCount { costs[j] = 0 }
        for j in 0..<variableCount { costs[j] = cost[j]; costs[variableCount+j] = -cost[j] }
    }

    func originalPoint(policy: LinearProgramPolicy, work: inout NumericalWork) throws(LinearProgramCause) -> [Double] {
        try LinearProgramArithmetic.charge(variableCount, policy: policy, work: &work)
        var point = [Double](repeating: 0, count: variableCount)
        for r in 0..<rowCount where active[r] {
            try LinearProgramArithmetic.charge(3, policy: policy, work: &work)
            let j = basis[r], value = entries[r*stride+columnCount]
            guard value >= 0, j < artificialStart else { throw .numericalAmbiguity }
            if j < variableCount { point[j] = try LinearProgramArithmetic.finite(point[j]+value) }
            else if j < 2*variableCount { point[j-variableCount] = try LinearProgramArithmetic.finite(point[j-variableCount]-value) }
        }
        return point
    }

    func originalMultipliers(policy: LinearProgramPolicy, work: inout NumericalWork) throws(LinearProgramCause) -> [Double] {
        try LinearProgramArithmetic.charge(rowCount, policy: policy, work: &work)
        var multipliers = [Double](repeating: 0, count: rowCount)
        for k in 0..<rowCount {
            try LinearProgramArithmetic.charge(try LinearProgramArithmetic.product(2, rowCount), policy: policy, work: &work)
            var value: Double = 0
            for r in 0..<rowCount where active[r] {
                value = try LinearProgramArithmetic.finite(value+costs[basis[r]]*transform[r*rowCount+k])
            }
            multipliers[k] = try LinearProgramArithmetic.finite(-rowSigns[k]*value)
        }
        return multipliers
    }

    func originalRay(entering: Int, policy: LinearProgramPolicy, work: inout NumericalWork) throws(LinearProgramCause) -> [Double] {
        try LinearProgramArithmetic.charge(variableCount, policy: policy, work: &work)
        var direction = [Double](repeating: 0, count: variableCount)
        if entering < variableCount { direction[entering] = 1 }
        else if entering < 2*variableCount { direction[entering-variableCount] = -1 }
        for r in 0..<rowCount where active[r] {
            try LinearProgramArithmetic.charge(3, policy: policy, work: &work)
            let j = basis[r], value = -entries[r*stride+entering]
            guard value >= 0, j < artificialStart else { throw .numericalAmbiguity }
            if j < variableCount { direction[j] = try LinearProgramArithmetic.finite(direction[j]+value) }
            else if j < 2*variableCount { direction[j-variableCount] = try LinearProgramArithmetic.finite(direction[j-variableCount]-value) }
        }
        return direction
    }
}
