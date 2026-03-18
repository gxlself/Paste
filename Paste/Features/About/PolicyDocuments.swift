//
//  PolicyDocuments.swift
//  Paste
//
//  Privacy Policy / Terms of Use documents (zh-Hans)
//

import Foundation

enum PolicyDocument: CaseIterable {
    case privacyPolicy
    case termsOfUse

    var windowTitle: String {
        switch self {
        case .privacyPolicy:
            return String(localized: "policy.window.privacy.title", defaultValue: "隐私政策")
        case .termsOfUse:
            return String(localized: "policy.window.terms.title", defaultValue: "使用条款")
        }
    }

    var content: String {
        switch self {
        case .privacyPolicy:
            return PolicyDocuments.localizedPrivacyPolicy
        case .termsOfUse:
            return PolicyDocuments.localizedTermsOfUse
        }
    }
}

enum PolicyDocuments {

    // 注意：这里是展示用正文；如你未来要做多语言/在线链接，可把内容迁移到资源文件或网站。

    static var localizedPrivacyPolicy: String {
        PolicyLocale.isEnglish ? privacyPolicy_en : privacyPolicy_zhHans
    }

    static var localizedTermsOfUse: String {
        PolicyLocale.isEnglish ? termsOfUse_en : termsOfUse_zhHans
    }

    private enum PolicyLocale {
        static var isEnglish: Bool {
            // 优先使用 Bundle 的本地化选择（与 SwiftUI Localizable 行为一致）
            let preferred = Bundle.main.preferredLocalizations.first?.lowercased() ?? ""
            if preferred.hasPrefix("en") { return true }
            if preferred.hasPrefix("zh") { return false }

            // 回退到当前系统语言
            let langCode = Locale.current.language.languageCode?.identifier.lowercased() ?? ""
            return langCode == "en"
        }
    }

    // MARK: - zh-Hans

