//
//  DataController.swift
//  Unwatched
//

import Foundation
import SwiftData
import OSLog

public extension ProcessInfo {
    var isXcodePreview: Bool {
        environment["XCODE_RUNNING_FOR_PREVIEWS"] != nil
    }
}

public final class DataProvider: Sendable {
    public static let shared = DataProvider()

    public let container: ModelContainer = {
        Log.info("getModelContainer")
        if UserDefaults.standard.bool(forKey: Const.enableIcloudSync) {
            Log.info("getModelContainer: CloudKit disabled for this build, forcing local store")
            UserDefaults.standard.set(false, forKey: Const.enableIcloudSync)
        }

        #if DEBUG
        if CommandLine.arguments.contains("enable-testing") || ProcessInfo.processInfo.isXcodePreview {
            return DataProvider.previewContainer
        }
        #endif

        let storeURL = defaultStoreURL()

        let config = ModelConfiguration(
            nil,
            schema: DataProvider.schema,
            url: storeURL,
            allowsSave: true,
            cloudKitDatabase: .none
        )

        Log.info("getModelContainer: config set \(storeURL.path())")

        do {
            do {
                return try ModelContainer(
                    for: DataProvider.schema,
                    migrationPlan: UnwatchedMigrationPlan.self,
                    configurations: [config]
                )
            } catch {
                Log.error("getModelContainer error: \(error)")
            }

            // workaround for migration (disable sync for initial launch)
            Log.info("getModelContainer: fallback")
            let config = ModelConfiguration(
                nil,
                schema: DataProvider.schema,
                url: storeURL,
                allowsSave: true,
                cloudKitDatabase: .none
            )
            let container = try ModelContainer(
                for: DataProvider.schema,
                migrationPlan: UnwatchedMigrationPlan.self,
                configurations: [config]
            )
            Task { @MainActor in
                DataProvider.migrationWorkaround(container.mainContext)
            }
            return container
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    private static func defaultStoreURL() -> URL {
        #if os(macOS)
        let appSupportURL = URL.applicationSupportDirectory
        #else
        let appSupportURL = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first ?? URL.documentsDirectory
        #endif

        do {
            try FileManager.default.createDirectory(
                at: appSupportURL,
                withIntermediateDirectories: true
            )
        } catch {
            Log.error("getModelContainer: failed to create app support directory \(error)")
        }

        return appSupportURL.appending(path: "default.store")
    }

    private static func migrationWorkaround(_ context: ModelContext) {
        // workaround: migration fails during willMigrate (https://developer.apple.com/forums/thread/775060)
        let dict = UnwatchedMigrationPlan.subPlaceVideosIn
        if !dict.isEmpty {
            UnwatchedMigrationPlan.migrateV1p6toV1p7DidMigrate(context)
        }
        UnwatchedMigrationPlan.migrateV1p9toV1p10DidMigrate()
    }

    public let localCacheContainer: ModelContainer = {
        let schema = Schema([CachedImage.self, Transcript.self])
        let fileName = "imageCache.sqlite"

        #if os(tvOS)
        let storeURL = FileManager.default
            .urls(for: .cachesDirectory, in: .userDomainMask)
            .first!
            .appendingPathComponent(fileName)
        #elseif os(macOS)
        let storeURL = URL.applicationSupportDirectory.appending(path: fileName)
        #else
        let storeURL = URL.documentsDirectory.appending(path: fileName)
        #endif

        let config = ModelConfiguration(
            nil,
            schema: schema,
            url: storeURL,
            allowsSave: true,
            cloudKitDatabase: .none
        )

        do {
            return try ModelContainer(
                for: schema,
                migrationPlan: CachedImageMigrationPlan.self,
                configurations: [config]
            )
        } catch {
            fatalError("Could not create CachedImage ModelContainer: \(error)")
        }
    }()

    init() {}

    public static func newContext() -> ModelContext {
        ModelContext(shared.container)
    }

    @MainActor
    public static var mainContext: ModelContext {
        shared.container.mainContext
    }

    public static let dbEntries: [any PersistentModel.Type] = [
        Video.self,
        Subscription.self,
        QueueEntry.self,
        InboxEntry.self,
        Chapter.self,
        WatchTimeEntry.self
    ]

    static let schema = Schema(DataProvider.dbEntries)

    public static let previewContainer: ModelContainer = {
        var sharedModelContainer: ModelContainer = {
            let schema = Schema(DataProvider.dbEntries)
            let modelConfiguration = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: true,
                cloudKitDatabase: .none
            )

            do {
                return try ModelContainer(for: schema, configurations: [modelConfiguration])
            } catch {
                fatalError("Could not create preview ModelContainer: \(error)")
            }
        }()
        return sharedModelContainer
    }()
}
