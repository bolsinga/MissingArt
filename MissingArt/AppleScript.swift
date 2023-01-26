//
//  AppleScript.swift
//  MissingArt
//
//  Created by Greg Bolsinga on 12/13/22.
//

import AppKit
import Carbon
import Foundation

private protocol AppleScriptDescriptable {
  func descriptor() throws -> NSAppleEventDescriptor
}

extension String: AppleScriptDescriptable {
  fileprivate func descriptor() throws -> NSAppleEventDescriptor {
    NSAppleEventDescriptor(string: self)
  }
}

extension Bool: AppleScriptDescriptable {
  fileprivate func descriptor() throws -> NSAppleEventDescriptor {
    NSAppleEventDescriptor(boolean: self)
  }
}

extension NSImage: AppleScriptDescriptable {
  fileprivate func descriptor() throws -> NSAppleEventDescriptor {
    // I changed the AppleScript to return a valid image data as the return value.
    // I then inspected it with the debugger to get the descriptorType. 'atdt' is 'tdta'
    // reversed which is what Script Editor will show for the class type for Image data.
    // Since Apple Script pre-dates the macos endian switch, my bet is it's backwards due to that.
    //    (lldb) p result.descriptorType
    //    (DescType) $R2 = 1952740449
    //    (lldb) p/c result.descriptorType
    //    (DescType) $R3 = atdt
    //    (lldb) p/x result.descriptorType
    //    (DescType) $R4 = 0x74647461
    let descriptor = NSAppleEventDescriptor(
      descriptorType: 0x7464_7461, data: self.tiffRepresentation)
    guard let descriptor = descriptor else {
      throw AppleScriptError.typeIsNotDescriptable(self.className)
    }
    return descriptor
  }
}

private enum AppleScriptError: Error {
  case cannotInitialize
  case cannotCompile(String)
  case unknownCompileError
  case cannotExecute(String)
  case unknownExecuteError
  case cannotExecuteAppleEvent(String)
  case unknownExecuteAppleEvent
  case typeIsNotDescriptable(String)
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

  fileprivate static func createExecuteAppleEventError(_ nsDictionary: NSDictionary)
    -> AppleScriptError
  {
    if let message = nsDictionary[NSAppleScript.errorMessage] as? String {
      return .cannotExecuteAppleEvent(message)
    }
    return .unknownExecuteAppleEvent
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
    case .cannotExecuteAppleEvent(let message):
      return "AppleScript Event Execution Error: \(message)"
    case .unknownExecuteAppleEvent:
      return "Unknown AppleScript Event Execution Error"
    case .typeIsNotDescriptable(let message):
      return "No Type Descriptor for type: \(message)"
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
    if let errorDictionary {
      throw AppleScriptError.createCompileError(errorDictionary)
    } else {
      script = exec
    }
  }

  public func run() throws -> Bool {
    var errorDictionary: NSDictionary?
    let result = script.executeAndReturnError(&errorDictionary)
    if let errorDictionary {
      throw AppleScriptError.createExecuteError(errorDictionary)
    }
    return result.booleanValue
  }

  private func run(handler: String, parameters: NSAppleEventDescriptor) throws -> Bool {
    // https://developer.apple.com/forums/thread/98830?answerId=301006022#301006022
    // See the above for the source of this code.
    let event = NSAppleEventDescriptor(
      eventClass: AEEventClass(kASAppleScriptSuite),
      eventID: AEEventID(kASSubroutineEvent),
      targetDescriptor: nil,
      returnID: AEReturnID(kAutoGenerateReturnID),
      transactionID: AETransactionID(kAnyTransactionID)
    )
    event.setDescriptor(
      NSAppleEventDescriptor(string: handler), forKeyword: AEKeyword(keyASSubroutineName))
    event.setDescriptor(parameters, forKeyword: AEKeyword(keyDirectObject))

    var errorDictionary: NSDictionary?
    let result = script.executeAppleEvent(event, error: &errorDictionary)
    if let errorDictionary {
      debugPrint("Apple Script Error : \(errorDictionary)")
      throw AppleScriptError.createExecuteAppleEventError(errorDictionary)
    }
    return result.booleanValue
  }

  func run(handler: String, parameters: Any...) throws -> Bool {
    let asParameters = NSAppleEventDescriptor.list()

    for parameter in parameters {
      guard let parameter = parameter as? AppleScriptDescriptable else {
        throw AppleScriptError.typeIsNotDescriptable("\(parameter.self)")
      }
      asParameters.insert(try parameter.descriptor(), at: 0)
    }

    return try run(handler: handler, parameters: asParameters)
  }
}
