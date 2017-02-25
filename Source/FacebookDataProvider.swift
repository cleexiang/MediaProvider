//
//  FacebookDataProvider.swift
//  Muse
//
//  Created by clee on 16/10/17.
//  Copyright © 2016年 PG. All rights reserved.
//

import Foundation
import UIKit
import CoreLocation
import AVFoundation

/// Facebook资源
public class FacebookAsset: MediaAsset {
    
    public var assetIdentifier: String

    public var assetType: AssetMediaType

    public var assetURL: URL?

    public var timeDuration: Double = 0

    public var coordinate: CLLocationCoordinate2D?

    public var thumbnailURL: URL?

    private var thumbnail: UIImage?

    public init(thumbnailURL: URL, assetURL: URL, assetType: AssetMediaType) {
        self.thumbnailURL = thumbnailURL
        self.assetURL = assetURL
        self.assetType = assetType
        self.assetIdentifier = assetURL.absoluteString;
    }

    public func fetchThumbnail(_ completed: @escaping (_ thumbnail: UIImage?) -> Void) {
        guard let thumbnailURL = self.thumbnailURL else {
            completed(nil)
            return
        }
        DispatchQueue.global().async {
            do {
                let data = try Data(contentsOf: thumbnailURL)
                let image = UIImage(data: data)
                DispatchQueue.main.sync {
                    completed(image)
                }
            } catch {
                assertionFailure("下载缩略图出错")
            }
        }
    }

    public func fetchAVAsset(_ completed: @escaping (_ avAsset: AVAsset?) -> Void) {
        guard let assetURL = self.assetURL else {
            completed(nil)
            return
        }
        DispatchQueue.global().async {
            let localUrl = URL(fileURLWithPath: NSTemporaryDirectory() + String(assetURL.absoluteString.hashValue) + ".mp4")
            if FileManager.default.fileExists(atPath: localUrl.absoluteString) {
                DispatchQueue.main.sync {
                    let asset = AVAsset(url: localUrl)
                    completed(asset)
                }
            } else {
                do {
                    let data = try Data(contentsOf: assetURL)
                    try data.write(to: localUrl)
                    DispatchQueue.main.sync {
                        let asset = AVAsset(url: localUrl)
                        completed(asset)
                    }
                } catch {
                    assertionFailure("下载视频出错")
                }
            }
        }
    }

    public func display(_ forImageView: UIImageView) {
        if let thumbnail = self.thumbnail {
            forImageView.image = thumbnail
        } else {
            DispatchQueue.global().async {
                self.fetchThumbnail {
                    forImageView.image = $0
                }
            }
        }
    }
}

/// Facebook数据源提供者
public class FacebookDataProvider: NetworkMediaDataProviderCompatible, OAuthViewControllerDelegate {
    public var baseURL: String {
        get {
            return ""
        }
    }

    public var authorizePath: String {
        get {
            return "https://www.facebook.com/v2.8/dialog/oauth"
        }
    }

    public var accessTokenPath: String {
        get {
            return "https://graph.facebook.com/v2.8/oauth/access_token"
        }
    }

    public var fetchMediaPath: String {
        get {
            return "https://graph.facebook.com/me/videos?fields=created_time,source,length,thumbnails&type=uploaded"
        }
    }

    public var redirectURL: String
    public var clientId: String
    public var clientSecret: String
    public var scopes:[String]

    var accessToken: String?

    var authorizeComplete: ((AuthorizeResult) -> Void)?
    var fetchMediaComplete: (([MediaAsset]) -> Void)?

    public init(clientId: String, clientSecret: String, scopes: Array<String>, redirectURL: String) {
        self.clientId = clientId
        self.clientSecret = clientSecret
        self.scopes = scopes
        self.redirectURL = redirectURL
    }

