import Foundation
import math_h


/*
 func trainValue(trajectories: [Trajectory],
                 valueEpochs: Int = 2)
 {
     // 用 Adam 做 regression: minimize (V(s) - R)^2
     for _ in 0..<valueEpochs {
         optimizer.zeroGrad()

         var totalLoss: Float = 0
         for traj in trajectories {
             let s = traj.obs
             let target = traj.ret

             let (_, v) = model.forward(x: s)

             let diff = v - target
             let loss = 0.5 * diff * diff
             totalLoss += loss

             // TODO: 手刻 value head 的反向傳播，把 ∂loss/∂params
             // 寫進 Parameter1D.grad
         }

         // 用 Adam.step() 更新（這裡同時也會動到 policy 的參數，因為你 shared trunk；
         // 如果要完全分開 policy / value 的參數，可以改架構）
         optimizer.step()
     }
 }

 */


final class Adam {
    var params: [Parameter1D]

    let lr: Double
    let beta1: Float
    let beta2: Float
    let eps: Float

    // 一個 param 對應一個 m / v 向量
    var m: [[Float]]
    var v: [[Float]]

    var t: Int = 0   // time step

    init(
        params: [Parameter1D],
        lr: Double,
        beta1: Float = 0.9,
        beta2: Float = 0.999,
        eps: Float = 1e-6
    ) {
        self.params = params
        self.lr = lr
        self.beta1 = beta1
        self.beta2 = beta2
        self.eps = eps

        self.m = params.map { p in
            Array(repeating: 0, count: p.data.count)
        }
        self.v = params.map { p in
            Array(repeating: 0, count: p.data.count)
        }
    }

    func zeroGrad() {
        for p in params {
            p.zeroGrad()
        }
    }
    
    func step() {
        t += 1
        let tFloat = Float(t)

        let biasCorr1 = 1 - pow(beta1, tFloat)
        let biasCorr2 = 1 - pow(beta2, tFloat)

        for i in 0..<params.count {
            let p = params[i]
            var m_i = m[i]
            var v_i = v[i]

            var data = p.data
            let grad = p.grad

            precondition(data.count == grad.count)

            for j in 0..<data.count {
                let g = grad[j]

                // m_t, v_t
                m_i[j] = beta1 * m_i[j] + (1 - beta1) * g
                v_i[j] = beta2 * v_i[j] + (1 - beta2) * g * g

                // bias-correct
                let mHat = m_i[j] / biasCorr1
                let vHat = v_i[j] / biasCorr2

                // update
                data[j] -= Float(lr * Double(mHat) / Double((sqrt(vHat) + eps)))
            }

            // 寫回到底層 MLP（透過 setter closure）
            p.data = data
            m[i] = m_i
            v[i] = v_i
        }
    }
}
