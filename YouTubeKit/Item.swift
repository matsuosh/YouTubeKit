//
//  Item.swift
//  YouTubeKit
//
//  Created by matsuosh on 2015/02/26.
//  Copyright (c) 2015年 matsuosh. All rights reserved.
//

import Alamofire
import Result
import Box

func dateFromPublishedAt(publishedAt: String) -> NSDate {
    // 世界時間にする。
    var formatter = NSDateFormatter()
    formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'"
    formatter.timeZone = NSTimeZone(name: "UTC")
    let worldDate = formatter.dateFromString(publishedAt)!
    // ローカル時間にする。
    formatter = NSDateFormatter()
    formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
    formatter.timeZone = NSTimeZone.defaultTimeZone()
    let formattedLocalDate = formatter.stringFromDate(worldDate)
    return formatter.dateFromString(formattedLocalDate)!
}
func formatFromDuration(duration: String) -> String {
    var duration = duration.stringByReplacingOccurrencesOfString("PT", withString: "", options: nil, range: nil)
    var time = [0, 0, 0]
    for (index, symbol) in enumerate(["H", "M", "S"]) {
        let components = duration.componentsSeparatedByString(symbol)
        if components.count == 2 {
            time[index] = components.first!.toInt()!
            duration = duration.stringByReplacingOccurrencesOfString("\(time[index])\(symbol)", withString: "", options: nil, range: nil)
        }
    }
    var formattedTime = ""
    if time.first > 0 {
        formattedTime += NSString(format: "%d:", time.first!) as String
    }
    formattedTime += NSString(format: "%02d:%02d", time[1], time[2]) as String
    return formattedTime
}

public protocol Initializable {
    init?(JSON: NSDictionary)
}
public protocol APIDelegate: Initializable {
    //static func type() -> String
    static var type: String { get }
    static func callAPI(parameters: [String: String]) -> API
}

public class Item: Initializable {

    public let id: String!
    public let publishedAt: NSDate?
    public let title: String!
    public let description: String!
    public let thumbnailURL: String!

    public required init?(JSON: NSDictionary) {
        if let id = JSON["id"] as? String,
           let snippet = JSON["snippet"] as? NSDictionary,
           let title = snippet["title"] as? String,
           let description = snippet["description"] as? String,
           let thumbnails = snippet["thumbnails"] as? NSDictionary {

            self.id = id
            if let publishedAt = snippet["publishedAt"] as? String {
                self.publishedAt = dateFromPublishedAt(publishedAt)
            } else {
                self.publishedAt = nil
            }
            self.title = title
            self.description = description
            if let thumbnail = thumbnails["standard"] as? NSDictionary, let thumbnailURL = thumbnail["url"] as? String {
                self.thumbnailURL = thumbnailURL
            } else if let thumbnail = thumbnails["default"] as? NSDictionary, let thumbnailURL = thumbnail["url"] as? String {
                self.thumbnailURL = thumbnailURL
            } else if let thumbnail = thumbnails["medium"] as? NSDictionary, let thumbnailURL = thumbnail["url"] as? String {
                self.thumbnailURL = thumbnailURL
            } else if let thumbnail = thumbnails["high"] as? NSDictionary, let thumbnailURL = thumbnail["url"] as? String {
                self.thumbnailURL = thumbnailURL
            } else {
                self.thumbnailURL = nil
            }
        } else {
            id = nil
            publishedAt = nil
            title = nil
            description = nil
            thumbnailURL = nil
            return nil
        }
    }

    public init(id: String, publishedAt: NSDate?, title: String, description: String, thumbnailURL: String) {
        self.id = id
        self.publishedAt = publishedAt
        self.title = title
        self.description = description
        self.thumbnailURL = thumbnailURL
    }


    public func thumbnailImage(handler: (Result<UIImage, NSError>) -> Void) {
        Alamofire.request(.GET, thumbnailURL!).response { (_, _, data, error) -> Void in
            if let image = UIImage(data: NSData(data: data as! NSData)) {
                handler(.Success(Box(image)))
                return
            }
            if let error = error {
                handler(.Failure(Box(error)))
                return
            }
            handler(.Failure(Box(ResponseError.Unknown.toNSError())))
        }
    }

}

public class Video: Item {

    public let channelId: String!
    public let channelTitle: String!
    public let viewCount: Int64!
    public let duration: String!

    public required init?(JSON: NSDictionary) {
        if let snippet = JSON["snippet"] as? NSDictionary,
           let channelId = snippet["channelId"] as? String,
           let channelTitle = snippet["channelTitle"] as? String,
           let contentDetails = JSON["contentDetails"] as? NSDictionary,
           let duration = contentDetails["duration"] as? String,
           let statistics = JSON["statistics"] as? NSDictionary {
            self.channelId = channelId
            self.channelTitle = channelTitle
            if let viewCount = statistics["viewCount"] as? String {
                self.viewCount = (viewCount as NSString).longLongValue
            } else {
                self.viewCount = 0
            }
            self.duration = formatFromDuration(duration)
            super.init(JSON: JSON)
        } else {
            channelId = nil
            channelTitle = nil
            viewCount = nil
            duration = nil
            super.init(JSON: JSON)
            return nil
        }
    }

