//
//  VideoPlayer.swift
//  VideoPlayer
//
//  Created by Gesen on 2019/7/7.
//  Copyright © 2019 Gesen. All rights reserved.
//

import AVFoundation
import GSPlayer
import SwiftUI
import CoreMedia

public struct VideoPlayer {
    
    public enum State {
        
        /// From the first load to get the first frame of the video
        case loading
        
        /// Playing now
        case playing(totalDuration: Double)
        
        /// Pause, will be called repeatedly when the buffer progress changes
        case paused(playProgress: Double, bufferProgress: Double)
        
        /// An error occurred and cannot continue playing
        case error(NSError)
    }
    
    private(set) var url: URL
    
    @Binding internal var play: Bool
    @Binding internal var time: CMTime
    
    internal var config = Config()
    
    /// Init video player instance.
    /// - Parameters:
    ///   - url: http/https URL
    ///   - play: play/pause
    ///   - time: current time
    public init(url: URL, play: Binding<Bool>, time: Binding<CMTime> = .constant(.zero)) {
        self.url = url
        _play = play
        _time = time
    }
    
    public func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    public class Coordinator: NSObject {
        var videoPlayer: VideoPlayer
        var observingURL: URL?
        var observer: Any?
        var observerTime: CMTime?
        var observerBuffer: Double?

        init(_ videoPlayer: VideoPlayer) {
            self.videoPlayer = videoPlayer
        }
        
        func startObserver(view: VideoPlayerView) {
            guard observer == nil else { return }
            
            observer = view.addPeriodicTimeObserver(forInterval: .init(seconds: 0.25, preferredTimescale: 60)) { [weak self, unowned view] time in
                guard let self = self else { return }
                
                self.videoPlayer.time = time
                self.observerTime = time
                
                self.updateBuffer(view: view)
            }
        }
        
        func stopObserver(view: VideoPlayerView) {
            guard let observer = observer else { return }
            
            view.removeTimeObserver(observer)
            
            self.observer = nil
        }
        
        func updateBuffer(view: VideoPlayerView) {
            guard let handler = videoPlayer.config.handler.onBufferChanged else { return }
            
            let bufferProgress = view.bufferProgress
                
            guard bufferProgress != observerBuffer else { return }
            
            DispatchQueue.main.async { handler(bufferProgress) }
            
            observerBuffer = bufferProgress
        }
    }
}

public extension VideoPlayer {
    
    /// Set the preload size, the default value is 1024 * 1024, unit is byte.
    static var preloadByteCount: Int {
        get { VideoPreloadManager.shared.preloadByteCount }
        set { VideoPreloadManager.shared.preloadByteCount = newValue }
    }
    
    /// Set the video urls to be preload queue.
    /// Preloading will automatically cache a short segment of the beginning of the video
    /// and decide whether to start or pause the preload based on the buffering of the currently playing video.
    /// - Parameter urls: URL array
    static func preload(urls: [URL]) {
        VideoPreloadManager.shared.set(waiting: urls)
    }
    
    /// Set custom http header, such as token.
    static func customHTTPHeaderFields(transform: @escaping (URL) -> [String: String]?) {
        VideoLoadManager.shared.customHTTPHeaderFields = transform
    }
    
    /// Get the total size of the video cache.
    static func calculateCachedSize() -> UInt {
        return VideoCacheManager.calculateCachedSize()
    }
    
    /// Clean up all caches.
    static func cleanAllCache() {
        try? VideoCacheManager.cleanAllCache()
    }
}

public extension VideoPlayer {
    
    struct Config {
        struct Handler {
            var onBufferChanged: ((Double) -> Void)?
            var onPlayToEndTime: (() -> Void)?
            var onReplay: (() -> Void)?
            var onStateChanged: ((State) -> Void)?
        }
        
        var autoReplay: Bool = false
        var mute: Bool = false
        var contentMode: ContentMode = .fill
        
        var handler: Handler = Handler()
    }
    
    /// Whether the video will be automatically replayed until the end of the video playback.
    func autoReplay(_ value: Bool) -> Self {
        var view = self
        view.config.autoReplay = value
        return view
    }
    
    /// Whether the video is muted, only for this instance.
    func mute(_ value: Bool) -> Self {
        var view = self
        view.config.mute = value
        return view
    }
    
    /// A string defining how the video is displayed within an AVPlayerLayer bounds rect.
    /// scaleAspectFill -> resizeAspectFill, scaleAspectFit -> resizeAspect, other -> resize
    func contentMode(_ value: ContentMode) -> Self {
        var view = self
        view.config.contentMode = value
        return view
    }
    
    /// Trigger a callback when the buffer progress changes,
    /// the value is between 0 and 1.
    func onBufferChanged(_ handler: @escaping (Double) -> Void) -> Self {
        var view = self
        view.config.handler.onBufferChanged = handler
        return view
    }
    
    /// Playing to the end.
    func onPlayToEndTime(_ handler: @escaping () -> Void) -> Self {
        var view = self
        view.config.handler.onPlayToEndTime = handler
        return view
    }
    
    /// Replay after playing to the end.
    func onReplay(_ handler: @escaping () -> Void) -> Self {
        var view = self
        view.config.handler.onReplay = handler
        return view
    }
    
    /// Playback status changes, such as from play to pause.
    func onStateChanged(_ handler: @escaping (State) -> Void) -> Self {
        var view = self
        view.config.handler.onStateChanged = handler
        return view
    }
    
}

internal extension VideoPlayerView {
    
    func convertState() -> VideoPlayer.State {
        switch state {
        case .none, .loading:
            return .loading
        case .playing:
            return .playing(totalDuration: totalDuration)
        case .paused(let p, let b):
            return .paused(playProgress: p, bufferProgress: b)
        case .error(let error):
            return .error(error)
        }
    }
}
