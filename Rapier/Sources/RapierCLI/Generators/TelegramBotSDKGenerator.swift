import Foundation
import Rapier

private struct Context {
    let directory: String
    
    var outTypes: String = ""
    var outMethods: String = ""
    
    init(directory: String) {
        self.directory = directory
    }
}

class TelegramBotSDKGenerator: CodeGenerator {
    required init(directory: String) {
        self.context = Context(directory: directory)
    }
    
    func start() throws {
        
    }
    
    func beforeGeneratingTypes() throws {
        let header = """
        // This file is automatically generated by Rapier
        
        import Foundation

        
        """
        context.outTypes.append(header)
    }
    
    func generateType(name: String, info: TypeInfo) throws {
        context.outTypes.append("""
            public struct \(name): JsonConvertible, InternalJsonConvertible {
                /// Original JSON for fields not yet added to Swift structures.
                public var json: Any {
                    get { return internalJson.object }
                    set { internalJson = JSON(newValue) }
                }
                internal var internalJson: JSON
            
            """)
        var allInitParams: [String] = []
        info.fields.sorted { $0.key < $1.key }.forEach { fieldName, fieldInfo in
            let getterName = makeGetterName(typeName: name, fieldName: fieldName, fieldType: fieldInfo.type)
            if fieldInfo.type == "True" {
                allInitParams.append(#""\#(fieldName)" = true"#)
            } else {
                if let field = buildFieldTemplate(fieldName: getterName, fieldInfo: fieldInfo) {
                    context.outTypes.append(field)
                }
            }
            
        }
        var initParamsString = allInitParams.joined(separator: ", ")
        if initParamsString.isEmpty {
            initParamsString = "[:]"
        }
        context.outTypes.append("""
            internal init(internalJson: JSON = \(initParamsString)) {
                self.internalJson = internalJson
            }
            public init() {
                self.internalJson = JSON()
            }
            public init(json: Any) {
                self.internalJson = JSON(json)
            }
            public init(data: Data) {
                self.internalJson = JSON(data: data)
            }
        }\n\n\n
        """)
    }
    
    func afterGeneratingTypes() throws {
    }
    
    func beforeGeneratingMethods() throws {
        let methodsHeader = """
        // This file is automatically generated by Rapier


        import Foundation
        import Dispatch

        public extension TelegramBot {


        """
        
        context.outMethods.append(methodsHeader)
    }
    
    func generateMethod(name: String, info: MethodInfo) throws {
        
        let parameters = info.parameters.sorted { $0.key < $1.key }
        
        let fields: [String] = parameters.map { fieldName, fieldInfo in
            var result = "\(fieldName.camelized()): \(buildSwiftType(fieldInfo: fieldInfo))"
            if fieldInfo.isOptional {
                result.append(" = nil")
            }
            
            return result
        }
        
        let arrayFields: [String] = parameters.map { fieldName, _ in
            return #""\#(fieldName)": \#(fieldName.camelized())"#
        }
        
        var fieldsString = fields.joined(separator: ",\n        ")
        var arrayFieldsString = arrayFields.joined(separator: ",\n")
        
        let completionName = (name.first?.uppercased() ?? "") + name.dropFirst() + "Completion"
        let resultSwiftType = buildSwiftType(fieldInfo: info.result)
        
        if !fieldsString.isEmpty {
            fieldsString.append(",")
        }
        
        if arrayFieldsString.isEmpty {
            arrayFieldsString = ":"
        }
        
        let method = """
            typealias \(completionName) = (_ result: \(resultSwiftType), _ error: DataTaskError?) -> ()
        
            @discardableResult
            func \(name)Sync(
                    \(fieldsString)
                    _ parameters: [String: Any?] = [:]) -> \(resultSwiftType) {
                return requestSync("\(name)", defaultParameters["\(name)"], parameters, [
                    \(arrayFieldsString)])
            }

            func \(name)Async(
                    \(fieldsString)
                    _ parameters: [String: Any?] = [:],
                    queue: DispatchQueue = .main,
                    completion: \(completionName)? = nil) {
                return requestAsync("\(name)", defaultParameters["\(name)"], parameters, [
                    \(arrayFieldsString)],
                    queue: queue, completion: completion)
            }
        
        """
        
        context.outMethods.append(method)
    }
    
    func afterGeneratingMethods() throws {
        context.outMethods.append("\n}\n")
    }
    
    func finish() throws {
        try saveTypes()
        try saveMethods()
    }
    
    private func saveTypes() throws {
        let dir = URL(fileURLWithPath: context.directory, isDirectory: true)
        let file = dir.appendingPathComponent("Types.swift", isDirectory: false)
        try context.outTypes.write(to: file, atomically: true, encoding: .utf8)
    }
    
    private func saveMethods() throws {
        let dir = URL(fileURLWithPath: context.directory, isDirectory: true)
        let file = dir.appendingPathComponent("Methods.swift", isDirectory: false)
        try context.outMethods.write(to: file, atomically: true, encoding: .utf8)
    }
    
    private func buildSwiftType(fieldInfo: FieldInfo) -> String {
        var type: String
        if (fieldInfo.isArray) {
            type = "[\(fieldInfo.type)]"
        } else {
            type = fieldInfo.type
        }
        if (fieldInfo.isOptional) {
            type.append("?")
        }
        return type
    }
    
    private func buildFieldTemplate(fieldName: String, fieldInfo: FieldInfo) -> String? {
        let type = fieldInfo.type
        let isOptional = fieldInfo.isOptional
        
        let jsonName = fieldName.replacingOccurrences(of: "_string", with: "")
        
        switch (type, isOptional) {
        case ("String", _), ("Int", _), ("Int64", _), ("Float", _), ("Bool", _):
            let swiftyJsonPropertyType = fieldInfo.type.lowercased()
            
            return """
                public var \(fieldName.camelized()): \(type)\(isOptional ? "?" : "") {
                    get { return internalJson["\(jsonName)"].\(swiftyJsonPropertyType)\(isOptional ? "" : "Value") }
                    set { internalJson["\(jsonName)"].\(swiftyJsonPropertyType)\(isOptional ? "" : "Value") = newValue }
                }\n\n
            """
        case ("Date", true):
            return """
                public var \(fieldName.camelized()): Date? {
                    get {
                        guard let date = internalJson["\(jsonName)"].double else { return nil }
                        return Date(timeIntervalSince1970: date)
                    }
                    set {
                        internalJson["\(jsonName)"].double = newValue?.timeIntervalSince1970
                    }
                }\n\n
            """
        case ("Date", false):
            return """
            public var \(fieldName.camelized()): Date {
                    get { return Date(timeIntervalSince1970: internalJson["\(jsonName)"].doubleValue) }
                    set { internalJson["\(jsonName)"].double = newValue.timeIntervalSince1970 }
                }\n\n
            """
        case (_, _):
            if fieldInfo.isArrayOfArray {
                if fieldInfo.isOptional {
                    return """
                        public var \(fieldName.camelized()): [[\(fieldInfo.type)]] {
                            get { return internalJson["\(jsonName)"].twoDArrayValue() }
                            set {
                                if newValue.isEmpty {
                                    json["\(jsonName)"] = JSON.null
                                    return
                                }\n"\
                                var rowsJson = [JSON]()
                                rowsJson.reserveCapacity(newValue.count)
                                for row in newValue {
                                    var colsJson = [JSON]()
                                    colsJson.reserveCapacity(row.count)
                                    for col in row {
                                        let json = col.internalJson
                                        colsJson.append(json)
                                    }
                                    rowsJson.append(JSON(colsJson))
                                }
                                internalJson["\(jsonName)"] = JSON(rowsJson)
                            }
                        }\n\n
                    """
                } else {
                    return """
                        public var \(fieldName.camelized()): [[\(fieldInfo.type)]] {
                            get { return internalJson["\(jsonName)"].twoDArrayValue() }
                            set {
                                var rowsJson = [JSON]()
                                rowsJson.reserveCapacity(newValue.count)
                                for row in newValue {
                                    var colsJson = [JSON]()
                                    colsJson.reserveCapacity(row.count)
                                    for col in row {
                                        let json = col.internalJson
                                        colsJson.append(json)
                                    }
                                    rowsJson.append(JSON(colsJson))
                                }
                                internalJson["\(jsonName)"] = JSON(rowsJson)
                            }
                        }\n\n
                    """
                }
            } else if fieldInfo.isArray {
                if fieldInfo.isOptional {
                    return """
                        public var \(fieldName.camelized()): [\(fieldInfo.type)] {
                            get { return internalJson["\(jsonName)"].customArrayValue() }
                            set { internalJson["\(jsonName)"] = newValue.isEmpty ? JSON.null : JSON.initFrom(newValue) }
                        }\n\n
                    """
                } else {
                    return """
                        public var \(fieldName.camelized()): [\(fieldInfo.type)] {
                            get { return internalJson["\(jsonName)"].customArrayValue() }
                            set { internalJson["\(jsonName)"] = JSON.initFrom(newValue) }
                        }\n\n
                    """
                }
            } else if fieldInfo.type.starts(with: "InputMessageContent") {
                if fieldInfo.isOptional {
                    return """
                        public var inputMessageContent: InputMessageContent? {
                            get {
                                fatalError("Not implemented")
                            }
                            set {
                                internalJson["input_message_content"] = JSON(newValue?.json ?? JSON.null)
                            }
                        }\n\n
                    """
                } else {
                    return """
                        public var inputMessageContent: InputMessageContent {
                            get {
                                fatalError("Not implemented")
                            }
                            set {
                                internalJson["input_message_content"] = JSON(newValue.json)
                            }
                        }\n\n
                    """
                }
            } else if fieldInfo.type == "InputFileOrString" {
                if fieldInfo.isOptional {
                    return "public var \(fieldName.camelized()): InputFileOrString? = nil\n\n"
                } else {
                    return "public var \(fieldName.camelized()): InputFileOrString\n\n"
                }
            } else {
                if fieldInfo.isOptional {
                    return """
                        public var \(fieldName.camelized()): \(fieldInfo.type)? {
                            get {
                                let value = internalJson["\(jsonName)"]
                                return value.isNullOrUnknown ? nil : \(fieldInfo.type)(internalJson: value)
                            }
                            set {
                                internalJson["\(jsonName)"] = newValue?.internalJson ?? JSON.null
                            }
                        }\n\n
                    """
                } else {
                    return """
                        public var \(fieldName.camelized()): \(fieldInfo.type) {
                            get { return \(fieldInfo.type)(internalJson: internalJson["\(jsonName)"]) }
                            set { internalJson["\(jsonName)"] = JSON(newValue.json) }
                        }\n\n
                    """
                }
            }
        }
    }
    
    private var context: Context
}

extension TelegramBotSDKGenerator {
    private func makeGetterName(typeName: String, fieldName: String, fieldType: String) -> String {
        switch (typeName, fieldName) {
        case ("ChatMember", "status"):
            return "status_string"
        default:
            if fieldName == "type" && fieldType == "String" {
                return "type_string"
                
            }
            if fieldName == "parse_mode" && fieldType == "String" {
                return "parse_mode_string"
            }
            break
        }
        return fieldName
    }
}


extension String {
    fileprivate func camelized() -> String {
        let components = self.components(separatedBy: "_")
        
        let firstLowercasedWord = components.first?.lowercased()
        
        let remainingWords = components.dropFirst().map {
            $0.prefix(1).uppercased() + $0.dropFirst().lowercased()
        }
        return ([firstLowercasedWord].compactMap{ $0 } + remainingWords).joined()
    }
}