    public init(id: String, publishedAt: NSDate?, title: String, description: String, thumbnailURL: String, channelId: String, channelTitle: String, viewCount: Int64, duration: String) {
        self.channelId = channelId
        self.channelTitle = channelTitle
        self.viewCount = viewCount
        self.duration = duration
        super.init(id: id, publishedAt: publishedAt, title: title, description: description, thumbnailURL: thumbnailURL)
    }
}

extension Video: APIDelegate {
    public static var type: String = {
        return "video"
    }()
    public class func callAPI(parameters: [String: String]) -> API {
        return API.Videos(parameters: parameters)
    }
}

public class Playlist: Item {

    public let channelId: String!
    public let channelTitle: String!
    public var itemCount: Int!

    public required init?(JSON: NSDictionary) {
        if let snippet = JSON["snippet"] as? NSDictionary,
           let channelId = snippet["channelId"] as? String,
           let channelTitle = snippet["channelTitle"] as? String,
           let contentDetails = JSON["contentDetails"] as? NSDictionary {

            self.channelId = channelId
            self.channelTitle = channelTitle
            if let itemCount = contentDetails["itemCount"] as? Int {
                self.itemCount = itemCount
            } else {
                self.itemCount = 0
            }
            super.init(JSON: JSON)
        } else {
            channelId = nil
            channelTitle = nil
            itemCount = nil
            super.init(JSON: JSON)
            return nil
        }
    }

    public init(id: String, publishedAt: NSDate?, title: String, description: String, thumbnailURL: String, channelId: String, channelTitle: String, itemCount: Int?) {
        self.channelId = channelId
        self.channelTitle = channelTitle
        self.itemCount = itemCount
        super.init(id: id, publishedAt: publishedAt, title: title, description: description, thumbnailURL: thumbnailURL)
    }

}

extension Playlist: APIDelegate {
    public static var type: String = {
        return "playlist"
    }()
    public class func callAPI(parameters: [String: String]) -> API {
        return API.Playlists(parameters: parameters)
    }
}

public class Channel: Item {

    public let viewCount: Int?
    public let subscriberCount: Int?
    public let videoCount: Int?

    public required init?(JSON: NSDictionary) {
        if let statistics = JSON["statistics"] as? NSDictionary {
            if let viewCount = statistics["viewCount"] as? String {
                self.viewCount = viewCount.toInt()
            } else {
                self.viewCount = nil
            }
            if let subscriberCount = statistics["subscriberCount"] as? String {
                self.subscriberCount = subscriberCount.toInt()
            } else {
                self.subscriberCount = nil
            }
            if let videoCount = statistics["videoCount"] as? String {
                self.videoCount = videoCount.toInt()
            } else {
                self.videoCount = nil
            }
            super.init(JSON: JSON)
        } else {
            viewCount = nil
            subscriberCount = nil
            videoCount = nil
            super.init(JSON: JSON)
            return nil
        }
    }

    public init(id: String, publishedAt: NSDate?, title: String, description: String, thumbnailURL: String, viewCount: Int?, subscriberCount: Int?, videoCount: Int?) {
        self.viewCount = viewCount
        self.subscriberCount = subscriberCount
        self.videoCount = videoCount
        super.init(id: id, publishedAt: publishedAt, title: title, description: description, thumbnailURL: thumbnailURL)
    }

}

extension Channel: APIDelegate {
    public static var type: String = {
        return "channel"
    }()
    public class func callAPI(parameters: [String: String]) -> API {
        return API.Channels(parameters: parameters)
    }
}

public class GuideCategory {
    public let id: String
    public let title: String
    public var channel: Channel?
    init(JSON: NSDictionary) {
        id = JSON["id"] as! String
        title = (JSON["snippet"] as! NSDictionary)["title"] as! String
    }
}

public struct Error {
    let code: Int!
    let message: String!
    init?(JSON: NSDictionary) {
        if let error = JSON["error"] as? NSDictionary {
            if let code = error["code"] as? Int {
                self.code = code
            } else {
                self.code = 99999
            }
            if let message = error["message"] as? String {
                self.message = message
            } else {
                self.message = ""
            }
        } else {
            return nil
        }
    }
    func toNSError() -> NSError {
        return NSError(domain: "YouTubeKitErrorDomain", code: code, userInfo: [NSLocalizedDescriptionKey: message])
    }
}

public struct Page {
    public let prev: String?
    public let next: String?
    public var totalResults: Int?
    public var resultsPerPage: Int?
    init(JSON: NSDictionary) {
        next = JSON["nextPageToken"] as? String
        prev = JSON["prevPageToken"] as? String
        if let pageInfo = JSON["pageInfo"] as? NSDictionary {
            totalResults = pageInfo["totalResults"] as? Int
            resultsPerPage = pageInfo["resultsPerPage"] as? Int
        }
    }
}