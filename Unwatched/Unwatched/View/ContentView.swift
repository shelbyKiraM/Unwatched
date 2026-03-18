//
//  ContentView.swift
//  Unwatched
//

import SwiftUI
import SwiftData
import OSLog
import UnwatchedShared

struct ContentView: View {
    @Environment(\.colorScheme) var colorScheme
    @Environment(NavigationManager.self) var navManager
    @Environment(PlayerManager.self) var player
    @Environment(\.horizontalSizeClass) var sizeClass: UserInterfaceSizeClass?
    @Environment(SheetPositionReader.self) var sheetPos

    var videoExists: Bool {
        player.video != nil
    }

    var bigScreen: Bool {
        Device.isBigScreen(sizeClass)
    }

    var body: some View {
        GeometryReader { proxy in
            let isLandscape = proxy.size.width > proxy.size.height
            let landscapeFullscreen = !bigScreen && isLandscape

            ZStack {
                #if os(iOS) || os(visionOS)
                IOSSPlitView(
                    proxy: proxy,
                    bigScreen: bigScreen,
                    isLandscape: isLandscape,
                    landscapeFullscreen: landscapeFullscreen
                )
                #else
                MacOSSplitView(
                    bigScreen: bigScreen,
                    isLandscape: isLandscape,
                    landscapeFullscreen: landscapeFullscreen
                )
                #endif
            }
            #if os(iOS)
            .environment(\.colorScheme, .dark)
            #endif
            #if !os(visionOS)
            .background(Color.playerBackgroundColor)
            #endif
            .onChange(of: proxy.safeAreaInsets.top, initial: true) {
                if !landscapeFullscreen {
                    sheetPos.setTopSafeArea(proxy.safeAreaInsets.top)
                }
            }
            .menuViewSheet(
                allowPlayerControlHeight: !player.embeddingDisabled
                    && player.videoAspectRatio > Const.tallestAspectRatio,
                landscapeFullscreen: landscapeFullscreen,
                disableSheet: bigScreen,
                proxy: proxy
            )
            .onAppear {
                logLayoutState(proxy: proxy, landscapeFullscreen: landscapeFullscreen, reason: "appear")
            }
            .onChange(of: proxy.size, initial: true) {
                logLayoutState(proxy: proxy, landscapeFullscreen: landscapeFullscreen, reason: "sizeChange")
            }
            .onChange(of: navManager.showMenu, initial: true) {
                logLayoutState(proxy: proxy, landscapeFullscreen: landscapeFullscreen, reason: "showMenu")
            }
            .onChange(of: player.video?.youtubeId, initial: true) {
                logLayoutState(proxy: proxy, landscapeFullscreen: landscapeFullscreen, reason: "video")
            }
            .onChange(of: player.embeddingDisabled, initial: true) {
                logLayoutState(proxy: proxy, landscapeFullscreen: landscapeFullscreen, reason: "embeddingDisabled")
            }
        }
        .setColorScheme()
        .onSizeChange { newSize in
            sheetPos.sheetHeight = newSize.height
        }
        .ignoresSafeArea(.keyboard)
    }

    func logLayoutState(proxy: GeometryProxy, landscapeFullscreen: Bool, reason: String) {
        Log.info(
            """
            ContentView[\(reason)]: size=\(proxy.size.width)x\(proxy.size.height) \
            bigScreen=\(bigScreen) landscapeFullscreen=\(landscapeFullscreen) \
            showMenu=\(navManager.showMenu) tab=\(String(describing: navManager.tab)) \
            video=\(player.video?.youtubeId ?? "nil") embeddingDisabled=\(player.embeddingDisabled) \
            swipedBelow=\(sheetPos.swipedBelow)
            """
        )
    }
}

#Preview {
    ContentView()
        .modelContainer(DataProvider.previewContainer)
        .environment(NavigationManager.getDummy(true))
        .environment(Alerter())
        .environment(PlayerManager.getDummy())
        .environment(ImageCacheManager())
        .environment(RefreshManager())
        .environment(SheetPositionReader.shared)
        .environment(TinyUndoManager())
        .modifier(CustomAlerter())
        #if os(macOS) || os(visionOS)
        .environment(NavigationTitleManager())
        #endif
        .appNotificationOverlay()
}