    static let privacyPolicy_zhHans = #"""
隐私政策（Privacy Policy）

生效日期：2026-01-26
应用名称：Paste
开发者/运营方：Gxlself（以下简称“我们”）
联系邮箱：gxlself@gmail.com

1. 我们收集哪些信息
为实现产品功能并保障稳定性，我们可能收集与处理以下信息：

- 你主动提供的信息：当你通过邮件等方式联系我们时，你提交的内容（例如问题描述、截图、可选的日志与诊断信息、联系方式）。
- 剪贴板相关信息（用于核心功能）：当你使用 Paste 的剪贴板管理/历史/搜索等功能时，应用会在你的设备上读取并处理剪贴板内容；如你启用“云同步”，相关数据可能会被同步到云端以在你的设备间保持一致。
- 订阅与购买信息（由购买渠道处理）：你进行订阅购买时，交易由应用分发平台（如 Mac App Store）处理。我们通常无法获取你的完整支付信息（如银行卡号），但可能会接收用于解锁权益的购买结果/订阅状态（例如是否有效、到期时间等，具体以平台回传为准）。

说明：Paste 不进行用户行为统计，也不进行崩溃/诊断上报（以当前版本与实际配置为准）。

2. 我们如何使用信息
- 提供与维护功能：实现剪贴板管理、历史记录、搜索、跨设备同步等。
- 用户支持：回应你的咨询与问题处理（仅在你联系并提供信息时使用）。
- 安全与合规：满足法律法规要求、处理滥用与安全风险。

3. 云同步与数据存储
- 本地存储：Paste 可能在你的设备本地保存剪贴板历史、配置与缓存数据（存储位置受 macOS 沙盒机制保护）。
- 云端存储（你启用云同步时）：为实现跨设备同步，你选择同步的数据会被上传并存储在云端，并在你的设备间同步。
- 存储期限：我们会在实现功能所需的合理期限内保留数据；你可以通过应用内功能清理历史记录/关闭云同步，或卸载应用以停止进一步处理。关闭云同步后，云端已有数据的保留与删除机制以应用内提示与实际实现为准。

4. 我们如何共享、转让与披露信息
我们不会出售你的个人信息。除以下情况外，我们不会与第三方共享你的数据：
- 经你明确同意；
- 为实现云同步所必需：在你启用云同步时，数据需要通过云服务进行存储与传输（具体服务与范围以应用实际实现为准）；
- 法律法规要求：依法配合监管、司法或执法机关的合法要求。

5. 第三方服务
- 应用分发与订阅：订阅购买与退款等通常由应用分发平台（如 Mac App Store）按照其规则处理。
- 云同步基础设施：云同步可能依赖云服务提供方的存储与传输能力（以实际实现为准）。第三方将根据其政策处理相关数据。

6. 你的权利与选择
你可以：
- 删除数据：在应用内清理剪贴板历史/相关记录（如提供该功能）。
- 关闭云同步：在应用设置中关闭同步以停止云端同步处理。
- 撤回系统权限：在 macOS 系统设置中撤销剪贴板/相关权限（撤回后部分功能可能不可用）。
- 联系我们：通过 gxlself@gmail.com 提出隐私相关问题与请求。

7. 儿童隐私
Paste 不面向未成年人提供服务。若我们发现不当收集相关信息，将尽快删除。

8. 跨境传输（如适用）
若你启用的云同步所使用的云服务涉及跨境存储或传输，我们将依据适用法律法规采取必要措施，并尽可能降低风险。

9. 本政策的更新
我们可能适时更新本政策。若发生重大变更，我们会通过应用内提示或发布渠道公告。更新后你继续使用 Paste，即视为你理解并同意更新内容。
"""#

    static let termsOfUse_zhHans = #"""
使用条款（Terms of Use）

生效日期：2026-01-26
应用名称：Paste
开发者/运营方：Gxlself
联系邮箱：gxlself@gmail.com

1. 接受条款
你下载、安装、访问或使用 Paste，即表示你已阅读并同意本使用条款及《隐私政策》。如不同意，请停止使用并卸载。

2. 服务内容与许可
- Paste 提供剪贴板管理、历史记录、搜索与（可选）云同步等功能（以实际版本为准）。
- 我们授予你一项个人、非排他、不可转让、可撤销的许可，用于在你拥有或控制的设备上使用本应用。

3. 订阅与付费（如适用）
- Paste 提供付费订阅以解锁部分功能/权益（以购买页面展示为准）。
- 订阅的扣费、续费、取消与退款遵循你购买渠道（如 Mac App Store）的规则与条款。
- 你应确保使用合法方式完成订阅购买。

4. 用户义务与禁止行为
你承诺不会：
- 将 Paste 用于任何违法用途，或侵犯他人合法权益；
- 逆向工程、反编译、破解、绕过授权或安全机制（法律允许的除外）；
- 干扰、破坏应用或相关系统的正常运行；
- 未经许可复制、出租、出售、分发 Paste 或其衍生作品。

5. 剪贴板内容风险提示
- 你理解：剪贴板可能包含敏感信息（如密码、验证码、身份信息等）。你应自行评估并妥善管理剪贴板内容。
- 因你复制、保存、同步、分享或使用剪贴板内容导致的风险或损失，由你自行承担。

6. 知识产权
Paste 及其相关内容（包括但不限于代码、界面、图标、商标等）的知识产权归 Gxlself 或相关权利人所有。未经许可不得使用。

7. 免责声明
在适用法律允许范围内：
- Paste 按“现状”提供，我们不保证完全无错误、不间断或满足你的特定需求；
- 因不可抗力、系统或网络故障、第三方原因等导致的服务中断或数据损失，我们在法律允许范围内不承担责任。

8. 责任限制
在适用法律允许范围内，我们对间接损失、利润损失、数据丢失等不承担责任；如需承担责任，赔偿总额以你为使用 Paste 所支付的费用（如有）为上限，或按法律强制规定执行（以较高者为准）。

9. 变更与终止
我们可基于产品运营与合规需要更新、修改或终止部分功能；你可随时停止使用并卸载应用。若你违反本条款，我们可在合理范围内限制或终止向你提供服务。

10. 适用法律与争议解决
本条款适用中华人民共和国法律（不含冲突法规则）。因本条款产生的争议，双方应友好协商；协商不成，提交我们所在地有管辖权的人民法院解决。

11. 联系我们
如有任何问题，请联系：gxlself@gmail.com
"""#

    // MARK: - en

    static let privacyPolicy_en = #"""
Privacy Policy

Effective Date: 2026-01-26
App Name: Paste
Developer/Operator: Gxlself ("we", "us")
Contact Email: gxlself@gmail.com

1. Information We Collect
To provide and improve the app, we may collect and process:

- Information you provide: content you send when contacting us by email (e.g., issue descriptions, screenshots, optional logs/diagnostics, contact details).
- Clipboard-related information (core functionality): when you use clipboard management/history/search, the app reads and processes your clipboard content on your device. If you enable "Cloud Sync", the data you choose to sync may be uploaded to the cloud to keep your devices in sync.
- Subscription and purchase information (handled by the platform): purchases are processed by the distribution platform (e.g., Mac App Store). We typically do not receive your full payment details (e.g., card number), but we may receive purchase/entitlement status necessary to unlock features (e.g., whether a subscription is active and its expiry, as provided by the platform).

Note: Paste does not perform user analytics tracking and does not upload crash/diagnostic reports (based on the current version and configuration).

2. How We Use Information
- Provide and maintain features: clipboard management, history, search, cross-device sync.
- Customer support: respond to your requests (only when you contact us and provide information).
- Security and compliance: comply with applicable laws and address abuse/security risks.

3. Cloud Sync and Data Storage
- Local storage: Paste may store clipboard history, settings, and cache locally on your device (protected by macOS sandboxing).
- Cloud storage (when Cloud Sync is enabled): to enable cross-device sync, the data you choose to sync is uploaded and stored in the cloud and synchronized across your devices.
- Retention: we keep data for a reasonable period needed to provide the service. You can clear history in the app (if available), disable Cloud Sync, or uninstall the app to stop further processing. After disabling Cloud Sync, cloud data retention/deletion depends on the in-app behavior and implementation.

4. Sharing, Transfer, and Disclosure
We do not sell your personal information. We do not share your data with third parties except:
- With your explicit consent;
- When necessary to provide Cloud Sync (storage and transmission through cloud services, as implemented);
- When required by law, regulation, or valid legal process.

5. Third-Party Services
- App distribution and subscriptions: billing, renewals, cancellations, and refunds are handled by the platform (e.g., Mac App Store) under its rules.
- Cloud sync infrastructure: Cloud Sync may rely on third-party cloud providers for storage and transfer (as implemented). Those providers process data under their own policies.

6. Your Choices
You can:
- Delete data: clear clipboard history/records in the app (if available).
- Disable Cloud Sync: turn off sync in settings to stop cloud synchronization.
- Revoke system permissions: revoke clipboard-related permissions in macOS settings (some features may stop working).
- Contact us: email gxlself@gmail.com for privacy questions and requests.

7. Children’s Privacy
Paste is not intended for children. If we become aware we collected information improperly, we will delete it promptly.

8. Cross-Border Transfers (if applicable)
If Cloud Sync involves cross-border storage or transfer, we will take measures required by applicable law and aim to minimize risk.

9. Updates to This Policy
We may update this policy from time to time. Material changes will be notified via in-app notice or release channels. Continued use after updates means you accept the updated policy.
"""#

    static let termsOfUse_en = #"""
Terms of Use

Effective Date: 2026-01-26
App Name: Paste
Developer/Operator: Gxlself
Contact Email: gxlself@gmail.com

1. Acceptance of Terms
By downloading, installing, accessing, or using Paste, you agree to these Terms of Use and the Privacy Policy. If you do not agree, please stop using and uninstall the app.

2. Service and License
- Paste provides clipboard management, history, search, and optional cloud sync (as available in the current version).
- We grant you a personal, non-exclusive, non-transferable, revocable license to use the app on devices you own or control.

3. Subscriptions and Paid Features (if applicable)
- Paste offers subscriptions to unlock certain features/benefits (as shown on the purchase page).
- Billing, renewals, cancellations, and refunds follow the rules of your purchase platform (e.g., Mac App Store).
- You must use lawful means to purchase subscriptions.

4. User Obligations and Prohibited Conduct
You agree not to:
- Use the app for unlawful purposes or infringe others’ rights;
- Reverse engineer, decompile, tamper with, or bypass licensing/security mechanisms (except where permitted by law);
- Interfere with or disrupt the app or related systems;
- Copy, rent, sell, distribute, or create derivative works of the app without our permission.

5. Clipboard Content Notice
- Clipboard content may contain sensitive information (passwords, one-time codes, identity data). You should manage clipboard content carefully.
- Any risks or losses arising from your copying, storing, syncing, sharing, or using clipboard content are your responsibility.

6. Intellectual Property
The app and related content (including code, UI, icons, trademarks) are owned by Gxlself or the respective rights holders. Unauthorized use is prohibited.

7. Disclaimer
To the extent permitted by law:
- The app is provided "as is" without warranties of uninterrupted or error-free operation or fitness for a particular purpose.
- We are not liable for interruptions or data loss caused by force majeure, system/network failures, or third parties.

8. Limitation of Liability
To the extent permitted by law, we are not liable for indirect, incidental, or consequential damages (including loss of profits or data). If liability applies, our total liability is limited to the amount you paid for the app (if any), or as required by law, whichever is greater.

9. Changes and Termination
We may update, modify, or discontinue parts of the app for operational or compliance reasons. You may stop using the app at any time. If you violate these terms, we may restrict or terminate access within a reasonable scope.

10. Governing Law and Dispute Resolution
These terms are governed by the laws of the People’s Republic of China (excluding conflict-of-law rules). Disputes should be resolved through friendly negotiation; if negotiation fails, disputes will be submitted to the court with jurisdiction where we are located.

11. Contact
If you have questions, contact: gxlself@gmail.com
"""#
}

