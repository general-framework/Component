//
//  Reducer.swift
//  
//
//  Created by Jacob Martin on 10/18/19.
//

public func combine<Value, Action>(
    _ reducers: Reducer<Value, Action>...
) -> Reducer<Value, Action> {
    return { value, action in
        let effects = reducers.map { $0(&value, action) }
        return {
            for effect in effects {
                effect()
            }
        }
    }
}

public func pullback<LocalValue, GlobalValue, LocalAction, GlobalAction>(
    _ reducer: @escaping Reducer<LocalValue, LocalAction>,
    value: WritableKeyPath<GlobalValue, LocalValue>,
    action: WritableKeyPath<GlobalAction, LocalAction?>
) -> Reducer<GlobalValue, GlobalAction> {
    return { globalValue, globalAction in
        guard let localAction = globalAction[keyPath: action] else { return {} }
        let effect = reducer(&globalValue[keyPath: value], localAction)
        return effect
    }
}

public func logging<Value, Action>(
    _ reducer: @escaping Reducer<Value, Action>
) -> Reducer<Value, Action> {
    return { value, action in
        let effect = reducer(&value, action)
        let newValue = value
        return {
            print("Action: \(action)")
            print("Value:")
            dump(newValue)
            print("---")
            effect()
        }
    }
}
