// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

//
//  helpers.swift
//  Packages
//
//  Created by Guigui on 10/5/25.
//
import Foundation

func runOnMainThread(_ work: @MainActor @Sendable @escaping () -> Void) {
  if Thread.isMainThread {
    MainActor.assumeIsolated {
      work()
    }
  } else {
    DispatchQueue.main.async {
      work()
    }
  }
}
