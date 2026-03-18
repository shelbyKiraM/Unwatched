//
//  CloudSyncSetting.swift
//  Unwatched
//

import SwiftUI
import UnwatchedShared

struct CloudSyncSetting: View {
    var body: some View {
        MySection("icloudSync") {
            Text("iCloud sync is unavailable in this local build.")
                .foregroundStyle(.secondary)
        }
    }
}