    public func authorize(complete: @escaping (_ status: AuthorizeResult) -> Void) {
        self.authorizeComplete = complete

        let oauthVC = OAuthViewController(baseURL: self.baseURL,
                                            authorizePath: self.authorizePath,
                                            accessTokenPath: self.accessTokenPath,
                                            clientId: self.clientId,
                                            clientSecret: self.clientSecret,
                                            scopes: self.scopes,
                                            redirectUri: self.redirectURL)

        oauthVC.delegate = self
        let nav = UINavigationController(rootViewController: oauthVC)
        UIApplication.shared.keyWindow?.rootViewController?.present(nav, animated: true, completion: nil)
    }

    public func fetchMedia(_ withType: AssetMediaType, _ minDuration: Double = 0, _ complete: @escaping (_ result: [MediaAsset]) -> Void) {
        self.fetchMediaComplete = complete
        guard let accessToken = self.accessToken else {
            self.authorizeComplete!(.success)
            return
        }
        let url = URL(string: self.fetchMediaPath + "&access_token=" + accessToken)
        var request = URLRequest(url: url!, cachePolicy: .useProtocolCachePolicy, timeoutInterval: 60.0)
        request.httpMethod = "GET"
        let session = URLSession(configuration: URLSessionConfiguration.default, delegate:nil, delegateQueue:nil)
        let task = session.dataTask(with: request, completionHandler: { (data, response, error) in
            if let error = error {
                print(error)
            }
            guard let data = data else {
                return
            }
            let result = String(data: data, encoding: String.Encoding.utf8)
            print(result)
            var assets = [MediaAsset]()
            do {
                let json = try JSONSerialization.jsonObject(with: data, options: [.allowFragments]) as! Dictionary<String, AnyObject>
                let dataArrayJson = json["data"] as! Array<Dictionary<String, AnyObject>>
                for dataJson in dataArrayJson {

                    guard let videoUrl = dataJson["source"] as? String else {
                        continue
                    }

                    guard let length = dataJson["length"] as? Double else {
                        continue
                    }
                    guard let imagesJson = dataJson["thumbnails"] as? Dictionary<String, AnyObject> else {
                        continue
                    }

                    var thumbnailUrl = ""
                    let imageDataJson = imagesJson["data"] as! Array<Dictionary<String, AnyObject>>
                    if imageDataJson.count > 0 {
                        let thumbnailJson = imageDataJson[0]
                        thumbnailUrl = thumbnailJson["uri"] as! String
                    }

                    let facebookAsset = FacebookAsset(thumbnailURL:URL(string: thumbnailUrl)!, assetURL: URL(string: videoUrl)!, assetType: .video)
                    facebookAsset.timeDuration = length
                    assets.append(facebookAsset)
                }
            } catch {
                assertionFailure("获取facebook资源列表的JSON数据有错误")
            }
            complete(assets)
        })
        task.resume()
    }

    public func oauthSuccess(_ viewController: OAuthViewController, accessToken: String) {
        self.accessToken = accessToken
        self.authorizeComplete!(.success)
        viewController.dismiss(animated: true, completion: nil)
    }

    public func oauthFail(_ viewController: OAuthViewController, error: NSError?) {
        self.authorizeComplete!(.fail)
        viewController.dismiss(animated: true, completion: nil)
    }
}

extension FacebookDataProvider: MediaDataProviderCacheable {
    static var cacheDirectory: String {
        get {
            return NSTemporaryDirectory() + "facebook"
        }
    }

    public static func cache(data: Data, url: String) {
        let localPath = self.cacheDirectory + "\(url)"
        if FileManager.default.fileExists(atPath: localPath) {
            return
        }
        do {
            try data.write(to: URL(string: url)!)
        } catch {
            assertionFailure("保存文件出错")
        }
    }

    public static func clearCache() {
        do {
            let items = try FileManager.default.subpathsOfDirectory(atPath: self.cacheDirectory)
            for item in items {
                do {
                    try FileManager.default.removeItem(atPath: item)
                } catch {
                }
            }
        } catch {
        }
    }
}
