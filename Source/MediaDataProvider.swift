//
//  MEditableProvider.swift
//  Muse
//
//  Created by clee on 16/10/10.
//  Copyright © 2016年 PG. All rights reserved.
//

import UIKit
import Foundation
import Photos
import CoreLocation

public enum MediaDataSourceType {
    case system
    case sandbox
    case instagram
    case facebook
}

public enum AuthorizeResult {
    case success
    case fail
}

public enum AssetMediaType {
    case unknow
    case image
    case livePhoto
    case video
}

public protocol MediaDataProviderCompatible {

    /// 用于授权
    ///
    /// - parameter complete: 授权完成回调
    ///
    /// - returns:
    func authorize(complete: @escaping (_ status: AuthorizeResult) -> Void)


    /// 获取多媒体数据
    ///
    /// - parameter withType: 多媒体类型
    /// - parameter complete: 获取数据完成回调
    func fetchMedia(_ withType: AssetMediaType, _ minDuration: Double, _ complete: @escaping (_ result: [MediaAsset]) -> Void) 
}

public protocol NetworkMediaDataProviderCompatible: MediaDataProviderCompatible {

    /// 接口地址
    var baseURL: String {get}
    /// 获取授权接口
    var authorizePath: String {get}
    /// 获取token接口
    var accessTokenPath: String {get}
    /// 获取资源列表接口
    var fetchMediaPath: String {get}
    /// clientID
    var clientId: String {get set}
    /// clientSecret
    var clientSecret: String {get set}
    /// scopes
    var scopes:[String] {get set}
    /// 重定向URL
    var redirectURL: String {get set}

}

/// 资源缓存管理协议
protocol MediaDataProviderCacheable {
    /// 获取资源缓存的目录
    static var cacheDirectory: String {get}

    /// 缓存数据
    ///
    /// - parameter data: 图片或者视频数据
    /// - parameter url:  缓存资源的唯一标识
    static func cache(data: Data, url: String)

    /// 清空缓存
    static func clearCache()
}

/// 支持资源显示到控件的协议
public protocol MediaDisplayable {
    func display(_ forImageView: UIImageView)
}

/// 资源协议
public protocol MediaAsset: MediaDisplayable {

    var assetType: AssetMediaType {get}

    var assetURL: URL? {get set}
    
    var assetIdentifier: String {get set}

    var thumbnailURL: URL? {get set}

    var timeDuration: Double {get}

    var coordinate: CLLocationCoordinate2D? {get}

    func fetchThumbnail(_ completed: @escaping (_ thumbnail: UIImage?) -> Void)

    func fetchAVAsset(_ completed: @escaping (_ avAsset: AVAsset?) -> Void)
}

//public func ==(lhs: Self, rhs: Self) -> Bool {
//    return lhs.assetURL == rhs.assetURL
//}
