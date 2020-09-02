
import Foundation
import AVFoundation

public protocol PlayerResourceLoaderDelegate: class {
    func resourceLoader(_ resourceLoader: PlayerResourceLoader, didFailWithError  error:Error?)
}

open class PlayerResourceLoader: NSObject {
    open fileprivate(set) var url: URL
    open weak var delegate: PlayerResourceLoaderDelegate?
    
    fileprivate var downloader: PlayerDownloader
    fileprivate var pendingRequestWorkers = Dictionary<String ,PlayerResourceLoadingRequest>()
    fileprivate var isCancelled: Bool = false
    
    deinit {
        downloader.invalidateAndCancel()
    }
    
    public init(url: URL) {
        self.url = url
        downloader = PlayerDownloader(url: url)
        super.init()
    }
    
    open func add(_ request: AVAssetResourceLoadingRequest) {
        for (_, value) in pendingRequestWorkers {
            value.cancel()
            value.finish()
        }
        pendingRequestWorkers.removeAll()
        startWorker(request)
    }
    
    open func remove(_ request: AVAssetResourceLoadingRequest) {
        let key = self.key(forRequest: request)
        let loadingRequest = PlayerResourceLoadingRequest(downloader, request)
        loadingRequest.finish()
        pendingRequestWorkers.removeValue(forKey: key)
    }
    
    open func cancel() {
        downloader.cancel()
    }
    
    internal func startWorker(_ request: AVAssetResourceLoadingRequest) {
        let key = self.key(forRequest: request)
        let loadingRequest = PlayerResourceLoadingRequest(downloader, request)
        loadingRequest.delegate = self
        pendingRequestWorkers[key] = loadingRequest
        loadingRequest.startWork()
    }
    
    internal func key(forRequest request: AVAssetResourceLoadingRequest) -> String {
        
        if let range = request.request.allHTTPHeaderFields!["Range"]{
            return String(format: "%@%@", (request.request.url?.absoluteString)!, range)
        }
        
        return String(format: "%@", (request.request.url?.absoluteString)!)
    }
}

// MARK: - PlayerResourceLoadingRequestDelegate
extension PlayerResourceLoader: PlayerResourceLoadingRequestDelegate {
    public func resourceLoadingRequest(_ resourceLoadingRequest: PlayerResourceLoadingRequest, didCompleteWithError error: Error?) {
        remove(resourceLoadingRequest.request)
        if error != nil {
            delegate?.resourceLoader(self, didFailWithError: error)
        }
    }
    
}

