import UIKit
import WebKit
import LocalAuthentication

class ViewController: UIViewController, WKNavigationDelegate, WKUIDelegate {

    var webView: WKWebView!
    var lockScreen: UIView!
    var isAuthenticated = false
    let appURL = "https://billbuddy.us"

    // MARK: - View Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor(red: 0.10, green: 0.10, blue: 0.18, alpha: 1.0)
        setupWebView()
        setupLockScreen()
        authenticateUser()

        NotificationCenter.default.addObserver(
            self, selector: #selector(appDidBecomeActive),
            name: UIApplication.didBecomeActiveNotification, object: nil
        )
    }

    override var preferredStatusBarStyle: UIStatusBarStyle { .lightContent }

    // MARK: - WebView Setup

    func setupWebView() {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true

        webView = WKWebView(frame: view.bounds, configuration: config)
        webView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        webView.navigationDelegate = self
        webView.uiDelegate = self
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        webView.isOpaque = false
        webView.backgroundColor = UIColor(red: 0.10, green: 0.10, blue: 0.18, alpha: 1.0)
        webView.scrollView.backgroundColor = UIColor(red: 0.10, green: 0.10, blue: 0.18, alpha: 1.0)

        // Allow swipe back/forward navigation
        webView.allowsBackForwardNavigationGestures = true

        view.addSubview(webView)

        // Load the app
        if let url = URL(string: appURL) {
            webView.load(URLRequest(url: url))
        }
    }

    // MARK: - Lock Screen (shown before Face ID)

    func setupLockScreen() {
        lockScreen = UIView(frame: view.bounds)
        lockScreen.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        lockScreen.backgroundColor = UIColor(red: 0.10, green: 0.10, blue: 0.18, alpha: 1.0)

        // App icon
        let iconSize: CGFloat = 80
        let icon = UIView(frame: CGRect(x: 0, y: 0, width: iconSize, height: iconSize))
        icon.backgroundColor = UIColor(red: 0.42, green: 0.36, blue: 0.91, alpha: 1.0) // #6C5CE7
        icon.layer.cornerRadius = 20
        icon.center = CGPoint(x: view.center.x, y: view.center.y - 60)
        icon.autoresizingMask = [.flexibleLeftMargin, .flexibleRightMargin, .flexibleTopMargin, .flexibleBottomMargin]

        let emoji = UILabel(frame: icon.bounds)
        emoji.text = "\u{1F4B8}"
        emoji.font = UIFont.systemFont(ofSize: 40)
        emoji.textAlignment = .center
        icon.addSubview(emoji)
        lockScreen.addSubview(icon)

        // App name
        let label = UILabel()
        label.text = "BillBuddy"
        label.font = UIFont.systemFont(ofSize: 28, weight: .bold)
        label.textColor = .white
        label.textAlignment = .center
        label.frame = CGRect(x: 0, y: icon.frame.maxY + 16, width: view.bounds.width, height: 40)
        label.autoresizingMask = [.flexibleWidth, .flexibleTopMargin, .flexibleBottomMargin]
        lockScreen.addSubview(label)

        // Unlock button
        let unlockBtn = UIButton(type: .system)
        unlockBtn.setTitle("Unlock with Face ID", for: .normal)
        unlockBtn.titleLabel?.font = UIFont.systemFont(ofSize: 16, weight: .semibold)
        unlockBtn.setTitleColor(.white, for: .normal)
        unlockBtn.backgroundColor = UIColor(red: 0.42, green: 0.36, blue: 0.91, alpha: 1.0)
        unlockBtn.layer.cornerRadius = 12
        unlockBtn.frame = CGRect(x: 40, y: label.frame.maxY + 40, width: view.bounds.width - 80, height: 50)
        unlockBtn.autoresizingMask = [.flexibleWidth, .flexibleTopMargin, .flexibleBottomMargin]
        unlockBtn.addTarget(self, action: #selector(authenticateUser), for: .touchUpInside)
        lockScreen.addSubview(unlockBtn)

        view.addSubview(lockScreen)
    }

    // MARK: - Face ID / Touch ID Authentication

    @objc func authenticateUser() {
        let context = LAContext()
        var error: NSError?

        if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
            context.evaluatePolicy(
                .deviceOwnerAuthenticationWithBiometrics,
                localizedReason: "Unlock BillBuddy to access your finances"
            ) { success, error in
                DispatchQueue.main.async {
                    if success {
                        self.unlockApp()
                    }
                }
            }
        } else {
            // No biometrics available — fall back to passcode
            context.evaluatePolicy(
                .deviceOwnerAuthentication,
                localizedReason: "Unlock BillBuddy to access your finances"
            ) { success, error in
                DispatchQueue.main.async {
                    if success {
                        self.unlockApp()
                    }
                }
            }
        }
    }

    func unlockApp() {
        isAuthenticated = true
        UIView.animate(withDuration: 0.3) {
            self.lockScreen.alpha = 0
        } completion: { _ in
            self.lockScreen.isHidden = true
        }
    }

    // MARK: - Re-lock on App Resume

    @objc func appDidBecomeActive() {
        // Re-authenticate when app comes back from background
        if !isAuthenticated { return }
        lockScreen.isHidden = false
        lockScreen.alpha = 1
        isAuthenticated = false
        authenticateUser()
    }

    // MARK: - WKWebView Navigation

    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction,
                 decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        if let url = navigationAction.request.url {
            // Open external links in Safari
            if url.host != nil && !url.absoluteString.contains("billbuddy.us")
                && !url.absoluteString.contains("accounts.google.com")
                && !url.absoluteString.contains("googleapis.com") {
                UIApplication.shared.open(url)
                decisionHandler(.cancel)
                return
            }
        }
        decisionHandler(.allow)
    }

    // Handle new window requests (Google OAuth popups)
    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration,
                 for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        webView.load(navigationAction.request)
        return nil
    }
}

