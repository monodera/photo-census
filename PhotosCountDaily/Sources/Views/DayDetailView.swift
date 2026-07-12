import Photos
import SwiftUI

struct DayDetailView: View {
    let stat: DailyStat
    let photosOnly: Bool
    let rawOnly: Bool

    @Environment(\.dismiss) private var dismiss
    @State private var assets: [PHAsset] = []

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("\(stat.day) — \(stat.count) items")
                    .font(.headline)
                Spacer()
                Button("Close") { dismiss() }
                    .keyboardShortcut(.cancelAction)
            }
            .padding()
            Divider()
            ScrollView {
                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: 120), spacing: 8)],
                    spacing: 8
                ) {
                    ForEach(assets, id: \.localIdentifier) { asset in
                        AssetThumbnailView(asset: asset)
                    }
                }
                .padding()
            }
        }
        .frame(minWidth: 560, minHeight: 420)
        .task {
            assets = Self.fetchAssets(for: stat, photosOnly: photosOnly, rawOnly: rawOnly)
        }
    }

    /// 集計と同じローカルタイムゾーン・同じフィルタ条件でその日の資産を取得する
    static func fetchAssets(for stat: DailyStat, photosOnly: Bool, rawOnly: Bool) -> [PHAsset] {
        guard let dayStart = stat.date else { return [] }
        let dayEnd = Calendar.current.date(byAdding: .day, value: 1, to: dayStart)!

        var predicates = [
            NSPredicate(
                format: "creationDate >= %@ AND creationDate < %@",
                dayStart as NSDate, dayEnd as NSDate
            )
        ]
        if photosOnly {
            predicates.append(
                NSPredicate(format: "mediaType == %d", PHAssetMediaType.image.rawValue)
            )
        }

        let options = PHFetchOptions()
        options.includeAssetSourceTypes = [.typeUserLibrary]
        options.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: true)]

        let fetchResult = PHAsset.fetchAssets(with: options)
        var result: [PHAsset] = []
        result.reserveCapacity(fetchResult.count)
        fetchResult.enumerateObjects { asset, _, _ in
            result.append(asset)
        }
        if rawOnly {
            result = result.filter { PhotoLibraryService.record(from: $0).isRAW }
        }
        return result
    }
}

struct AssetThumbnailView: View {
    let asset: PHAsset

    @State private var image: NSImage?

    private static let imageManager = PHCachingImageManager()

    var body: some View {
        ZStack {
            if let image {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Rectangle().fill(.quaternary)
                ProgressView().controlSize(.small)
            }
        }
        .frame(width: 120, height: 120)
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .task {
            let options = PHImageRequestOptions()
            options.isNetworkAccessAllowed = true
            options.deliveryMode = .opportunistic
            Self.imageManager.requestImage(
                for: asset,
                targetSize: CGSize(width: 240, height: 240),
                contentMode: .aspectFill,
                options: options
            ) { result, _ in
                if let result {
                    image = result
                }
            }
        }
    }
}
