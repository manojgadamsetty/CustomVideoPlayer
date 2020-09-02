

import Foundation

open class PlayerCacheSession: NSObject {
    public fileprivate(set) var downloadQueue: OperationQueue
    static let shared = PlayerCacheSession()
    
    public override init() {
        let queue = OperationQueue()
        queue.name = "com.player.downloadSession"
        downloadQueue = queue
    }
}
