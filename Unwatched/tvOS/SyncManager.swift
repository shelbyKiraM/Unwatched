//
//  SyncManager.swift
//  UnwatchedTV
//

import SwiftUI
import Observation
import Combine
import OSLog
import CoreData
import UnwatchedShared

@Observable class SyncManager {
    var isSyncing = false

    @ObservationIgnored var cancellables: Set<AnyCancellable> = []

    init() {
        isSyncing = false
    }

    func setupCloudKitListener() {
        isSyncing = false
    }

    func cancelCloudKitListener() {
        cancellables.removeAll()
        isSyncing = false
    }

}
