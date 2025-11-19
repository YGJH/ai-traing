
//
//  parameter1d.swift
//  ai-traing
//
//  Created by user20 on 2025/11/19.
//

final class Parameter1D {
    typealias Vector = [Float]

    private let getter: () -> Vector
    private let setter: (Vector) -> Void

    /// 對應的 gradient（你在 backward 的時候要自己填）
    var grad: Vector

    /// 權重值：讀取時從 model 拿，寫入時回寫到 model
    var data: Vector {
        get { getter() }
        set {
            precondition(newValue.count == grad.count, "Shape mismatch in Parameter1D.data set")
            setter(newValue)
        }
    }

    init(getter: @escaping () -> Vector,
         setter: @escaping (Vector) -> Void)
    {
        self.getter = getter
        self.setter = setter
        let initial = getter()
        self.grad = Array(repeating: 0, count: initial.count)
    }

    func zeroGrad() {
        grad = Array(repeating: 0, count: grad.count)
    }
}
