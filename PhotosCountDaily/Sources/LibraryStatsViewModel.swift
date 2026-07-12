import Foundation
import Observation
import Photos

enum MediaFilter: String, CaseIterable {
    case all = "All"
    case photosOnly = "Photos only"
    case rawOnly = "RAW only"
}

@MainActor
@Observable
final class LibraryStatsViewModel {
    enum LoadState: Equatable {
        case idle
        case denied
        case loading(done: Int, total: Int)
        case loaded
    }

    var state: LoadState = .idle
    var filter: MediaFilter = .all { didSet { recompute() } }
    var sortField: StatSortField = .count { didSet { resort() } }
    var sortAscending = false { didSet { resort() } }
    private(set) var result: AggregationResult = .empty
    private(set) var sortedStats: [DailyStat] = []

    private var records: [AssetRecord] = []

    func load() async {
        guard state == .idle else { return }
        let status = await PhotoLibraryService.requestAccess()
        guard status == .authorized || status == .limited else {
            state = .denied
            return
        }
        state = .loading(done: 0, total: 0)
        records = await PhotoLibraryService.loadRecords { done, total in
            Task { @MainActor [weak self] in
                self?.state = .loading(done: done, total: total)
            }
        }
        recompute()
        state = .loaded
    }

    private func recompute() {
        result = DailyAggregator.aggregate(
            records,
            photosOnly: filter == .photosOnly,
            rawOnly: filter == .rawOnly
        )
        resort()
    }

    private func resort() {
        sortedStats = DailyAggregator.sorted(result.stats, by: sortField, ascending: sortAscending)
    }
}
