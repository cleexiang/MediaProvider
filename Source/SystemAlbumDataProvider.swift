//
//  SystemAlbumDataProvider.swift
//  Muse
//
//  Created by clee on 16/10/13.
//  Copyright © 2016年 PG. All rights reserved.
//
import Photos

/// PHAsset扩展
extension PHAsset: MediaAsset {
    public var assetType: AssetMediaType {
        get {
            switch self.mediaType {
            case .image:
                return AssetMediaType.image
            case .video:
                return AssetMediaType.video
            default:
                return AssetMediaType.unknow
            }
        }
    }
    
    public var assetIdentifier: String {
        get {
            return self.localIdentifier
        }
        set {}
    }

    public var assetURL: URL? {
        get {
            return nil
        }
        set {}
    }

    public var thumbnailURL: URL? {
        get {
            return nil
        }
        set {}
    }


    public var timeDuration: Double {
        get {
            return self.duration
        }
    }

    public var coordinate: CLLocationCoordinate2D? {
        return (self.location?.coordinate)!
    }

    public func fetchThumbnail(_ completed: @escaping (UIImage?) -> Void) {
        completed(nil)
    }

    public func fetchAVAsset(_ completed: @escaping (_ avAsset: AVAsset?) -> Void) {
        if self.assetType == .video {
            PHImageManager.default().requestAVAsset(forVideo: self, options: nil) { (avAsset, audioMix, dic) in
                DispatchQueue.main.async {
                    completed(avAsset)
                }
            }
        } else {
            completed(nil)
        }
        //TODO: @lx处理图片的情况 
    }

    public func display(_ forImageView: UIImageView) {
        let options = PHImageRequestOptions()
        options.deliveryMode = .opportunistic
        options.resizeMode = .exact
        PHImageManager.default().requestImage(for: self, targetSize: CGSize(width: 200, height: 200), contentMode: .aspectFill, options: options) {
            (image, anyObj) in
            DispatchQueue.main.async(execute: {
                forImageView.image = image
            })
        }
    }
}

public class SystemAlbumDataProvider:NSObject, MediaDataProviderCompatible {

    public func authorize(complete: @escaping (_ status: AuthorizeResult) -> Void) {
        PHPhotoLibrary.requestAuthorization { (systemStatus) in
            switch systemStatus {
            case .denied, .notDetermined, .restricted:
                complete(.fail)
            case .authorized:
                complete(.success)
            }
        }
    }

    public func fetchMedia(_ withType: AssetMediaType, _ minDuration: Double = 0, _ complete: @escaping (_ result: [MediaAsset]) -> Void) {
        var items = [MediaAsset]()
        var mediaType = PHAssetMediaType.image
        switch withType {
        case .image:
            mediaType = PHAssetMediaType.image
        case .video:
            mediaType = PHAssetMediaType.video
        default:
            mediaType = PHAssetMediaType.unknown
        }

        let result = PHAsset.fetchAssets(with: mediaType, options: nil)

        result.enumerateObjects({ (obj, idx, stop) in
            let phAsset = obj
            if F_GREATER_OR_EQUAL_THAN(CGFloat(phAsset.duration), CGFloat(minDuration)) {
                items.append(phAsset)
            }
        })
        complete(items)
    }

    func clearCache() {

    }
}
