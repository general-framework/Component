import CasePaths`

//(inout RandomNumberGenerator) -> A
struct Gen<A> {
  let run: (inout RandomNumberGenerator) -> A
}

//(inout Substring) -> A?
struct Parser<A> {
  let run: (inout Substring) -> A?
}

//(@escaping (A) -> Void) -> Void
//struct Effect<A> {
//  let run: (@escaping (A) -> Void) -> Void
//}

//public typealias Reducer<Value, Action, Environment> = (inout Value, Action, Environment) -> [Effect<Action>]
public struct Reducer<Value, Action, Environment> {
  let reducer: (inout Value, Action, Environment) -> [Effect<Action>]
  
  public init(_ reducer: @escaping (inout Value, Action, Environment) -> [Effect<Action>]) {
    self.reducer = reducer
  }
}

extension Reducer {
  public func callAsFunction(_ value: inout Value, _ action: Action, _ environment: Environment) -> [Effect<Action>] {
    self.reducer(&value, action, environment)
  }
}

extension Reducer {
  public static func combine(_ reducers: Reducer...) -> Reducer {
    .init { value, action, environment in
      let effects = reducers.flatMap { $0(&value, action, environment) }
      return effects
    }
  }
}

//public func combine<Value, Action, Environment>(
//  _ reducers: Reducer<Value, Action, Environment>...
//) -> Reducer<Value, Action, Environment> {
//  .init { value, action, environment in
//    let effects = reducers.flatMap { $0(&value, action, environment) }
//    return effects
//  }
//}

extension Reducer {
  public func pullback<GlobalValue, GlobalAction, GlobalEnvironment>(
    value: WritableKeyPath<GlobalValue, Value>,
    action: CasePath<GlobalAction, Action>,
    environment: @escaping (GlobalEnvironment) -> Environment
  ) -> Reducer<GlobalValue, GlobalAction, GlobalEnvironment> {
    .init { globalValue, globalAction, globalEnvironment in
      guard let localAction = action.extract(from: globalAction) else { return [] }
      let localEffects = self(&globalValue[keyPath: value], localAction, environment(globalEnvironment))

      return localEffects.map { localEffect in
        localEffect.map(action.embed)
          .eraseToEffect()
      }
    }
  }
}

//public func pullback<LocalValue, GlobalValue, LocalAction, GlobalAction, LocalEnvironment, GlobalEnvironment>(
//  _ reducer: Reducer<LocalValue, LocalAction, LocalEnvironment>,
//  value: WritableKeyPath<GlobalValue, LocalValue>,
//  action: CasePath<GlobalAction, LocalAction>,
//  environment: @escaping (GlobalEnvironment) -> LocalEnvironment
//) -> Reducer<GlobalValue, GlobalAction, GlobalEnvironment> {
//  return .init { globalValue, globalAction, globalEnvironment in
//    guard let localAction = action.extract(from: globalAction) else { return [] }
//    let localEffects = reducer(&globalValue[keyPath: value], localAction, environment(globalEnvironment))
//
//    return localEffects.map { localEffect in
//      localEffect.map(action.embed)
//        .eraseToEffect()
//    }
//  }
//}

extension Reducer {
  public func logging(
    printer: @escaping (Environment) -> (String) -> Void = { _ in { print($0) } }
  ) -> Reducer {
    .init { value, action, environment in
      let effects = self(&value, action, environment)
      let newValue = value
      let print = printer(environment)
      return [.fireAndForget {
        print("Action: \(action)")
        print("Value:")
        var dumpedNewValue = ""
        dump(newValue, to: &dumpedNewValue)
        print(dumpedNewValue)
        print("---")
        }] + effects
    }
  }
}

//public func logging<Value, Action, Environment>(
//  _ reducer: Reducer<Value, Action, Environment>
//) -> Reducer<Value, Action, Environment> {
//  return .init { value, action, environment in
//    let effects = reducer(&value, action, environment)
//    let newValue = value
//    return [.fireAndForget {
//      print("Action: \(action)")
//      print("Value:")
//      dump(newValue)
//      print("---")
//      }] + effects
//  }
//}
