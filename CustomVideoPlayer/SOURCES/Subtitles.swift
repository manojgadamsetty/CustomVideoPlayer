

import Foundation

public enum subtitlesFormat : String {
    case unknown
    case srt
    case ass
}

public struct subtitles: CustomStringConvertible {
    public var index : Int
    public var start : TimeInterval
    public var end : TimeInterval
    public var content : String
    
    init(index: Int, start: TimeInterval, end: TimeInterval, content: String) {
        self.index = index
        self.start = start
        self.end = end
        self.content = content
    }
    
    public var description: String {
        return "\nindex: \(index)\n start: \(start)\n end: \(end)\n content: \(content)\n\n\n\n"
    }
}

open class Subtitles {
    
    open fileprivate(set) var subtitlesFormat : subtitlesFormat = .unknown
    open fileprivate(set) var subtitlesGroups : [subtitles] = []
    
    public init(filePath: URL, encoding: String.Encoding = String.Encoding.utf8) {
        
        do{
            subtitlesFormat = decoderSubtitlesFormat(filePath)
            let string = try String(contentsOf: filePath, encoding: encoding)
            subtitlesGroups = parseSubtitles(string)
        }
        catch { }
    }
    
    public func search(for time: TimeInterval) -> subtitles? {
        var result : subtitles?
        for group in subtitlesGroups {
            if group.start <= time && group.end >= time {
                result = group
                return result
            }
        }
        return result
    }
    
    
    fileprivate func parseSubtitles(_ payload: String) -> [subtitles]  {
        switch subtitlesFormat {
        case .srt:
            return parseStrSubtitles(payload)!
        case .ass:
            return parseAssSubtitles(payload)!
        default:
            return []
        }
        
    }
    
    fileprivate func parseStrSubtitles(_ payload: String) -> [subtitles]? {
        var group: [subtitles] = []
        let scanner = Scanner(string: payload)
        while !scanner.isAtEnd {
            
            var indexString: NSString?
            scanner.scanUpToCharacters(from: .newlines, into: &indexString)
            
            var startString: NSString?
            scanner.scanUpTo(" --> ", into: &startString)
            
            scanner.scanString("-->", into: nil)
            
            var endString: NSString?
            scanner.scanUpToCharacters(from: .newlines, into: &endString)
            
            var contentString: NSString?
            scanner.scanUpTo("\r\n\r\n", into: &contentString)
            
            if let indexString = indexString,
                let index = Int(indexString as String),
                let start = startString,
                let end   = endString,
                let content  = contentString {
                let starTime = parseTime(start as String)
                let endTime = parseTime(end as String)
                let sub = subtitles(index: index, start: starTime, end: endTime, content: content as String)
                group.append(sub)
            }
        }
        return group
        
    }
    
    fileprivate func parseAssSubtitles(_ payload: String) -> [subtitles]? {
        var groups: [subtitles] = []
        let regxString = "Dialogue: [^,.]*[0-9]*,([1-9]?[0-9]*:[0-9]*:[0-9]*.[0-9]*),([1-9]?[0-9]*:[0-9]*:[0-9]*.[0-9]*),[^,.]*,[^,.]*,[0-9]*,[0-9]*,[0-9]*,[^,.]*,(.*)"
        var index = 0
        do {
            let regex = try NSRegularExpression(pattern: regxString, options: .caseInsensitive)
            let matches = regex.matches(in: payload, options: NSRegularExpression.MatchingOptions(rawValue: 0), range: NSMakeRange(0, payload.count))
            for matche in matches {
                let group = (payload as NSString).substring(with: matche.range)
                let regex = try NSRegularExpression(pattern: "\\d{1,2}:\\d{1,2}:\\d{1,2}[,.]\\d{1,3}", options: .caseInsensitive)
                let match = regex.matches(in: group, options: NSRegularExpression.MatchingOptions(rawValue: 0), range: NSMakeRange(0, group.count))
                guard let start = match.first, let end = match.last else {
                    continue
                }
                let startString = (group as NSString).substring(with: start.range)
                let endString = (group as NSString).substring(with: end.range)
                
                // content before
                let contentRegex = try NSRegularExpression(pattern: "[0-9]*,[0-9]*,[^,.]*,[^,.]*,[0-9]*,[0-9]*,", options: .caseInsensitive)
                let contentMatch = contentRegex.matches(in: group, options: NSRegularExpression.MatchingOptions(rawValue: 0), range: NSMakeRange(0, group.count))
                
                guard let text = contentMatch.first else {
                    continue
                }
                
                guard (group as NSString).length - text.range.length > 0 else {
                    continue
                }
                
                let contentRange = NSMakeRange(0, text.range.location + text.range.length + 1)
                let content = (group as NSString).replacingCharacters(in: contentRange, with: "")
                let starTime = parseTime(startString as String)
                let endTime = parseTime(endString as String)
                let sub = subtitles(index: index, start: starTime, end: endTime, content: content )
                groups.append(sub)
                index += 1
            }
            return groups
        } catch _ {
            return groups
        }
    }
    
    fileprivate func decoderSubtitlesFormat(_ filePath: URL) -> subtitlesFormat {
        let path = filePath.absoluteString
        if path.contains(".srt") {
            return .srt
        } else if path.contains(".ass") {
            return .ass
        } else {
            return .unknown
        }
    }
    
    fileprivate func parseTime(_ timeString: String) -> TimeInterval {
        var h: TimeInterval = 0.0, m: TimeInterval = 0.0, s: TimeInterval = 0.0, c: TimeInterval = 0.0
        let scanner = Scanner(string: timeString)
        scanner.scanDouble(&h)
        scanner.scanString(":", into: nil)
        scanner.scanDouble(&m)
        scanner.scanString(":", into: nil)
        scanner.scanDouble(&s)
        scanner.scanString(",", into: nil)
        scanner.scanDouble(&c)
        let time = (h * 3600.0) + (m * 60.0) + s + (c / 1000.0)
        return time
    }
    
    
}













