import SwiftUI
import WebKit

/// Hosts the bundled `podrida-score.html` and supplies the native pieces it expects:
/// a persistent `window.storage` API and safe-area aware layout.
struct ScoreWebView: UIViewRepresentable {
    let pageState: PageState

    func makeCoordinator() -> Coordinator {
        Coordinator(pageState: pageState)
    }

    func makeUIView(context: Context) -> WKWebView {
        let content = WKUserContentController()
        content.addScriptMessageHandler(context.coordinator, contentWorld: .page, name: "storage")
        content.add(context.coordinator, name: "page")
        content.addUserScript(WKUserScript(source: Scripts.storageShim, injectionTime: .atDocumentStart, forMainFrameOnly: true))
        content.addUserScript(WKUserScript(source: Scripts.nativeChrome, injectionTime: .atDocumentEnd, forMainFrameOnly: true))

        let config = WKWebViewConfiguration()
        config.userContentController = content

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.isOpaque = false
        webView.backgroundColor = UIColor(named: "LaunchBackground")
        webView.allowsLinkPreview = false
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        #if DEBUG
        webView.isInspectable = true
        #endif

        if let url = Bundle.main.url(forResource: "podrida-score", withExtension: "html") {
            webView.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
        }
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {}

    @MainActor
    final class Coordinator: NSObject, WKScriptMessageHandlerWithReply, WKScriptMessageHandler {
        private let pageState: PageState
        private let defaults = UserDefaults.standard
        private let keyPrefix = "webstorage."

        init(pageState: PageState) {
            self.pageState = pageState
        }

        /// Backs `window.storage.get/set/delete` with UserDefaults so a game survives app restarts.
        func userContentController(
            _ userContentController: WKUserContentController,
            didReceive message: WKScriptMessage,
            replyHandler: @escaping @MainActor @Sendable (Any?, String?) -> Void
        ) {
            guard let body = message.body as? [String: Any],
                  let op = body["op"] as? String,
                  let key = body["key"] as? String else {
                replyHandler(nil, "Storage request needs an op and a key")
                return
            }
            let storageKey = keyPrefix + key
            switch op {
            case "get":
                replyHandler(defaults.string(forKey: storageKey), nil)
            case "set":
                guard let value = body["value"] as? String else {
                    replyHandler(nil, "Storage value must be a string")
                    return
                }
                defaults.set(value, forKey: storageKey)
                replyHandler(nil, nil)
            case "delete":
                defaults.removeObject(forKey: storageKey)
                replyHandler(nil, nil)
            default:
                replyHandler(nil, "Unknown storage operation: \(op)")
            }
        }

        /// Receives which screen is showing.
        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            guard let raw = message.body as? String, let page = ScorePage(rawValue: raw) else { return }
            pageState.page = page
        }
    }
}

private enum Scripts {
    /// The web app persists through an async `window.storage` host API; provide it natively.
    static let storageShim = """
    (function () {
      var handlers = window.webkit && window.webkit.messageHandlers;
      if (!handlers || !handlers.storage) return;
      function call(message) { return handlers.storage.postMessage(message); }
      window.storage = {
        get: function (key) {
          return call({ op: 'get', key: key }).then(function (value) {
            return value == null ? null : { key: key, value: value };
          });
        },
        set: function (key, value) {
          return call({ op: 'set', key: key, value: String(value) }).then(function () {
            return { key: key, value: value };
          });
        },
        delete: function (key) {
          return call({ op: 'delete', key: key }).then(function () {
            return { key: key, deleted: true };
          });
        }
      };
    })();
    """

    /// Edge-to-edge layout that respects the notch and home indicator, no zoom-on-focus,
    /// and a report of the current screen so the status bar can match it.
    static let nativeChrome = """
    (function () {
      var viewport = document.querySelector('meta[name="viewport"]');
      if (viewport) {
        viewport.setAttribute('content', 'width=device-width, initial-scale=1, maximum-scale=1, viewport-fit=cover');
      }

      var style = document.createElement('style');
      style.textContent = [
        'html { -webkit-text-size-adjust: 100%; }',
        'html, body { background: var(--desk); -webkit-tap-highlight-color: transparent; }',
        'body:has(.ledger-page) { background: var(--ledger-bg); }',
        '.setup-page {',
        '  padding: calc(56px + env(safe-area-inset-top)) calc(16px + env(safe-area-inset-right))',
        '           calc(56px + env(safe-area-inset-bottom)) calc(16px + env(safe-area-inset-left));',
        '}',
        // The ledger fills the screen exactly: header and buttons stay put, only the table scrolls.
        '.ledger-page {',
        '  display: flex; flex-direction: column; height: 100vh; min-height: 0;',
        '  padding: env(safe-area-inset-top) env(safe-area-inset-right)',
        '           env(safe-area-inset-bottom) env(safe-area-inset-left);',
        '}',
        '.table-scroll { flex: 1 1 auto; min-height: 0; max-height: none; }'
      ].join('\\n');
      document.head.appendChild(style);

      var app = document.getElementById('app');
      var handlers = window.webkit && window.webkit.messageHandlers;
      if (!app || !handlers || !handlers.page) return;
      var last = null;
      function report() {
        var page = app.querySelector('.ledger-page') ? 'ledger' : 'setup';
        if (page === last) return;
        last = page;
        // A scroll offset left over from the other screen would push content under the status bar.
        window.scrollTo(0, 0);
        handlers.page.postMessage(page);
      }
      new MutationObserver(report).observe(app, { childList: true });
      report();
    })();
    """
}
