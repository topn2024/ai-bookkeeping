import UIKit
import Social
import MobileCoreServices
import UniformTypeIdentifiers

/// Share Extension 视图控制器
/// 处理从其他应用分享过来的图片
class ShareViewController: SLComposeServiceViewController {

    /// App Group 标识符（需要与主应用一致）
    private let appGroupId = "group.com.example.ai_bookkeeping"

    /// 分享文件存储目录名
    private let sharedFolderName = "SharedImages"

    override func isContentValid() -> Bool {
        // 检查是否有有效的图片内容
        return hasImageContent()
    }

    override func didSelectPost() {
        // 处理分享的图片
        processSharedImages { [weak self] success in
            DispatchQueue.main.async {
                if success {
                    // 打开主应用
                    self?.openMainApp()
                }
                // 完成扩展
                self?.extensionContext?.completeRequest(
                    returningItems: nil,
                    completionHandler: nil
                )
            }
        }
    }

    override func configurationItems() -> [Any]! {
        // 可以在这里添加配置项
        return []
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        // 设置标题
        self.title = "发送到鱼记"
        // 自定义发布按钮文字
        self.navigationItem.rightBarButtonItem?.title = "识别记账"
    }

    // MARK: - Private Methods

    /// 检查是否有图片内容
    private func hasImageContent() -> Bool {
        guard let extensionItems = extensionContext?.inputItems as? [NSExtensionItem] else {
            return false
        }

        for item in extensionItems {
            guard let attachments = item.attachments else { continue }

            for attachment in attachments {
                if attachment.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
                    return true
                }
            }
        }

        return false
    }

    /// 处理分享的图片
    private func processSharedImages(completion: @escaping (Bool) -> Void) {
        guard let extensionItems = extensionContext?.inputItems as? [NSExtensionItem] else {
            completion(false)
            return
        }

        let dispatchGroup = DispatchGroup()
        var savedPaths: [String] = []

        for item in extensionItems {
            guard let attachments = item.attachments else { continue }

            for attachment in attachments {
                if attachment.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
                    dispatchGroup.enter()

                    attachment.loadItem(forTypeIdentifier: UTType.image.identifier, options: nil) { [weak self] item, error in
                        defer { dispatchGroup.leave() }

                        if let error = error {
                            print("ShareExtension: 加载图片失败: \(error)")
                            return
                        }

                        var imageData: Data?

                        if let url = item as? URL {
                            imageData = try? Data(contentsOf: url)
                        } else if let image = item as? UIImage {
                            imageData = image.jpegData(compressionQuality: 0.85)
                        } else if let data = item as? Data {
                            imageData = data
                        }

                        if let data = imageData, let path = self?.saveImageToSharedContainer(data) {
                            savedPaths.append(path)
                        }
                    }
                }
            }
        }

        dispatchGroup.notify(queue: .main) { [weak self] in
            if !savedPaths.isEmpty {
                // 保存路径列表到 UserDefaults
                self?.saveImagePathsToUserDefaults(savedPaths)
                completion(true)
            } else {
                completion(false)
            }
        }
    }

    /// 保存图片到共享容器
    private func saveImageToSharedContainer(_ imageData: Data) -> String? {
        guard let containerURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: appGroupId
        ) else {
            print("ShareExtension: 无法访问 App Group 容器")
            return nil
        }

        let sharedFolder = containerURL.appendingPathComponent(sharedFolderName)

        // 确保目录存在
        try? FileManager.default.createDirectory(
            at: sharedFolder,
            withIntermediateDirectories: true,
            attributes: nil
        )

        // 生成唯一文件名
        let fileName = "shared_\(UUID().uuidString).jpg"
        let fileURL = sharedFolder.appendingPathComponent(fileName)

        do {
            try imageData.write(to: fileURL)
            return fileURL.path
        } catch {
            print("ShareExtension: 保存图片失败: \(error)")
            return nil
        }
    }

    /// 保存图片路径到 UserDefaults
    private func saveImagePathsToUserDefaults(_ paths: [String]) {
        guard let userDefaults = UserDefaults(suiteName: appGroupId) else {
            print("ShareExtension: 无法访问共享 UserDefaults")
            return
        }

        // 获取现有路径并追加
        var existingPaths = userDefaults.stringArray(forKey: "pendingSharedImages") ?? []
        existingPaths.append(contentsOf: paths)

        userDefaults.set(existingPaths, forKey: "pendingSharedImages")
        userDefaults.set(Date().timeIntervalSince1970, forKey: "lastShareTimestamp")
        userDefaults.synchronize()
    }

    /// 打开主应用
    private func openMainApp() {
        // 使用 URL Scheme 打开主应用
        let urlString = "aibookkeeping://share?action=recognize"

        guard let url = URL(string: urlString) else { return }

        // 在 iOS 中，Share Extension 不能直接打开其他应用
        // 需要通过 openURL 方法（需要在扩展中特殊处理）
        var responder: UIResponder? = self
        while responder != nil {
            if let application = responder as? UIApplication {
                application.open(url, options: [:], completionHandler: nil)
                break
            }
            responder = responder?.next
        }
    }
}
