
import Foundation
import UIKit

open class PlayerCacheMediaWorker: NSObject {
    open fileprivate(set) var cacheConfiguration: PlayerCacheMediaConfiguration?
    open fileprivate(set) var setupError: Error?
    
    fileprivate var readFileHandle: FileHandle?
    fileprivate var writeFileHandle: FileHandle?
    fileprivate var filePath: String
    fileprivate var currentOffset: UInt64?
    fileprivate var starWriteDate: NSDate?
    fileprivate var writeBytes: Double = 0.0
    fileprivate var isWritting: Bool = false
    
    fileprivate let writeFileQueue = DispatchQueue(label: "com.player.cacheWriteFileQueue")
    fileprivate let kPackageLength = 204800
    
    deinit {
        NotificationCenter.default.removeObserver(self)
        save()
        readFileHandle?.closeFile()
        writeFileHandle?.closeFile()
    }
    
    public init(url: URL) {
        let path = PlayerCacheManager.cacheFilePath(for: url)
        filePath = path
        let fileManager = FileManager.default
        let cacheFolder = (path as NSString).deletingLastPathComponent
        var err: Error?
        if !fileManager.fileExists(atPath: cacheFolder) {
            do {
                try fileManager.createDirectory(atPath: cacheFolder, withIntermediateDirectories: true, attributes: nil)
            }
            catch {
                err = error
            }
        }
        
        if err == nil {
            if !FileManager.default.fileExists(atPath: path) {
                FileManager.default.createFile(atPath: path, contents: nil, attributes: nil)
            }
            let fileURL = URL(fileURLWithPath: path)
            
            do {
                try readFileHandle = FileHandle(forReadingFrom: fileURL)
            } catch {
                err = error
            }
            
            if err == nil {
                if !FileManager.default.fileExists(atPath: path) {
                    FileManager.default.createFile(atPath: path, contents: nil, attributes: nil)
                }
                
                do {
                    try writeFileHandle = FileHandle(forWritingTo: fileURL)
                    cacheConfiguration = PlayerCacheMediaConfiguration.configuration(filePath: path)
                    cacheConfiguration?.url = url
                } catch {
                    err = error
                }
            }
        }
        
        setupError = err;
        super.init()
    }
    
    open func cache(_ data: Data, forRange range: NSRange, closure: (Bool) -> Void) {
        writeFileQueue.sync {

            if let _ = writeFileHandle?.seek(toFileOffset: UInt64(range.location)),
                let _ = writeFileHandle?.write(data) {
                writeBytes += Double(data.count)
                cacheConfiguration?.addCache(range)
                closure(true)
            } else {
                closure(false)
            }
        }
    }
    
    open func cache(forRange range: NSRange) -> Data? {
        readFileHandle?.seek(toFileOffset: UInt64(range.location))
        let data = readFileHandle?.readData(ofLength: range.length)
        return data
    }
    
    open func cachedDataActions(forRange range:NSRange) -> Array<PlayerCacheAction> {
        var actions = [PlayerCacheAction]()
        if range.location == NSNotFound {
            return actions
        }
        
        let endOffset = range.location + range.length
        
        if let cachedSegments = cacheConfiguration?.cacheSegments {
            
            for (_, value) in cachedSegments.enumerated() {
                let segmentRange = value.rangeValue
                let intersctionRange = NSIntersectionRange(range, segmentRange)
                if intersctionRange.length > 0 {
                    let package = intersctionRange.length / kPackageLength
                    for i in 0...package {
                        let offset = i * kPackageLength
                        let offsetLocation = intersctionRange.location + offset
                        let maxLocation = intersctionRange.location + intersctionRange.length
                        let length = (offsetLocation + kPackageLength) > maxLocation ? (maxLocation - offsetLocation) : kPackageLength
                        let ra = NSMakeRange(offsetLocation, length)
                        let action = PlayerCacheAction(type: .local, range: ra)
                        actions.append(action)
                    }
                } else if segmentRange.location >= endOffset {
                    break
                }
            }
        }
        if actions.count == 0 {
            let action = PlayerCacheAction(type: .remote, range: range)
            actions.append(action)
        } else {
            var localRemoteActions = [PlayerCacheAction]()
            for (index, value) in actions.enumerated() {
                let actionRange = value.range
                if index == 0 {
                    if range.location < actionRange.location {
                        let ra = NSMakeRange(range.location, actionRange.location - range.location)
                        let action = PlayerCacheAction(type: .remote, range: ra)
                        localRemoteActions.append(action)
                    }
                    localRemoteActions.append(value)
                } else {
                    if let lastAction = localRemoteActions.last {
                        let lastOffset = lastAction.range.location + lastAction.range.length
                        if actionRange.location > lastOffset {
                            let ra = NSMakeRange(lastOffset, actionRange.location - lastOffset)
                            let action = PlayerCacheAction(type: .remote, range: ra)
                            localRemoteActions.append(action)
                        }
                    }
                    localRemoteActions.append(value)
                }
                
                if index == actions.count - 1 {
                    let localEndOffset = actionRange.location + actionRange.length
                    if endOffset > localEndOffset {
                        let ra = NSMakeRange(localEndOffset, endOffset)
                        let action = PlayerCacheAction(type: .remote, range: ra)
                        localRemoteActions.append(action)
                    }
                }
            }
            
            actions = localRemoteActions
        }
        return actions
    }
    
    open func set(cacheMedia: PlayerCacheMedia) -> Bool {
        cacheConfiguration?.cacheMedia = cacheMedia
        if let _ = writeFileHandle?.truncateFile(atOffset: UInt64(cacheMedia.contentLength)),
            let _ = writeFileHandle?.synchronizeFile(){
            return true
        } else {
            return false
        }
    }
    
    open func save() {
        writeFileQueue.sync {
            writeFileHandle?.synchronizeFile()
            cacheConfiguration?.save()
        }
    }
    
    open func startWritting() {
        if !isWritting {
            NotificationCenter.default.addObserver(self, selector: #selector(applicationDidEnterBackground(_:)), name:UIApplication.didEnterBackgroundNotification , object: nil)
        }
        isWritting = true
        starWriteDate = NSDate()
        writeBytes = 0.0
    }
    
    open func finishWritting() {
        if isWritting {
            isWritting = false
            NotificationCenter.default.removeObserver(self)
            if let starWriteDate = starWriteDate {
                let time = Date().timeIntervalSince(starWriteDate as Date)
                cacheConfiguration?.add(UInt64(writeBytes), time: time)
            }
        }
    }
    
    @objc internal func applicationDidEnterBackground(_ notification: Notification) {
        save()
    }
}
