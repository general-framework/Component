//
//  Alias.swift
//  
//
//  Created by Jacob Martin on 10/18/19.
//

public typealias Effect = () -> Void

public typealias Reducer<Value, Action> = (inout Value, Action) -> Effect
