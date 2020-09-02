
import Foundation

public enum PlayerCacheActionType: Int {
    case local
    case remote
}

public struct PlayerCacheAction: Hashable, CustomStringConvertible {
    public var type: PlayerCacheActionType
    public var range: NSRange
    
    public var description: String {
        return "type: \(type)  range:\(range)"
    }
    
    public var hashValue: Int {
        return String(format: "%@%@", NSStringFromRange(range), String(describing: type)).hashValue
    }
    
    public static func ==(lhs: PlayerCacheAction, rhs: PlayerCacheAction) -> Bool {
        return lhs.hashValue == rhs.hashValue
    }
    
    init(type: PlayerCacheActionType, range: NSRange) {
        self.type = type
        self.range = range
    }
    
}
