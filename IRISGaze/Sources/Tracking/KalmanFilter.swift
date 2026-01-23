import Foundation
import simd

/// Kalman filter for predictive gaze smoothing
/// Reduces perceived lag by predicting future gaze position
struct KalmanFilter {
    // State vector: [x, y, vx, vy]
    private var state: SIMD4<Double>

    // State covariance matrix (4x4)
    private var P: [[Double]]

    // Process noise covariance
    private let Q: [[Double]]

    // Measurement noise covariance
    private let R: [[Double]]

    // Time delta (60 FPS = ~16.67ms)
    private let dt: Double = 1.0 / 60.0

    init() {
        // Initial state: position at screen center, zero velocity
        state = SIMD4<Double>(960, 540, 0, 0)

        // Initial covariance (high uncertainty)
        P = [
            [1000, 0, 0, 0],
            [0, 1000, 0, 0],
            [0, 0, 1000, 0],
            [0, 0, 0, 1000]
        ]

        // Process noise (how much we trust the model)
        // Velocity noise increased from 0.5 to 1.0 for faster response to velocity changes
        Q = [
            [0.1, 0, 0, 0],
            [0, 0.1, 0, 0],
            [0, 0, 1.0, 0],    // Increased for lower latency
            [0, 0, 0, 1.0]
        ]

        // Measurement noise (how much we trust the measurements)
        // Reduced from 5.0 to trust raw data more for lower latency
        R = [
            [2.0, 0],
            [0, 2.0]
        ]
    }

    /// Update filter with new measurement and return predicted position
    mutating func update(measurement: CGPoint) -> CGPoint {
        // PREDICT STEP

        // State transition matrix F (constant velocity model)
        let F = [
            [1.0, 0.0, dt, 0.0],
            [0.0, 1.0, 0.0, dt],
            [0.0, 0.0, 1.0, 0.0],
            [0.0, 0.0, 0.0, 1.0]
        ]

        // Predict state: x = F * x
        state = multiplyMatrixVector(F, state)

        // Predict covariance: P = F * P * F' + Q
        P = addMatrices(multiplyMatrices(multiplyMatrices(F, P), transpose(F)), Q)

        // UPDATE STEP

        // Measurement matrix H (we only measure position, not velocity)
        let H = [
            [1.0, 0.0, 0.0, 0.0],
            [0.0, 1.0, 0.0, 0.0]
        ]

        // Innovation (measurement residual): y = z - H * x
        let predicted = multiplyMatrixVector2x4(H, state)
        let innovation = SIMD2<Double>(
            measurement.x - predicted.x,
            measurement.y - predicted.y
        )

        // Innovation covariance: S = H * P * H' + R
        let HPHt = multiplyMatrices2x4x4x2(H, P, transpose2x4(H))
        let S = addMatrices2x2(HPHt, R)

        // Kalman gain: K = P * H' * inv(S)
        let Sinv = inverse2x2(S)
        let PHt = multiplyMatrices4x4x4x2(P, transpose2x4(H))
        let K = multiplyMatrices4x2x2x2(PHt, Sinv)

        // Update state: x = x + K * y
        let correction = multiplyMatrixVector4x2(K, innovation)
        state.x += correction.x
        state.y += correction.y
        state.z += correction.z
        state.w += correction.w

        // Update covariance: P = (I - K * H) * P
        let KH = multiplyMatrices4x2x2x4(K, H)
        let I = identityMatrix4x4()
        let IminusKH = subtractMatrices(I, KH)
        P = multiplyMatrices(IminusKH, P)

        // Return predicted position (includes velocity prediction)
        return CGPoint(x: state.x, y: state.y)
    }

    // MARK: - Matrix Operations

    private func multiplyMatrixVector(_ matrix: [[Double]], _ vector: SIMD4<Double>) -> SIMD4<Double> {
        return SIMD4<Double>(
            matrix[0][0] * vector.x + matrix[0][1] * vector.y + matrix[0][2] * vector.z + matrix[0][3] * vector.w,
            matrix[1][0] * vector.x + matrix[1][1] * vector.y + matrix[1][2] * vector.z + matrix[1][3] * vector.w,
            matrix[2][0] * vector.x + matrix[2][1] * vector.y + matrix[2][2] * vector.z + matrix[2][3] * vector.w,
            matrix[3][0] * vector.x + matrix[3][1] * vector.y + matrix[3][2] * vector.z + matrix[3][3] * vector.w
        )
    }

    private func multiplyMatrixVector2x4(_ matrix: [[Double]], _ vector: SIMD4<Double>) -> SIMD2<Double> {
        return SIMD2<Double>(
            matrix[0][0] * vector.x + matrix[0][1] * vector.y + matrix[0][2] * vector.z + matrix[0][3] * vector.w,
            matrix[1][0] * vector.x + matrix[1][1] * vector.y + matrix[1][2] * vector.z + matrix[1][3] * vector.w
        )
    }

    private func multiplyMatrixVector4x2(_ matrix: [[Double]], _ vector: SIMD2<Double>) -> SIMD4<Double> {
        return SIMD4<Double>(
            matrix[0][0] * vector.x + matrix[0][1] * vector.y,
            matrix[1][0] * vector.x + matrix[1][1] * vector.y,
            matrix[2][0] * vector.x + matrix[2][1] * vector.y,
            matrix[3][0] * vector.x + matrix[3][1] * vector.y
        )
    }

