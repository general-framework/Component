import Combine

public final class Store<Value, Action> {
  private let reducer: Reducer<Value, Action, Any>
  private let environment: Any
  @Published private var value: Value
  private var viewCancellable: Cancellable?
  private var effectCancellables: Set<AnyCancellable> = []

  public init<Environment>(
    initialValue: Value,
    reducer: Reducer<Value, Action, Environment>,
    environment: Environment
  ) {
    self.reducer = .init { value, action, environment in
      reducer(&value, action, environment as! Environment)
    }
    self.value = initialValue
    self.environment = environment
  }

  private func send(_ action: Action) {
    let effects = self.reducer(&self.value, action, self.environment)
    effects.forEach { effect in
      var effectCancellable: AnyCancellable?
      var didComplete = false
      effectCancellable = effect.sink(
        receiveCompletion: { [weak self, weak effectCancellable] _ in
          didComplete = true
          guard let effectCancellable = effectCancellable else { return }
          self?.effectCancellables.remove(effectCancellable)
      },
        receiveValue: { [weak self] in self?.send($0) }
      )
      if !didComplete, let effectCancellable = effectCancellable {
        self.effectCancellables.insert(effectCancellable)
      }
    }
  }

  public func scope<LocalValue, LocalAction>(
    value toLocalValue: @escaping (Value) -> LocalValue,
    action toGlobalAction: @escaping (LocalAction) -> Action
  ) -> Store<LocalValue, LocalAction> {
    let localStore = Store<LocalValue, LocalAction>(
      initialValue: toLocalValue(self.value),
      reducer: .init { localValue, localAction, _ in
        self.send(toGlobalAction(localAction))
        localValue = toLocalValue(self.value)
        return []
    },
      environment: self.environment
    )
    localStore.viewCancellable = self.$value
      .map(toLocalValue)
      .sink { [weak localStore] newValue in
        localStore?.value = newValue
      }
    return localStore
  }
}

@dynamicMemberLookup
public final class ViewStore<Value, Action>: ObservableObject {
  @Published public fileprivate(set) var value: Value
  fileprivate var cancellable: Cancellable?
  public let send: (Action) -> Void
  
  public subscript<LocalValue>(dynamicMember keyPath: KeyPath<Value, LocalValue>) -> LocalValue {
    self.value[keyPath: keyPath]
  }

  public init(
    initialValue value: Value,
    send: @escaping (Action) -> Void
  ) {
    self.value = value
    self.send = send
  }
}

extension Store where Value: Equatable {
  public var view: ViewStore<Value, Action> {
    self.view(removeDuplicates: ==)
  }
}

extension Store {
  public func view(
    removeDuplicates predicate: @escaping (Value, Value) -> Bool
  ) -> ViewStore<Value, Action> {
    let viewStore = ViewStore(
      initialValue: self.value,
      send: self.send
    )

    viewStore.cancellable = self.$value
      .removeDuplicates(by: predicate)
      .sink(receiveValue: { [weak viewStore] value in
        viewStore?.value = value
      })

    return viewStore
  }
}
