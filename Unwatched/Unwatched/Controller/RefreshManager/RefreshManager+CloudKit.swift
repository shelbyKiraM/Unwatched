//
//  RefreshManager+CloudKit.swift
//  Unwatched
//

import Foundation
import OSLog
import CoreData
import SwiftData
import UnwatchedShared

extension RefreshManager {
    func setupCloudKitListener() {
        isSyncingIcloud = false
    }

    func cancelCloudKitListener() {
        cancellables.removeAll()
        isSyncingIcloud = false
    }

    func handleIcloudSyncDone() async {
        let task = Task { @MainActor in
            self.isSyncingIcloud = false
        }
        await task.value
        await executeAutoRefresh()
    }

    func cleanup(
        hardRefresh: Bool
    ) async {
        if hardRefresh {
            let task = CleanupService.cleanupDuplicatesAndInboxDate(quickCheck: false, videoOnly: false)
            _ = await task.value
        } else {
            await quickCleanup()
        }
    }

    private func quickCleanup() async {
        Log.info("quickCleanup")
        let task = CleanupService.cleanupDuplicatesAndInboxDate(quickCheck: true)
        _ = await task.value
    }
}
