import Foundation

public struct FieldInfo {
    public init(type: String = "", isArray: Bool = false, isArrayOfArray: Bool = false, isOptional: Bool = false) {
        self.type = type
        self.isArray = isArray
        self.isArrayOfArray = isArrayOfArray
        self.isOptional = isOptional
    }
    
    public var type: String
    public var isArray: Bool
    public var isArrayOfArray: Bool
    public var isOptional: Bool
}