    private func multiplyMatrices(_ A: [[Double]], _ B: [[Double]]) -> [[Double]] {
        let rows = A.count
        let cols = B[0].count
        let inner = B.count

        var result = Array(repeating: Array(repeating: 0.0, count: cols), count: rows)

        for i in 0..<rows {
            for j in 0..<cols {
                var sum = 0.0
                for k in 0..<inner {
                    sum += A[i][k] * B[k][j]
                }
                result[i][j] = sum
            }
        }

        return result
    }

    private func multiplyMatrices2x4x4x2(_ H: [[Double]], _ P: [[Double]], _ Ht: [[Double]]) -> [[Double]] {
        // H (2x4) * P (4x4) * H' (4x2) = 2x2
        let HP = multiplyMatrices2x4x4x4(H, P)
        return multiplyMatrices2x4x4x2Final(HP, Ht)
    }

    private func multiplyMatrices2x4x4x4(_ H: [[Double]], _ P: [[Double]]) -> [[Double]] {
        var result = Array(repeating: Array(repeating: 0.0, count: 4), count: 2)
        for i in 0..<2 {
            for j in 0..<4 {
                var sum = 0.0
                for k in 0..<4 {
                    sum += H[i][k] * P[k][j]
                }
                result[i][j] = sum
            }
        }
        return result
    }

    private func multiplyMatrices2x4x4x2Final(_ HP: [[Double]], _ Ht: [[Double]]) -> [[Double]] {
        var result = Array(repeating: Array(repeating: 0.0, count: 2), count: 2)
        for i in 0..<2 {
            for j in 0..<2 {
                var sum = 0.0
                for k in 0..<4 {
                    sum += HP[i][k] * Ht[k][j]
                }
                result[i][j] = sum
            }
        }
        return result
    }

    private func multiplyMatrices4x4x4x2(_ P: [[Double]], _ Ht: [[Double]]) -> [[Double]] {
        var result = Array(repeating: Array(repeating: 0.0, count: 2), count: 4)
        for i in 0..<4 {
            for j in 0..<2 {
                var sum = 0.0
                for k in 0..<4 {
                    sum += P[i][k] * Ht[k][j]
                }
                result[i][j] = sum
            }
        }
        return result
    }

    private func multiplyMatrices4x2x2x2(_ PHt: [[Double]], _ Sinv: [[Double]]) -> [[Double]] {
        var result = Array(repeating: Array(repeating: 0.0, count: 2), count: 4)
        for i in 0..<4 {
            for j in 0..<2 {
                var sum = 0.0
                for k in 0..<2 {
                    sum += PHt[i][k] * Sinv[k][j]
                }
                result[i][j] = sum
            }
        }
        return result
    }

    private func multiplyMatrices4x2x2x4(_ K: [[Double]], _ H: [[Double]]) -> [[Double]] {
        var result = Array(repeating: Array(repeating: 0.0, count: 4), count: 4)
        for i in 0..<4 {
            for j in 0..<4 {
                var sum = 0.0
                for k in 0..<2 {
                    sum += K[i][k] * H[k][j]
                }
                result[i][j] = sum
            }
        }
        return result
    }

    private func addMatrices(_ A: [[Double]], _ B: [[Double]]) -> [[Double]] {
        var result = A
        for i in 0..<A.count {
            for j in 0..<A[0].count {
                result[i][j] += B[i][j]
            }
        }
        return result
    }

    private func addMatrices2x2(_ A: [[Double]], _ B: [[Double]]) -> [[Double]] {
        return [
            [A[0][0] + B[0][0], A[0][1] + B[0][1]],
            [A[1][0] + B[1][0], A[1][1] + B[1][1]]
        ]
    }

    private func subtractMatrices(_ A: [[Double]], _ B: [[Double]]) -> [[Double]] {
        var result = A
        for i in 0..<A.count {
            for j in 0..<A[0].count {
                result[i][j] -= B[i][j]
            }
        }
        return result
    }

    private func transpose(_ matrix: [[Double]]) -> [[Double]] {
        let rows = matrix.count
        let cols = matrix[0].count
        var result = Array(repeating: Array(repeating: 0.0, count: rows), count: cols)

        for i in 0..<rows {
            for j in 0..<cols {
                result[j][i] = matrix[i][j]
            }
        }

        return result
    }

    private func transpose2x4(_ matrix: [[Double]]) -> [[Double]] {
        return [
            [matrix[0][0], matrix[1][0]],
            [matrix[0][1], matrix[1][1]],
            [matrix[0][2], matrix[1][2]],
            [matrix[0][3], matrix[1][3]]
        ]
    }

    private func inverse2x2(_ matrix: [[Double]]) -> [[Double]] {
        let det = matrix[0][0] * matrix[1][1] - matrix[0][1] * matrix[1][0]
        let invDet = 1.0 / det

        return [
            [matrix[1][1] * invDet, -matrix[0][1] * invDet],
            [-matrix[1][0] * invDet, matrix[0][0] * invDet]
        ]
    }

    private func identityMatrix4x4() -> [[Double]] {
        return [
            [1, 0, 0, 0],
            [0, 1, 0, 0],
            [0, 0, 1, 0],
            [0, 0, 0, 1]
        ]
    }
}
