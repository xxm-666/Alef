import Capacitor
import UIKit
import WebKit

private enum StudyTab: String, CaseIterable {
    case words, flashcards, grid, rules, settings

    var item: UITabBarItem {
        let title: String
        let symbol: String
        switch self {
        case .words: (title, symbol) = ("单词", "character.book.closed")
        case .flashcards: (title, symbol) = ("闪卡", "rectangle.on.rectangle")
        case .grid: (title, symbol) = ("字母", "textformat.abc")
        case .rules: (title, symbol) = ("规则", "book")
        case .settings: (title, symbol) = ("设置", "gearshape")
        }
        return UITabBarItem(title: title, image: UIImage(systemName: symbol), selectedImage: nil)
    }
}

private struct StudyAppearance {
    let background: UIColor
    let style: UIUserInterfaceStyle

    init?(message: Any) {
        guard let values = message as? [String: Any],
              let dark = values["dark"] as? Bool,
              let hex = values["background"] as? String,
              hex.first == "#", hex.utf8.count == 7,
              let rgb = UInt32(hex.dropFirst(), radix: 16) else { return nil }

        background = UIColor(
            red: CGFloat((rgb >> 16) & 0xff) / 255,
            green: CGFloat((rgb >> 8) & 0xff) / 255,
            blue: CGFloat(rgb & 0xff) / 255,
            alpha: 1
        )
        style = dark ? .dark : .light
    }
}

final class AlefTabBarController: UITabBarController, UITabBarControllerDelegate {
    private let studyController = AlefStudyController()
    private let studyTabs = StudyTab.allCases

    override var childForStatusBarStyle: UIViewController? { nil }

    override var preferredStatusBarStyle: UIStatusBarStyle {
        overrideUserInterfaceStyle == .dark ? .lightContent : .darkContent
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        overrideUserInterfaceStyle = .light
        view.backgroundColor = .systemBackground
        delegate = self
        viewControllers = studyTabs.map { tab in
            let controller = UIViewController()
            controller.tabBarItem = tab.item
            controller.view.backgroundColor = .systemBackground
            return controller
        }
        selectedIndex = studyTabs.firstIndex(of: .grid) ?? 0
        studyController.onAppearanceChange = { [weak self] appearance in
            guard let self else { return }
            self.overrideUserInterfaceStyle = appearance.style
            self.view.backgroundColor = appearance.background
            self.viewControllers?.forEach { $0.view.backgroundColor = appearance.background }
            self.studyController.webView?.underPageBackgroundColor = appearance.background
            self.setNeedsStatusBarAppearanceUpdate()
        }
        studyController.onViewChange = { [weak self] route in
            guard let self, let tab = StudyTab(rawValue: route == "detail" ? "grid" : route),
                  let index = self.studyTabs.firstIndex(of: tab) else { return }
            if self.selectedIndex != index {
                self.selectedIndex = index
                self.attachStudyView()
            }
        }
        attachStudyView()
    }

    func tabBarController(_ tabBarController: UITabBarController, didSelect viewController: UIViewController) {
        guard studyTabs.indices.contains(selectedIndex) else { return }
        attachStudyView()
        studyController.open(studyTabs[selectedIndex])
    }

    private func attachStudyView() {
        guard let container = selectedViewController, studyController.parent !== container else { return }
        if studyController.parent != nil {
            studyController.willMove(toParent: nil)
            studyController.view.removeFromSuperview()
            studyController.removeFromParent()
        }

        container.addChild(studyController)
        let studyView: UIView = studyController.view
        studyView.translatesAutoresizingMaskIntoConstraints = false
        container.view.addSubview(studyView)
        let area = container.view.safeAreaLayoutGuide
        NSLayoutConstraint.activate([
            studyView.topAnchor.constraint(equalTo: area.topAnchor),
            studyView.bottomAnchor.constraint(equalTo: area.bottomAnchor),
            studyView.leadingAnchor.constraint(equalTo: area.leadingAnchor),
            studyView.trailingAnchor.constraint(equalTo: area.trailingAnchor)
        ])
        studyController.didMove(toParent: container)
    }
}

private final class AlefStudyController: CAPBridgeViewController {
    var onViewChange: ((String) -> Void)?
    var onAppearanceChange: ((StudyAppearance) -> Void)?

    override func capacitorDidLoad() {
        super.capacitorDidLoad()
        bridge?.registerPluginInstance(AlefPronunciationPlugin())
        let controller = webView?.configuration.userContentController
        controller?.addUserScript(WKUserScript(
            source: "window.alefNativeTabs = true;",
            injectionTime: .atDocumentStart,
            forMainFrameOnly: true
        ))
        controller?.add(AlefScriptMessageHandler { [weak self] message in
            guard let route = message as? String else { return }
            self?.onViewChange?(route)
        }, name: "alefViewChanged")
        controller?.add(AlefScriptMessageHandler { [weak self] message in
            guard let appearance = StudyAppearance(message: message) else { return }
            self?.onAppearanceChange?(appearance)
        }, name: "alefThemeChanged")
    }

    func open(_ tab: StudyTab) {
        webView?.evaluateJavaScript(
            "window.dispatchEvent(new CustomEvent('alef-native-tab', { detail: '\(tab.rawValue)' }));"
        )
    }
}

private final class AlefScriptMessageHandler: NSObject, WKScriptMessageHandler {
    private let receive: (Any) -> Void

    init(_ receive: @escaping (Any) -> Void) {
        self.receive = receive
    }

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard message.frameInfo.isMainFrame else { return }
        receive(message.body)
    }
}
