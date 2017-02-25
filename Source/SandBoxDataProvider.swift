//
//  SandBoxDataProvider.swift
//  Muse
//
//  Created by clee on 16/10/26.
//  Copyright © 2016年 PG. All rights reserved.
//

import UIKit
import AVFoundation
import CoreLocation

/// 存放在沙盒的资源
public class SandBoxAsset: MediaAsset {
    
    public var assetIdentifier: String

    public var assetType: AssetMediaType

    public var assetURL: URL?

    public var thumbnailURL: URL?
    
    public var timeDuration: Double {
        get {
            guard let assetURL = self.assetURL else {
                return 0
            }
            let avAsset = AVAsset(url: assetURL)
            return CMTimeGetSeconds(avAsset.duration)
        }
    }

    public var coordinate: CLLocationCoordinate2D? {
        return nil
    }

    private var thumbnail: UIImage?

    public func fetchThumbnail(_ completed: @escaping (UIImage?) -> Void) {
        completed(nil)
    }

    public init(assetURL: URL, assetType: AssetMediaType) {
        self.assetURL = assetURL
        self.assetType = assetType
        self.assetIdentifier = assetURL.absoluteString
    }

    public func fetchAVAsset(_ completed: @escaping (_ avAsset: AVAsset?) -> Void) {
        guard let assetURL = self.assetURL else {
            completed(nil)
            return
        }
        let avAsset = AVAsset(url: assetURL)
        completed(avAsset)
    }

    public func display(_ forImageView: UIImageView) {
        if let path = self.assetURL?.absoluteString {
            if path.hasSuffix("JPG") {
                let image = UIImage(contentsOfFile: path)
                forImageView.image = image
            }
        } else {
            self.fetchAVAsset { avAsset in
                guard let avAsset = avAsset else {
                    return
                }
                let duration = avAsset.duration
                let snapshot = CMTimeMake(duration.value / 2, duration.timescale);
                let generator = AVAssetImageGenerator(asset: avAsset)
                generator.appliesPreferredTrackTransform = true

                do {
                    let cgImage = try generator.copyCGImage(at: snapshot, actualTime: nil)
                    forImageView.image = UIImage(cgImage: cgImage)
                } catch {
                    assertionFailure("获取缩略图失败")
                }
            }
        }
    }
}

public class SandBoxDataProvider: MediaDataProviderCompatible {

    var authorizeComplete: ((AuthorizeResult) -> Void)?
    var fetchMediaComplete: (([MediaAsset]) -> Void)?

    public func authorize(complete: @escaping (_ status: AuthorizeResult) -> Void) {
        complete(.success)
    }

    public func fetchMedia(_ withType: AssetMediaType, _ minDuration: Double = 0, _ complete: @escaping (_ result: [MediaAsset]) -> Void) {
        self.fetchMediaComplete = complete
        var items = [MediaAsset]()
        DispatchQueue.global().async {
            do {
                let resources = try FileManager.default.contentsOfDirectory(atPath: SandBoxDataProvider.cacheDirectory)
                for path in resources {
                    if withType == .video {
                        if path.hasSuffix("mov") {
                            let sandBoxAsset = SandBoxAsset(assetURL: URL(fileURLWithPath: SandBoxDataProvider.cacheDirectory.appending("/\(path)")), assetType: .video)
                            items.append(sandBoxAsset)
                        }
                    } else if withType == .image {
                        if path.hasSuffix("JPG") {
                            if let url = URL(string: SandBoxDataProvider.cacheDirectory.appending("/\(path)")) {
                                let sandBoxAsset = SandBoxAsset(assetURL: url, assetType: .image)
                                items.append(sandBoxAsset)
                            }
                        }
                    } else {
                        continue
                    }
                }
                DispatchQueue.main.sync {
                    complete(items)
                }
            } catch {
                assertionFailure("读取沙盒资源失败")
            }
        }
    }
}

extension SandBoxDataProvider: MediaDataProviderCacheable {
    static var cacheDirectory: String {
        get {
            return NSTemporaryDirectory() + Bundle.main.bundleIdentifier!
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
