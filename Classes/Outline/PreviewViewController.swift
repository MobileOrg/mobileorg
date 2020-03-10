//
//  PreviewViewController.swift
//  MobileOrg
//
//  Created by Artem Loenko on 10/03/2020.
//  Copyright © 2020 Sean Escriva. All rights reserved.
//

import UIKit
import WebKit

final class PreviewViewController: UIViewController {

    private let node: Node
    private var positionToScroll: Int?
    private lazy var nodeContent: Node = {
        guard self.node.isLink(), let content = NodeWithFilename(self.node.linkFile()) else { return self.node }
        return content
    }()
    private lazy var webView: WKWebView = { [weak self] in
        let configuration = WKWebViewConfiguration()
        configuration.dataDetectorTypes = []

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.translatesAutoresizingMaskIntoConstraints = false
        webView.navigationDelegate = self
        return webView
    }()

    @objc
    init(with node: Node) {
        self.node = node
        super.init(nibName: nil, bundle: nil)
    }

    @objc
    init(with node: Node, positionToScroll: Int) {
        self.node = node
        self.positionToScroll = positionToScroll
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        self.view.addSubview(self.webView)
        NSLayoutConstraint.activate([
            self.webView.leadingAnchor.constraint(equalTo: self.view.safeAreaLayoutGuide.leadingAnchor),
            self.webView.topAnchor.constraint(equalTo: self.view.safeAreaLayoutGuide.topAnchor),
            self.webView.trailingAnchor.constraint(equalTo: self.view.safeAreaLayoutGuide.trailingAnchor),
            self.webView.bottomAnchor.constraint(equalTo: self.view.safeAreaLayoutGuide.bottomAnchor)
        ])
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        if let index = self.navigationController?.viewControllers.firstIndex(of: self) {
            SessionManager.instance()?.popOutlineState(toLevel: Int32(index))
        }

        self.title = self.node.headingForDisplay()
        self.webView.loadHTMLString(self.nodeContent.html(forDocumentViewLevel: 0), baseURL: URL(fileURLWithPath: Bundle.main.bundlePath))
    }

    func pushOrgFile(with filename: String) {
        guard let nextNode = NodeWithFilename(filename) else { return }
        SessionManager.instance()?.pushOutlineState({
            let state = OutlineState()
            state.selectedLink = filename
            state.selectionType = OutlineSelectionTypeDocumentView
            return state
        }())
        let controller = PreviewViewController(with: nextNode)
        self.navigationController?.pushViewController(controller, animated: true)
    }

}

extension PreviewViewController: WKNavigationDelegate {

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        guard let positionToScroll = self.positionToScroll else { return }
        webView.evaluateJavaScript("window.scrollTo(0, \(positionToScroll);", completionHandler: nil)
        self.positionToScroll = nil
    }

    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        guard let url = navigationAction.request.url else {
            decisionHandler(.cancel)
            return
        }

        switch url.host {
        case "orgfile":
            guard let resolvedLink = self.node.resolveLink((url as NSURL).resourceSpecifier) else { return }
            self.pushOrgFile(with: resolvedLink)
            decisionHandler(.cancel)
            return
        case nil:
            decisionHandler(.allow)
            return
        default:
            UIApplication.shared.open(url, options: [:], completionHandler: nil)
            decisionHandler(.cancel)
            return
        }
    }

}
