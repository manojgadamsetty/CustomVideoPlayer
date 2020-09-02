

import Foundation
import MobileCoreServices

// MARK: - PlayerDownloaderStatus
public struct PlayerDownloaderStatus {
    
    static let shared = PlayerDownloaderStatus()
    fileprivate var downloadingURLs: NSMutableSet
    fileprivate let downloaderStatusQueue = DispatchQueue(label: "com.Player.downloaderStatusQueue")
    
    init() {
        downloadingURLs = NSMutableSet()
    }
    
    public func add(URL: URL) {
        downloaderStatusQueue.sync {
            downloadingURLs.add(URL)
        }
    }
    
    public func remove(URL: URL) {
        downloaderStatusQueue.sync {
            downloadingURLs.remove(URL)
        }
    }
    
    public func contains(URL: URL) -> Bool{
        return downloadingURLs.contains(URL)
    }
    
    public func urls() -> NSSet {
        return downloadingURLs.copy() as! NSSet
    }
}

public protocol PlayerDownloaderDelegate: class {
    func downloader(_ downloader: PlayerDownloader, didReceiveResponse response: URLResponse)
    func downloader(_ downloader: PlayerDownloader, didReceiveData data: Data)
    func downloader(_ downloader: PlayerDownloader, didFinishedWithError error: Error?)
}


extension PlayerDownloaderDelegate {
    public func downloader(_ downloader: PlayerDownloader, didReceiveResponse response: URLResponse) { }
    public func downloader(_ downloader: PlayerDownloader, didReceiveData data: Data) { }
    public func downloader(_ downloader: PlayerDownloader, didFinishedWithError error: Error?) { }
}

// MARK: - PlayerDownloader
open class PlayerDownloader: NSObject {
    open fileprivate(set) var url: URL
    open weak var delegate: PlayerDownloaderDelegate?
    open var cacheMedia: PlayerCacheMedia?
    open var cacheMediaWorker: PlayerCacheMediaWorker
    
    fileprivate var session: URLSession = {
        let configuration = URLSessionConfiguration.default
        let session = URLSession(configuration: configuration)
        return session
    }()
    fileprivate var isDownloadToEnd: Bool = false
    fileprivate var actionWorker: PlayerDownloadActionWorker?
    
    deinit {
        PlayerDownloaderStatus.shared.remove(URL: url)
    }
    
    public init(url: URL) {
        self.url = url
        cacheMediaWorker = PlayerCacheMediaWorker(url: url)
        cacheMedia = cacheMediaWorker.cacheConfiguration?.cacheMedia
        super.init()
    }
    
    open func dowloaderTask(_ fromOffset: Int64, _ length: Int, _ isEnd: Bool) {
        if isCurrentURLDownloading() {
            handleCurrentURLDownloadingError()
            return
        }
        PlayerDownloaderStatus.shared.add(URL: self.url)
        
        var range = NSRange(location: Int(fromOffset), length: length)
        if isEnd {
            if let contentLength = cacheMediaWorker.cacheConfiguration?.cacheMedia?.contentLength {
                range.length = Int(contentLength) - range.location
            } else {
                range.length = 0 - range.location
            }
            
        }
        let actions = cacheMediaWorker.cachedDataActions(forRange: range)
        actionWorker = PlayerDownloadActionWorker(actions: actions, url: url, cacheMediaWorker: cacheMediaWorker)
        actionWorker?.delegate = self
        actionWorker?.start()
    }
    open func dowloadFrameStartToEnd() {
        if isCurrentURLDownloading() {
            handleCurrentURLDownloadingError()
            return
        }
        PlayerDownloaderStatus.shared.add(URL: url)
        
        isDownloadToEnd = true
        let range = NSRange(location: 0, length: 2)
        let actions = cacheMediaWorker.cachedDataActions(forRange: range)
        actionWorker = PlayerDownloadActionWorker(actions: actions, url: url, cacheMediaWorker: cacheMediaWorker)
        actionWorker?.delegate = self
        actionWorker?.start()
        
        
    }
    open func cancel() {
        PlayerDownloaderStatus.shared.remove(URL: url)
        actionWorker?.cancel()
        actionWorker?.delegate = nil
        actionWorker = nil
    }
    
