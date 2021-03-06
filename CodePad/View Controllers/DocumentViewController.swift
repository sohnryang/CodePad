//
//  DocumentViewController.swift
//  CodePad
//
//  Created by Ryang Sohn on 2020/01/07.
//  Copyright © 2020 Ryang Sohn. All rights reserved.
//

import UIKit
import WebKit

class DocumentViewController: UIViewController, FontConfigurable {
    var document: CodePadDocument?
    var config: CodePadConfiguration!
    var webView: WKWebView!
    var editorReady = false

    fileprivate func prepareWebView() {
        let conf = WKWebViewConfiguration()
        conf.userContentController.add(self, name: "editorMessageHandler")
        webView = WKWebView(frame: .zero, configuration: conf)
        webView.scrollView.isScrollEnabled = false
        view.addSubview(webView)
        let layoutGuide = view.safeAreaLayoutGuide
        webView.translatesAutoresizingMaskIntoConstraints = false
        webView.leadingAnchor.constraint(equalTo: layoutGuide.leadingAnchor).isActive = true
        webView.trailingAnchor.constraint(equalTo: layoutGuide.trailingAnchor).isActive = true
        webView.topAnchor.constraint(equalTo: layoutGuide.topAnchor).isActive = true
        webView.bottomAnchor.constraint(equalTo: layoutGuide.bottomAnchor).isActive = true
        let url = Bundle.main.url(forResource: "TextEditor", withExtension: "html")!
        webView.loadFileURL(url, allowingReadAccessTo: url)
        webView.scrollView.delegate = self
    }
    
    fileprivate func loadSettings() {
        config = CodePadConfiguration()
    }
    
    fileprivate func setNavbar() {
        self.title = document?.fileURL.lastPathComponent
    }
    
    @IBAction func commandPalleteButtonTapped(_ sender: Any) {
        #if targetEnvironment(simulator)
        print("Command Palette Button Tapped")
        #endif
        self.webView.evaluateJavaScript("editor.execCommand(editor.commands.byName.openCommandPallete);") { (result, error) in
            if error != nil {
                #if targetEnvironment(simulator)
                print("Failed to open command pallete")
                #endif
            }
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        FontProvider.shared.register(observer: self)
        prepareWebView()
        loadSettings()
        setNavbar()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        NotificationCenter.default.addObserver(self, selector: #selector(adjustForKeyboard), name: UIResponder.keyboardWillHideNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(adjustForKeyboard), name: UIResponder.keyboardWillShowNotification, object: nil)
    }
    
    @objc func adjustForKeyboard(notification: Notification) {
        #if targetEnvironment(simulator)
        print("Keyboard Change")
        #endif
        
        guard let keyboardValue = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue else { return }
        
        #if targetEnvironment(simulator)
        print(keyboardValue)
        #endif
        
        let keyboardScreenEndFrame = keyboardValue.cgRectValue
        let keyboardViewEndFrame = view.convert(keyboardScreenEndFrame, from: view.window)
        #if targetEnvironment(simulator)
        print("keyboardViewEndFrame = \(keyboardViewEndFrame)")
        #endif
        
        if notification.name == UIResponder.keyboardWillHideNotification {
            self.webView.evaluateJavaScript("document.body.style.height = '\(webView.frame.height)px';editor.resize(true);") { (result, error) in
                if error != nil {
                    #if targetEnvironment(simulator)
                    print("Failed to resize editor")
                    debugPrint(error!)
                    #endif
                }
            }
        } else {
            self.webView.evaluateJavaScript("document.body.style.height = '\(webView.frame.height -  keyboardViewEndFrame.height + view.safeAreaInsets.bottom)px';editor.resize(true);") { (result, error) in
                if error != nil {
                    #if targetEnvironment(simulator)
                    print("Failed to resize editor")
                    debugPrint(error!)
                    #endif
                }
            }
        }
    }
    
    fileprivate func initializeEditor() {
        let filename = self.document!.fileURL.lastPathComponent
        self.webView.evaluateJavaScript("initializeEditor('\(config.colorScheme)', '\(filename)', `\(document!.code.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "`", with: "\\`"))`, \(config.indentationSize), \(config.indentationType.ordinal()), '\(config.keybindingType.rawValue)', '\(config.fontFamilyName)', \(config.fontSize))") { (result, error) in
            if error != nil {
                #if targetEnvironment(simulator)
                print("Failed to initialize editor")
                debugPrint(error!)
                #endif
            }
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        NotificationCenter.default.removeObserver(self)
    }
    
    func scrollViewWillBeginZooming(_ scrollView: UIScrollView, with view: UIView?) {
        scrollView.pinchGestureRecognizer?.isEnabled = false
    }
    
    func apply(font: UIFont) {
        #if targetEnvironment(simulator)
        print("Applying font: \(font.familyName)")
        #endif
        self.navigationController?.navigationBar.titleTextAttributes = [NSAttributedString.Key.font: UIFont(name: font.fontName, size: 17)!]
        guard editorReady else { return }
        self.webView.evaluateJavaScript("updateFont('\(font.familyName)');") { (result, error) in
            if error != nil {
                fatalError("Could not apply font to editor")
            }
        }
    }
}

extension DocumentViewController: UIScrollViewDelegate {
    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        return nil
    }
}

extension DocumentViewController: WKUIDelegate {
    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        let conf = WKWebViewConfiguration()
        conf.userContentController.add(self, name: "editorMessageHandler")
        return WKWebView(frame: webView.frame, configuration: conf)
    }
}

extension DocumentViewController: WKScriptMessageHandler {
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        if message.name == "editorMessageHandler" {
            guard let dict = message.body as? [String: AnyObject],
                let event = dict["event"] as? String,
                let data = dict["data"] as? [String: AnyObject] else {
                    fatalError("Cannot read message handler data")
            }
            switch event {
            case "editor_ready":
                self.document!.open(completionHandler: { (success) in
                    guard success else {
                        fatalError("Failed to open file")
                    }
                    #if targetEnvironment(simulator)
                    print("File opened")
                    print("Current content: \(self.document!.code)")
                    #endif
                    self.initializeEditor()
                })
                editorReady = true
            case "text_change":
                let fileContents: String = data["fileContent"] as! String
                self.document!.code = fileContents
                #if targetEnvironment(simulator)
                print("Writing to file...")
                #endif
                self.document!.save(to: document!.fileURL, for: .forOverwriting, completionHandler: nil)
            case "configure":
                performSegue(withIdentifier: "Configure", sender: nil)
            default:
                #if targetEnvironment(simulator)
                print("Unknown event: \(event)")
                #endif
            }
        }
    }
}
