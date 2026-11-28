import Observation
import StoreKit
import SwiftUI

@MainActor
@Observable final class StudyPurchases {
    static let productID = "com.xxm666.alef.full"

    private(set) var ownsFullEdition = false
    private(set) var product: Product?
    private(set) var isBusy = false
    private(set) var message: String?
    private var entitlementRefresh = 0
    private var hasResolvedEntitlements = false

    var hasFullAccess: Bool { !StudyDistribution.isAppStore || ownsFullEdition }
    var isReady: Bool { !StudyDistribution.isAppStore || hasResolvedEntitlements }

    func refreshEntitlements() async {
        guard StudyDistribution.isAppStore else { return }
        entitlementRefresh += 1
        let refresh = entitlementRefresh
        var ownsEdition = false
        for await result in StoreKit.Transaction.currentEntitlements {
            if let transaction = verifiedEdition(from: result), transaction.revocationDate == nil {
                ownsEdition = true
                break
            }
        }
        if refresh == entitlementRefresh && !Task.isCancelled {
            ownsFullEdition = ownsEdition
            hasResolvedEntitlements = true
        }
    }

    func listenForUpdates() async {
        guard StudyDistribution.isAppStore else { return }
        for await result in StoreKit.Transaction.updates {
            guard !Task.isCancelled, let transaction = verifiedEdition(from: result) else { continue }
            await refreshEntitlements()
            await transaction.finish()
            if ownsFullEdition { message = nil }
        }
    }

    func loadProduct() async {
        guard StudyDistribution.isAppStore, !hasFullAccess, product == nil, !isBusy else { return }
        isBusy = true
        message = nil
        defer { isBusy = false }
        do {
            product = try await Product.products(for: [Self.productID]).first {
                $0.id == Self.productID && $0.type == .nonConsumable
            }
            if product == nil { message = "暂时无法取得 App Store 价格，请稍后重试。" }
        } catch {
            guard !Task.isCancelled else { return }
            message = "暂时无法联系 App Store，请检查网络后重试。"
        }
    }

    func purchase() async {
        guard StudyDistribution.isAppStore, !hasFullAccess, !isBusy, let product else { return }
        isBusy = true
        message = nil
        defer { isBusy = false }
        do {
            switch try await product.purchase() {
            case .success(let result):
                guard let transaction = verifiedEdition(from: result) else {
                    message = "无法验证购买。请稍后尝试恢复购买。"
                    return
                }
                entitlementRefresh += 1
                ownsFullEdition = transaction.revocationDate == nil
                hasResolvedEntitlements = true
                await transaction.finish()
            case .pending:
                message = "购买正在等待付款或批准。完成后会自动解锁。"
            case .userCancelled:
                break
            @unknown default:
                message = "App Store 尚未确认购买。请稍后尝试恢复购买。"
            }
        } catch {
            guard !Task.isCancelled else { return }
            message = "购买未完成，请稍后重试。"
        }
    }

    func restore() async {
        guard StudyDistribution.isAppStore, !isBusy else { return }
        isBusy = true
        message = nil
        defer { isBusy = false }
        do {
            try await AppStore.sync()
            await refreshEntitlements()
            guard !Task.isCancelled else { return }
            message = ownsFullEdition ? "已恢复 Alef 完整版。" : "此 Apple 账号暂无 Alef 完整版的购买记录。"
        } catch {
            guard !Task.isCancelled else { return }
            message = "暂时无法恢复购买，请检查 Apple 账号和网络。"
        }
    }

    private func verifiedEdition(from result: VerificationResult<StoreKit.Transaction>) -> StoreKit.Transaction? {
        guard case .verified(let transaction) = result,
              transaction.productID == Self.productID,
              transaction.productType == .nonConsumable else { return nil }
        return transaction
    }
}

struct StudyFullEditionView: View {
    @Environment(StudyPurchases.self) private var purchases
    @Environment(StudyProgress.self) private var progress

    var body: some View {
        StudyPage {
            StudyCard(highlighted: true) {
                StudySectionTitle("Alef 完整版")
                Text("一次购买，解锁全部主题词包、分级阅读、情景剧场与易混音辨析。解锁后可离线使用这些课程。")
                    .font(.subheadline)
                if purchases.hasFullAccess {
                    StudyNotice(title: "已解锁 Alef 完整版", symbol: "checkmark.seal.fill")
                } else if let product = purchases.product {
                    Button {
                        Task { await purchases.purchase() }
                    } label: {
                        Label("一次性解锁 · \(product.displayPrice)", systemImage: "lock.open")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(StudyButtonStyle(prominent: true))
                    .disabled(purchases.isBusy)
                } else if !purchases.isBusy {
                    Button("重新获取价格") { Task { await purchases.loadProduct() } }
                        .buttonStyle(StudyButtonStyle())
                }
                if purchases.isBusy { ProgressView("正在联系 App Store…") }
                if let message = purchases.message {
                    Text(message).font(.subheadline).foregroundStyle(progress.theme.mutedInk)
                }
                Button("恢复购买") { Task { await purchases.restore() } }
                    .buttonStyle(StudyButtonStyle())
                    .disabled(purchases.isBusy)
            }
        }
        .studyDetail("Alef 完整版", showsTabBar: true)
        .task { await purchases.loadProduct() }
    }
}

struct StudyFullEditionLink: View {
    var body: some View {
        NavigationLink {
            StudyFullEditionView()
        } label: {
            Label("查看 Alef 完整版", systemImage: "lock.open")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(StudyButtonStyle(prominent: true))
    }
}