    open func invalidateAndCancel() {
        PlayerDownloaderStatus.shared.remove(URL: url)
        actionWorker?.cancel()
        actionWorker?.delegate = nil
        actionWorker = nil
    }
    
    // check
    internal func isCurrentURLDownloading() -> Bool {
        return PlayerDownloaderStatus.shared.contains(URL: url)
    }
    
    internal func handleCurrentURLDownloadingError() {
        
        if isCurrentURLDownloading() {
            let userInfo = [NSLocalizedDescriptionKey: "URL: \(url) alreay in downloading queue."]
            let error = NSError(domain: "com.player.download", code: -1, userInfo: userInfo)
            delegate?.downloader(self, didFinishedWithError: error as Error)
        }
    }
}

// MARK: - PlayerDownloadActionWorkerDelegate
extension PlayerDownloader: PlayerDownloadActionWorkerDelegate {
    
    public func downloadActionWorker(_ actionWorker: PlayerDownloadActionWorker, didFinishWithError error: Error?) {
        PlayerDownloaderStatus.shared.remove(URL: url)
        if error == nil && isDownloadToEnd {
            isDownloadToEnd = false
            let length = (cacheMediaWorker.cacheConfiguration?.cacheMedia?.contentLength)! - 2
            dowloaderTask(2, Int(length), true)
        } else {
            delegate?.downloader(self, didFinishedWithError: error)
        }
    }
    
    public func downloadActionWorker(_ actionWorker: PlayerDownloadActionWorker, didReceive data: Data, isLocal: Bool) {
        delegate?.downloader(self, didReceiveData: data)
    }
    
    public func downloadActionWorker(_ actionWorker: PlayerDownloadActionWorker, didReceive response: URLResponse) {
        if cacheMedia == nil {
            let cacheMedia = PlayerCacheMedia()
            if response.isKind(of: HTTPURLResponse.classForCoder()) {
                
                let HTTPurlResponse = response as! HTTPURLResponse                                  // set header
                let acceptRange = HTTPurlResponse.allHeaderFields["Accept-Ranges"] as? String
                if let bytes = acceptRange?.isEqual("bytes") {
                    cacheMedia.isByteRangeAccessSupported = bytes
                }
                // fix swift allHeaderFields NO! case insensitive
                let contentRange = HTTPurlResponse.allHeaderFields["content-range"] as? String
                let contentRang = HTTPurlResponse.allHeaderFields["Content-Range"] as? String
                if let last = contentRange?.components(separatedBy: "/").last {
                    cacheMedia.contentLength = Int64(last)!
                }
                if let last = contentRang?.components(separatedBy: "/").last {
                    cacheMedia.contentLength = Int64(last)!
                }
                
            }
            if let mimeType = response.mimeType {
                let contentType =  UTTypeCreatePreferredIdentifierForTag(kUTTagClassMIMEType, mimeType as CFString, nil)
                if let takeUnretainedValue = contentType?.takeUnretainedValue() {
                    cacheMedia.contentType = takeUnretainedValue as String
                }
            }
            self.cacheMedia = cacheMedia
            let isSetCacheMedia = cacheMediaWorker.set(cacheMedia: cacheMedia)
            if !isSetCacheMedia {
                let nsError = NSError(domain: "com.player.cacheMedia", code: -1, userInfo: [NSLocalizedDescriptionKey:"Set cache media failed."])
                delegate?.downloader(self, didFinishedWithError: nsError as Error)
                return
            }
        }
        delegate?.downloader(self, didReceiveResponse: response)
    }
    
    
}
