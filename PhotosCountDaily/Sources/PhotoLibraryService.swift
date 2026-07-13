import Foundation
import Photos
import UniformTypeIdentifiers

enum PhotoLibraryService {
    static func requestAccess() async -> PHAuthorizationStatus {
        await PHPhotoLibrary.requestAuthorization(for: .readWrite)
    }

    /// ユーザーライブラリの全資産を AssetRecord に変換する。
    /// リソース列挙が資産ごとに DB を叩くため大規模ライブラリでは時間がかかる。
    /// progress は約 30Hz に間引いて呼ばれる（最終件は必ず呼ぶ）。
    static func loadRecords(
        progress: @escaping @Sendable (Int, Int) -> Void
    ) async -> [AssetRecord] {
        await Task.detached(priority: .userInitiated) {
            let options = PHFetchOptions()
            // 共有アルバム等を除外し、ライブラリビュー相当の資産のみ対象にする
            options.includeAssetSourceTypes = [.typeUserLibrary]
            let fetchResult = PHAsset.fetchAssets(with: options)
            let total = fetchResult.count
            var records: [AssetRecord] = []
            records.reserveCapacity(total)

            var lastReport = Date.distantPast
            fetchResult.enumerateObjects { asset, index, _ in
                records.append(record(from: asset))
                // 毎アイテム進捗を刻みつつ、UI 更新は約 30Hz に間引く
                let now = Date()
                if now.timeIntervalSince(lastReport) >= 1.0 / 30.0 || index == total - 1 {
                    lastReport = now
                    progress(index + 1, total)
                }
            }
            return records
        }.value
    }

    static func record(from asset: PHAsset) -> AssetRecord {
        var isRAW = false
        var totalSize: Int64 = 0
        var sizeKnown = false

        for resource in PHAssetResource.assetResources(for: asset) {
            switch resource.type {
            case .photo, .video, .alternatePhoto:
                if let type = UTType(resource.uniformTypeIdentifier),
                   type.conforms(to: .rawImage) {
                    isRAW = true
                }
                // fileSize は公開 API にないため KVC で取得する（App Store 配布はしない前提）
                if let size = (resource.value(forKey: "fileSize") as? NSNumber)?.int64Value {
                    totalSize += size
                    sizeKnown = true
                }
            default:
                break
            }
        }

        return AssetRecord(
            creationDate: asset.creationDate,
            isVideo: asset.mediaType == .video,
            isRAW: isRAW,
            fileSize: sizeKnown ? totalSize : nil
        )
    }
}
