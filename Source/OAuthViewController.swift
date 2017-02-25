//
//  CLOAuthViewController.swift
//  CLOAuth2ViewController
//
//  Created by clee on 16/1/26.
//  Copyright © 2016年 cleexiang. All rights reserved.
//

import UIKit
import WebKit

extension NSError {
    class func error(_ domain: String, code: Int, description: String) -> NSError {
        return NSError(domain: domain, code: code, userInfo: nil)
    }
}

public protocol OAuthViewControllerDelegate: class {

    func oauthSuccess(_ viewController: OAuthViewController, accessToken: String)
    func oauthFail(_ viewController: OAuthViewController, error: NSError?)
}

open class OAuthViewController: UIViewController, WKNavigationDelegate, URLSessionDelegate {

    var webView: WKWebView?

    let baseURL: String
    let authorizePath: String
    let accessTokenPath: String
    let clientId: String
    let clientSecret: String
    let scope: String
    var redirectUri: String?
    var code: String?
    var task: URLSessionDataTask?

    open weak var delegate: OAuthViewControllerDelegate?

    public init(baseURL: String, authorizePath: String = "/oauth/authorize", accessTokenPath: String = "/oauth/access_token",
                clientId: String, clientSecret: String, scopes: Array<String>, redirectUri: String) {
        self.baseURL = baseURL
        self.authorizePath = authorizePath
        self.accessTokenPath = accessTokenPath
        self.clientId = clientId
        self.clientSecret = clientSecret
        self.scope = scopes.joined(separator: ",")
        self.redirectUri = redirectUri.addingPercentEncoding(withAllowedCharacters: CharacterSet.urlHostAllowed)!

        super.init(nibName: nil, bundle: nil)
    }

    required public init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        self.webView?.removeObserver(self, forKeyPath: "loading")
        self.webView?.navigationDelegate = nil
    }

    override open func viewDidLoad() {
        super.viewDidLoad()

        self.navigationController?.navigationBar.tintColor = UIColor.black
        self.navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .cancel,
                                                                 target: self, action: #selector(OAuthViewController.cancelAction))

        self.webView = WKWebView(frame: self.view.bounds)
        self.webView?.navigationDelegate = self
        view.addSubview(webView!)

        var queryStr = self.baseURL + self.authorizePath + "?client_id=\(self.clientId)" + "&scope=\(scope)&response_type=code"

        if let redirectUri = self.redirectUri {
            queryStr = queryStr.appendingFormat("&redirect_uri=%@", redirectUri)
        }
        if let url: URL = URL(string: queryStr) {
            _ = self.webView?.load(URLRequest(url:url))
        }

        self.webView?.addObserver(self, forKeyPath: "loading", options: NSKeyValueObservingOptions.new, context: nil)
    }

    func cancelAction() {
        self.dismiss(animated: true, completion: nil)
    }

    override open func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        if keyPath?.compare("loading") == ComparisonResult.orderedSame {
            guard let change = change else {
                return
            }

            guard let value = change[NSKeyValueChangeKey.newKey] else {
                return
            }
            let isLoading = (value as AnyObject).boolValue!
            if !isLoading {
                if let code = self.code {
                    let headers = [
                        "Content-Type": "application/x-www-form-urlencoded",
                        "Accept": "application/json"
                    ]
                    let url = URL(string: self.baseURL + self.accessTokenPath)
                    var request = URLRequest(url: url!, cachePolicy: .useProtocolCachePolicy, timeoutInterval: 60.0)
                    request.allHTTPHeaderFields = headers
                    request.httpMethod = "POST"
                    var bodyString = "client_id=\(self.clientId)&client_secret=\(self.clientSecret)&code=\(code)&grant_type=authorization_code"
                    if let redirectUri = self.redirectUri {
                        bodyString = bodyString.appendingFormat("&redirect_uri=%@", redirectUri)
                    }
                    request.httpBody = bodyString.data(using: .utf8)
                    let session = URLSession(configuration: URLSessionConfiguration.default, delegate:self, delegateQueue:nil)
                    self.task = session.dataTask(with: request, completionHandler: { (data, response, error) in
                        if let error = error {
                            print(error)
                        }
                        guard let data = data else {
                            return
                        }
                        let result = String(data: data, encoding: String.Encoding.utf8)
                        do {
                            let json = try JSONSerialization.jsonObject(with: data, options: [.allowFragments]) as! Dictionary<String, AnyObject>
                            if let errorMsg = json["error"] as? String {
                                DispatchQueue.main.async {
                                    self.delegate?.oauthFail(self, error: NSError.error("", code: 0, description: errorMsg))
                                }
                            } else if let accessToken = json["access_token"] as? String {
                                DispatchQueue.main.async {
                                    self.delegate?.oauthSuccess(self, accessToken: accessToken)
                                }
                            }
                        } catch {
                            DispatchQueue.main.async {
                                self.delegate?.oauthFail(self, error: NSError.error("", code: 0, description: ""))
                            }
                        }


                        print(result)
                    })
                    self.task!.resume()
                }
            }
        }
    }

    open func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        print("%@", navigationAction.request.url!)

        if let urlString = navigationAction.request.url?.absoluteString {
            if urlString.contains("code=") {
                let comps = urlString.components(separatedBy: "code=")
                if comps.count == 2 {
                    self.code = comps.last
                }
            }
        }
        decisionHandler(.allow)
    }

    open func webView(_ webView: WKWebView, decidePolicyFor navigationResponse: WKNavigationResponse, decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void) {
        decisionHandler(.allow)
    }

    open func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        NSLog("")
    }
}
