//
//  AppleScript.swift
//  MissingArt
//
//  Created by Greg Bolsinga on 12/13/22.
//

import Foundation

private enum AppleScriptError: Error {
  case cannotInitialize
  case cannotCompile(String)
  case unknownCompileError
  case cannotExecute(String)
  case unknownExecuteError
}

extension AppleScriptError {
  fileprivate static func createCompileError(_ nsDictionary: NSDictionary) -> AppleScriptError {
    if let message = nsDictionary[NSAppleScript.errorMessage] as? String {
      return .cannotCompile(message)
    }
    return .unknownCompileError
  }

  fileprivate static func createExecuteError(_ nsDictionary: NSDictionary) -> AppleScriptError {
    if let message = nsDictionary[NSAppleScript.errorMessage] as? String {
      return .cannotExecute(message)
    }
    return .unknownExecuteError
  }
}

extension AppleScriptError: LocalizedError {
  var errorDescription: String? {
    switch self {
    case .cannotInitialize:
      return "AppleScript Initialization Error"
    case .cannotCompile(let message):
      return "AppleScript Compilation Error: \(message)"
    case .unknownCompileError:
      return "Unknown AppleScript Compilation Error"
    case .cannotExecute(let message):
      return "AppleScript Execution Error: \(message)"
    case .unknownExecuteError:
      return "Unknown AppleScript Execution Error"
    }
  }
}

public actor AppleScript {
  private var script: NSAppleScript

  public init(source: String) throws {
    let exec = NSAppleScript(source: source)
    guard let exec = exec else { throw AppleScriptError.cannotInitialize }

    var errorDictionary: NSDictionary?
    _ = exec.compileAndReturnError(&errorDictionary)
    if let errorDictionary = errorDictionary {
      throw AppleScriptError.createCompileError(errorDictionary)
    } else {
      script = exec
    }
  }

  public func run() throws {
    var errorDictionary: NSDictionary?
    _ = script.executeAndReturnError(&errorDictionary)
    if let errorDictionary = errorDictionary {
      throw AppleScriptError.createExecuteError(errorDictionary)
    }
  }
}
