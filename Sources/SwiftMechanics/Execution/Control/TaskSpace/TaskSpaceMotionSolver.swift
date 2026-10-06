internal struct TaskSpaceMotionSolver: Sendable {
    let physical: TaskSpacePhysicalInvocation
    let linear: TaskSpaceLinearInvocation
    @inline(never)
    func solve(_ task: TaskSpaceMotion, system: PhysicalRigidDynamicsSystem, policy: TaskSpacePolicy,
               reserved: Int, work: inout NumericalWork) throws(TaskSpaceFailure) -> TaskSpaceMotionSolution {
        let n = system.velocityCount, m = task.axes.count
        try TaskSpaceArithmetic.charge(try TaskSpaceArithmetic.sum(try TaskSpaceArithmetic.product(2,n),24),&work)
        guard m > 0, m <= 3, task.weights.count == m, task.accelerationMetersPerSecondSquared.count == m,
              task.weights.allSatisfy({$0.isFinite && $0 > 0}), task.accelerationMetersPerSecondSquared.allSatisfy({$0.isFinite}) else {
            throw TaskSpaceFailure(.invalidShape)
        }
        if let secondary = task.secondaryGeneralizedAcceleration {
            guard secondary.count == n, secondary.allSatisfy({$0.isFinite}) else { throw TaskSpaceFailure(.invalidShape) }
        }
        for i in task.axes.indices {
            for j in 0..<i { guard task.axes[j] != task.axes[i] else { throw TaskSpaceFailure(.invalidInput) } }
        }
        // FIXME(INCOMPLETE_IMPLEMENTATION): This point-motion path does not implement out-of-plane
        // planar tasks. Such requests fail until original plane-support and task evidence exists.
        if system.input.dimension == .planar, task.axes.contains(.z) { throw TaskSpaceFailure(.unsupportedDomain) }
        try TaskSpaceArithmetic.charge(try TaskSpaceArithmetic.product(96,n),&work)
        let calculator = KinematicJacobianCalculator(), jacobian: PointJacobian, motion: PointKinematics
        do {
            jacobian = try calculator.point(body:task.body,bodyLocalPoint:task.bodyLocalPoint,snapshot:system.input.snapshot)
            motion = try calculator.pointMotion(body:task.body,bodyLocalPoint:task.bodyLocalPoint,snapshot:system.input.snapshot)
        } catch let error as JointError { throw TaskSpaceFailure(.joints(error)) }
        catch let error as CoreError { throw TaskSpaceFailure(.core(error)) }
        catch { throw TaskSpaceFailure(.invalidSupplierOutput) }
        guard jacobian.columns.count == n, jacobian.referenceFrame == system.input.snapshot.tree.worldFrame,
              motion.referenceFrame == jacobian.referenceFrame, motion.body == task.body else { throw TaskSpaceFailure(.invalidSupplierOutput) }
        let entries = try TaskSpaceArithmetic.product(m,n)
        var rows = [Double](repeating:0,count:entries), normalized = rows, inverseColumns = rows
        var roots = [Double](repeating:0,count:m), rhs = roots
        try TaskSpaceArithmetic.charge(5,&work)
        let timeSquared = try TaskSpaceArithmetic.finite(policy.dynamics.timeScale*policy.dynamics.timeScale)
        let accelerationScale = try TaskSpaceArithmetic.finite(policy.lengthScaleMeters/timeSquared)
        let forceScale = try TaskSpaceArithmetic.finite(policy.dynamics.energyScale/policy.lengthScaleMeters)
        let gramScale = try TaskSpaceArithmetic.finite(forceScale/accelerationScale)
        guard accelerationScale > 0, forceScale > 0, gramScale > 0 else { throw TaskSpaceFailure(.invalidInput) }
        for row in 0..<m {
            try TaskSpaceArithmetic.check(system,policy); try TaskSpaceArithmetic.charge(6,&work)
            roots[row] = task.weights[row].squareRoot()
            rhs[row] = try TaskSpaceArithmetic.finite(roots[row]*(task.accelerationMetersPerSecondSquared[row]-task.axes[row].component(motion.accelerationBias))/accelerationScale)
            var column = [Double](repeating:0,count:n)
            for i in 0..<n {
                try TaskSpaceArithmetic.charge(4,&work)
                rows[row*n+i] = try TaskSpaceArithmetic.finite(roots[row]*task.axes[row].component(jacobian.columns[i]))
                column[i] = rows[row*n+i]
                normalized[row*n+i] = try TaskSpaceArithmetic.finite(rows[row*n+i]*policy.dynamics.coordinateScales[i]/policy.lengthScaleMeters)
            }
            let massProduct = try physical.call(.inverseMass,system:system,values:column,policy:policy,reserved:reserved,work:&work)
            for i in 0..<n { inverseColumns[row*n+i] = massProduct.acceleration[i] }
        }
        let rank = try TaskSpaceArithmetic.rank(normalized,count:m,width:n,relative:policy.rankRelativeTolerance,system:system,policy:policy,work:&work)
        let damping: Double
        switch policy.singularity {
        case .requireFullRowRank:
            guard rank == m else { throw TaskSpaceFailure(.singularTask(rank:rank,rows:m)) }; damping = 0
        case .damped(let lambda): damping = lambda
        }
        var gram = [Double](repeating:0,count:try TaskSpaceArithmetic.product(m,m))
        for row in 0..<m {
            try TaskSpaceArithmetic.check(system,policy)
            for column in row..<m {
                var value = 0.0
                for i in 0..<n { try TaskSpaceArithmetic.charge(2,&work); value = try TaskSpaceArithmetic.finite(value+rows[row*n+i]*inverseColumns[column*n+i]) }
                try TaskSpaceArithmetic.charge(1,&work); value = try TaskSpaceArithmetic.finite(value*gramScale)
                var reverse = 0.0
                for i in 0..<n { try TaskSpaceArithmetic.charge(2,&work); reverse = try TaskSpaceArithmetic.finite(reverse+rows[column*n+i]*inverseColumns[row*n+i]) }
                try TaskSpaceArithmetic.charge(2,&work); reverse = try TaskSpaceArithmetic.finite(reverse*gramScale)
                let symmetryThreshold: Double
                do { symmetryThreshold = try policy.taskLinearTolerance.threshold(scale:max(abs(value),abs(reverse))) }
                catch { throw TaskSpaceFailure(.numerical(error)) }
                guard abs(try TaskSpaceArithmetic.finite(value-reverse)) <= symmetryThreshold else { throw TaskSpaceFailure(.invalidSupplierOutput) }
                // The verified physical inverse makes both original entries agree within the
                // caller gate; the upper entry selects the exact symmetric Cholesky storage.
                gram[row*m+column] = value; gram[column*m+row] = value
            }
            try TaskSpaceArithmetic.charge(2,&work); gram[row*m+row] = try TaskSpaceArithmetic.finite(gram[row*m+row]+damping*damping)
        }
        let primaryDual = try linear.solve(gram,rhs:rhs,system:system,policy:policy,reserved:reserved,work:&work)
        var primary = [Double](repeating:0,count:n), secondary = primary
        var secondaryDefect = [Double](repeating:0,count:m)
        for i in 0..<n {
            for row in 0..<m { try TaskSpaceArithmetic.charge(3,&work); primary[i] = try TaskSpaceArithmetic.finite(primary[i]+inverseColumns[row*n+i]*primaryDual[row]*forceScale) }
        }
        if let feedforward = task.secondaryGeneralizedAcceleration {
            var secondaryRHS = [Double](repeating:0,count:m)
            for row in 0..<m {
                for i in 0..<n { try TaskSpaceArithmetic.charge(2,&work); secondaryRHS[row] = try TaskSpaceArithmetic.finite(secondaryRHS[row]+rows[row*n+i]*feedforward[i]) }
                try TaskSpaceArithmetic.charge(1,&work); secondaryRHS[row] = try TaskSpaceArithmetic.finite(secondaryRHS[row]/accelerationScale)
            }
            let secondaryDual = try linear.solve(gram,rhs:secondaryRHS,system:system,policy:policy,reserved:reserved,work:&work)
            for row in 0..<m {
                try TaskSpaceArithmetic.charge(4,&work)
                secondaryDefect[row] = try TaskSpaceArithmetic.finite(damping*damping*secondaryDual[row]*accelerationScale/roots[row])
            }
            secondary = feedforward
            for i in 0..<n {
                for row in 0..<m { try TaskSpaceArithmetic.charge(3,&work); secondary[i] = try TaskSpaceArithmetic.finite(secondary[i]-inverseColumns[row*n+i]*secondaryDual[row]*forceScale) }
            }
        }
        var total = primary, force = [Double](repeating:0,count:3), defect = [Double](repeating:0,count:m)
        for i in 0..<n { try TaskSpaceArithmetic.charge(1,&work); total[i] = try TaskSpaceArithmetic.finite(primary[i]+secondary[i]) }
        for row in 0..<m {
            try TaskSpaceArithmetic.charge(7,&work)
            force[task.axes[row].rawValue] = try TaskSpaceArithmetic.finite(roots[row]*primaryDual[row]*forceScale)
            defect[row] = try TaskSpaceArithmetic.finite(damping*damping*primaryDual[row]*accelerationScale/roots[row])
        }
        let pointForce = try TaskSpaceArithmetic.core { () throws(CoreError) in try Vector3(force[0],force[1],force[2]) }
        return TaskSpaceMotionSolution(jacobian:jacobian,pointMotion:motion,primary:primary,secondary:secondary,total:total,
            rank:rank,damping:damping,pointForce:pointForce,regularizationDefect:defect,secondaryRegularizationDefect:secondaryDefect)
    }
}
