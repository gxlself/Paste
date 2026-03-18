//
//  PolicyView.swift
//  Paste-iOS
//

import SwiftUI

enum iOSPolicyDocument: String, Identifiable {
    case privacyPolicy
    case termsOfUse

    var id: String { rawValue }

    var title: String {
        switch self {
        case .privacyPolicy: return String(localized: "about.privacyPolicy")
        case .termsOfUse: return String(localized: "about.termsOfUse")
        }
    }

    var content: String {
        let isEnglish: Bool = {
            let preferred = Bundle.main.preferredLocalizations.first?.lowercased() ?? ""
            if preferred.hasPrefix("en") { return true }
            if preferred.hasPrefix("zh") { return false }
            return Locale.current.language.languageCode?.identifier.lowercased() == "en"
        }()

        switch self {
        case .privacyPolicy:
            return isEnglish ? iOSPolicyContent.privacyPolicy_en : iOSPolicyContent.privacyPolicy_zhHans
        case .termsOfUse:
            return isEnglish ? iOSPolicyContent.termsOfUse_en : iOSPolicyContent.termsOfUse_zhHans
        }
    }
}

struct PolicyView: View {

    let document: iOSPolicyDocument

    var body: some View {
        ScrollView {
            Text(document.content)
                .font(.subheadline)
                .foregroundStyle(Color(UIColor.label))
                .padding()
                .textSelection(.enabled)
        }
        .navigationTitle(document.title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Policy content (matching Mac version)

enum iOSPolicyContent {

    static let privacyPolicy_zhHans = """
隐私政策（Privacy Policy）

生效日期：2026-01-26
应用名称：Paste
开发者/运营方：Gxlself（以下简称"我们"）
联系邮箱：gxlself@gmail.com

1. 我们收集哪些信息
为实现产品功能并保障稳定性，我们可能收集与处理以下信息：

- 你主动提供的信息：当你通过邮件等方式联系我们时，你提交的内容（例如问题描述、截图、可选的日志与诊断信息、联系方式）。
- 剪贴板相关信息（用于核心功能）：当你使用 Paste 的剪贴板管理/历史/搜索等功能时，应用会在你的设备上读取并处理剪贴板内容；如你启用"云同步"，相关数据可能会被同步到云端以在你的设备间保持一致。
- 订阅与购买信息（由购买渠道处理）：你进行订阅购买时，交易由应用分发平台（如 App Store）处理。我们通常无法获取你的完整支付信息（如银行卡号），但可能会接收用于解锁权益的购买结果/订阅状态。

说明：Paste 不进行用户行为统计，也不进行崩溃/诊断上报（以当前版本与实际配置为准）。

2. 我们如何使用信息
- 提供与维护功能：实现剪贴板管理、历史记录、搜索、跨设备同步等。
- 用户支持：回应你的咨询与问题处理（仅在你联系并提供信息时使用）。
- 安全与合规：满足法律法规要求、处理滥用与安全风险。

3. 云同步与数据存储
- 本地存储：Paste 可能在你的设备本地保存剪贴板历史、配置与缓存数据（存储位置受系统沙盒机制保护）。
- 云端存储（你启用云同步时）：为实现跨设备同步，你选择同步的数据会被上传并存储在云端，并在你的设备间同步。

4. 我们如何共享、转让与披露信息
我们不会出售你的个人信息。除以下情况外，我们不会与第三方共享你的数据：
- 经你明确同意；
- 为实现云同步所必需；
- 法律法规要求。

5. 你的权利与选择
你可以：
- 删除数据：在应用内清理剪贴板历史。
- 关闭云同步：在应用设置中关闭同步。
- 联系我们：通过 gxlself@gmail.com 提出隐私相关问题与请求。

6. 儿童隐私
Paste 不面向未成年人提供服务。

7. 本政策的更新
我们可能适时更新本政策。若发生重大变更，我们会通过应用内提示通知。
"""

    static let termsOfUse_zhHans = """
使用条款（Terms of Use）

生效日期：2026-01-26
应用名称：Paste
开发者/运营方：Gxlself
联系邮箱：gxlself@gmail.com

1. 接受条款
你下载、安装、访问或使用 Paste，即表示你已阅读并同意本使用条款及《隐私政策》。如不同意，请停止使用并卸载。

2. 服务内容与许可
- Paste 提供剪贴板管理、历史记录、搜索与（可选）云同步等功能。
- 我们授予你一项个人、非排他、不可转让、可撤销的许可，用于在你拥有或控制的设备上使用本应用。

3. 用户义务与禁止行为
你承诺不会：
- 将 Paste 用于任何违法用途；
- 逆向工程、反编译、破解应用；
- 干扰、破坏应用或相关系统的正常运行。

4. 免责声明
Paste 按"现状"提供，我们不保证完全无错误、不间断或满足你的特定需求。

5. 联系我们
如有任何问题，请联系：gxlself@gmail.com
"""

    static let privacyPolicy_en = """
Privacy Policy

Effective Date: 2026-01-26
App Name: Paste
Developer/Operator: Gxlself ("we", "us")
Contact Email: gxlself@gmail.com

1. Information We Collect
To provide and improve the app, we may collect and process:

- Information you provide: content you send when contacting us by email.
- Clipboard-related information (core functionality): when you use clipboard management/history/search, the app reads and processes your clipboard content on your device. If you enable "Cloud Sync", data may be uploaded to the cloud.
- Subscription and purchase information (handled by the platform): purchases are processed by the App Store.

Note: Paste does not perform user analytics tracking and does not upload crash/diagnostic reports.

2. How We Use Information
- Provide and maintain features: clipboard management, history, search, cross-device sync.
- Customer support: respond to your requests.
- Security and compliance: comply with applicable laws.

3. Cloud Sync and Data Storage
- Local storage: protected by system sandboxing.
- Cloud storage (when enabled): data is synchronized across your devices.

4. Sharing, Transfer, and Disclosure
We do not sell your personal information.

5. Your Choices
You can: delete data in-app, disable Cloud Sync, or contact gxlself@gmail.com.

6. Children's Privacy
Paste is not intended for children.

7. Updates to This Policy
We may update this policy from time to time.
"""

    static let termsOfUse_en = """
Terms of Use

Effective Date: 2026-01-26
App Name: Paste
Developer/Operator: Gxlself
Contact Email: gxlself@gmail.com

1. Acceptance of Terms
By downloading, installing, or using Paste, you agree to these Terms of Use and the Privacy Policy.

2. Service and License
Paste provides clipboard management, history, search, and optional cloud sync. We grant you a personal, non-exclusive, non-transferable, revocable license to use the app.

3. User Obligations
You agree not to use the app for unlawful purposes, reverse engineer it, or interfere with its operation.

4. Disclaimer
The app is provided "as is" without warranties.

5. Contact
If you have questions, contact: gxlself@gmail.com
"""
}
