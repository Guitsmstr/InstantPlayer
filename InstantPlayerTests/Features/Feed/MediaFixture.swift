//
//  MediaFixture.swift
//  InstantPlayerTests
//
//  Throwaway fixture builder for the seam suites (E2-S1, design §9.1).
//

import AVFoundation
import CoreGraphics
import Darwin
import Foundation
import ImageIO
import UniformTypeIdentifiers

/// Builds throwaway fixture folders under
/// `FileManager.default.temporaryDirectory/<UUID>/` and removes the tree
/// when the fixture dies (deinit teardown — design §9.1).
///
/// Determinism (§9.1): payloads are fixed byte constants typed by
/// EXTENSION — the honest declared-type contract of §5.2 (content bytes
/// are never sniffed; nothing here needs to be playable). A 1×1 PNG for
/// `.png`, a minimal JPEG (SOI/APP0/EOI) constant for `.jpg`, a minimal
/// ISO-BMFF `ftyp` stub for `.mp4`/`.mov`.
final class MediaFixture {
    let root: URL
    private let fileManager = FileManager.default

    init() {
        root = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        try? fileManager.createDirectory(at: root, withIntermediateDirectories: true)
    }

    deinit {
        try? fileManager.removeItem(at: root)
    }

    /// Empty subfolder under the fixture root.
    @discardableResult
    func makeDirectory(named name: String) throws -> URL {
        let url = root.appending(path: name, directoryHint: .isDirectory)
        try fileManager.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    /// Subfolder inside an existing fixture folder (e.g. a subfolder
    /// holding media that must NOT be collected, S10).
    @discardableResult
    func makeDirectory(named name: String, in parent: URL) throws -> URL {
        let url = parent.appending(path: name, directoryHint: .isDirectory)
        try fileManager.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    /// Folder pre-populated with `fileCount` media files (perf fixtures).
    @discardableResult
    func makeDirectory(named name: String, fileCount: Int) throws -> URL {
        let folder = try makeDirectory(named: name)
        for index in 0 ..< fileCount {
            try writeFile("clip-\(index).mp4", into: folder)
        }
        return folder
    }

    /// Writes a file with the fixture's deterministic typed bytes.
    @discardableResult
    func writeFile(_ name: String, bytes: [UInt8]? = nil, into folder: URL? = nil) throws -> URL {
        let url = (folder ?? root).appending(path: name)
        try Data(bytes ?? Self.bytes(for: name)).write(to: url, options: .atomic)
        return url
    }

    /// Broken symlink (destination does not exist) — the fail-open case.
    func makeBrokenSymlink(named name: String, to missingTarget: String, in folder: URL) throws {
        try fileManager.createSymbolicLink(
            at: folder.appending(path: name),
            withDestinationURL: folder.appending(path: missingTarget)
        )
    }

    /// FIFO — a non-regular special file (S11 exclusion set).
    struct FifoCreationFailure: Error {}

    func makeFifo(named name: String, in folder: URL) throws {
        let path = folder.appending(path: name).path
        guard mkfifo(path, S_IRUSR | S_IWUSR) == 0 else {
            throw FifoCreationFailure()
        }
    }

    /// Fixed typed bytes per extension (§9.1 determinism).
    static func bytes(for name: String) -> [UInt8] {
        switch name.lowercased() {
        case let lowercased where lowercased.hasSuffix(".jpg"):
            jpeg
        case let lowercased where lowercased.hasSuffix(".png"):
            png1x1
        default:
            ftyp
        }
    }

    /// Canonical 1×1 PNG.
    static let png1x1: [UInt8] = [
        0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A,
        0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52,
        0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
        0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4,
        0x89, 0x00, 0x00, 0x00, 0x0D, 0x49, 0x44, 0x41,
        0x54, 0x78, 0x9C, 0x62, 0x00, 0x01, 0x00, 0x00,
        0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00,
        0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE,
        0x42, 0x60, 0x82,
    ]

    /// Minimal JPEG constant (SOI/APP0 marker … EOI) — declared-type bytes.
    static let jpeg: [UInt8] = [
        0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10, 0x4A, 0x46,
        0x49, 0x46, 0x00, 0x01, 0x01, 0x00, 0x00, 0x01,
        0x00, 0x01, 0x00, 0x00, 0xFF, 0xD9,
    ]

    /// Minimal ISO-BMFF `ftyp` stub (size/'ftyp'/'isom'/ver/'isom'/'mp41') —
    /// the declared-type carrier; bytes need not be playable (§9.1).
    static let ftyp: [UInt8] = [
        0x00, 0x00, 0x00, 0x18, 0x66, 0x74, 0x79, 0x70,
        0x69, 0x73, 0x6F, 0x6D, 0x00, 0x00, 0x02, 0x00,
        0x69, 0x73, 0x6F, 0x6D, 0x6D, 0x70, 0x34, 0x31,
    ]
}

/// Fixture build failures surfaced as thrown errors — the fixtures fail
/// loudly but safely (no traps, no force unwraps).
enum MediaFixtureError: Error {
    case encoderNotReady
    case pixelBufferPoolUnavailable
    case pixelBufferUnavailable
    case sampleAppendFailed
    case imageContextUnavailable
    case imageDestinationUnavailable
    case encodeFailed
    case audioFormatUnavailable
    case audioBlockBufferUnavailable
    case audioSampleBufferUnavailable
}

// MARK: - Real-bytes fixtures (E2-S2 design §10.2)

extension MediaFixture {
    /// Writes a tiny real one-frame H.264 MP4 at `url` (E2-S2 design
    /// §10.2 — honest extraction needs real decodable bytes, unlike the
    /// `ftyp` stub above). One solid-color frame of the given pixel size,
    /// a thirtieth of a second long. `nonisolated`: the AVAssetWriter work
    /// runs off the main thread (the performance test bridges it from a
    /// synchronous XCTest body through a semaphore).
    nonisolated static func writeOneFrameMP4(to url: URL, pixelWidth: Int, pixelHeight: Int) async throws {
        try? FileManager.default.removeItem(at: url)
        let writer = try AVAssetWriter(outputURL: url, fileType: .mp4)
        let settings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: pixelWidth,
            AVVideoHeightKey: pixelHeight,
        ]
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: settings)
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: input,
            sourcePixelBufferAttributes: [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
                kCVPixelBufferWidthKey as String: pixelWidth,
                kCVPixelBufferHeightKey as String: pixelHeight,
            ]
        )
        writer.add(input)
        guard writer.startWriting() else { throw MediaFixtureError.encodeFailed }
        writer.startSession(atSourceTime: .zero)
        defer { input.markAsFinished() }

        guard let pool = adaptor.pixelBufferPool else { throw MediaFixtureError.pixelBufferPoolUnavailable }
        var pooled: CVPixelBuffer?
        guard CVPixelBufferPoolCreatePixelBuffer(kCFAllocatorDefault, pool, &pooled) == kCVReturnSuccess,
              let buffer = pooled else { throw MediaFixtureError.pixelBufferUnavailable }
        try fill(buffer, pixelWidth: pixelWidth, pixelHeight: pixelHeight)

        var waits = 0
        while input.isReadyForMoreMediaData == false {
            usleep(1000)
            waits += 1
            if waits > 2000 {
                throw MediaFixtureError.encoderNotReady
            }
        }
        guard adaptor.append(buffer, withPresentationTime: .zero) else { throw MediaFixtureError.sampleAppendFailed }
        writer.endSession(atSourceTime: CMTime(value: 1, timescale: 30))
        await writer.finishWriting()
        guard writer.status == .completed else { throw MediaFixtureError.encodeFailed }
    }

    /// Writes a real decodable PNG/JPEG (chosen by extension) of the given
    /// pixel size, solid-filled — a known aspect ratio with honest bytes
    /// for the ImageIO decode path. Overwrites any previous file, so the
    /// discard-cache test can swap content under one URL.
    nonisolated static func writeImage(to url: URL, pixelWidth: Int, pixelHeight: Int) throws {
        try? FileManager.default.removeItem(at: url)
        guard let context = CGContext(
            data: nil,
            width: pixelWidth,
            height: pixelHeight,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { throw MediaFixtureError.imageContextUnavailable }
        context.setFillColor(red: 0.3, green: 0.5, blue: 0.8, alpha: 1.0)
        context.fill(CGRect(x: 0, y: 0, width: pixelWidth, height: pixelHeight))
        guard let image = context.makeImage() else { throw MediaFixtureError.imageContextUnavailable }
        let typeID: CFString = switch url.pathExtension.lowercased() {
        case "jpg", "jpeg":
            UTType.jpeg.identifier as CFString
        default:
            UTType.png.identifier as CFString
        }
        guard let destination = CGImageDestinationCreateWithURL(url as CFURL, typeID, 1, nil) else {
            throw MediaFixtureError.imageDestinationUnavailable
        }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else { throw MediaFixtureError.encodeFailed }
    }

    /// One solid-gray frame drawn into a BGRA pixel buffer.
    private nonisolated static func fill(_ buffer: CVPixelBuffer, pixelWidth: Int, pixelHeight: Int) throws {
        CVPixelBufferLockBaseAddress(buffer, [])
        defer { CVPixelBufferUnlockBaseAddress(buffer, []) }
        guard let base = CVPixelBufferGetBaseAddress(buffer) else { throw MediaFixtureError.pixelBufferUnavailable }
        let context = CGContext(
            data: base,
            width: pixelWidth,
            height: pixelHeight,
            bitsPerComponent: 8,
            bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGImageByteOrderInfo.order32Little.rawValue
        )
        guard let context else { throw MediaFixtureError.imageContextUnavailable }
        context.setFillColor(gray: 0.4, alpha: 1.0)
        context.fill(CGRect(x: 0, y: 0, width: pixelWidth, height: pixelHeight))
    }

    /// Instance convenience: a real one-frame MP4 named `name` inside the
    /// fixture tree (async test bodies call this directly).
    @discardableResult
    func writeOneFrameMP4(
        named name: String = "clip.mp4",
        pixelWidth: Int,
        pixelHeight: Int,
        into folder: URL? = nil
    ) async throws -> URL {
        let url = (folder ?? root).appending(path: name)
        try await Self.writeOneFrameMP4(to: url, pixelWidth: pixelWidth, pixelHeight: pixelHeight)
        return url
    }

    /// Instance convenience: a real decodable PNG/JPEG inside the fixture
    /// tree, the format chosen by extension.
    @discardableResult
    func writeImage(
        named name: String,
        pixelWidth: Int,
        pixelHeight: Int,
        into folder: URL? = nil
    ) throws -> URL {
        let url = (folder ?? root).appending(path: name)
        try Self.writeImage(to: url, pixelWidth: pixelWidth, pixelHeight: pixelHeight)
        return url
    }
}

// MARK: - Short multi-frame clip (E2-S3 design §10.2)

extension MediaFixture {
    /// Writes a tiny real multi-frame H.264 MP4 at `url` (E2-S3 design
    /// §10.2 — the end/loop timing helper): `frameCount` solid frames at
    /// `fps`, so a started session plays to its natural end in bounded,
    /// deterministic time. Same builder shape as `writeOneFrameMP4` above;
    /// kept alongside it rather than merged (task 7.5 lands the helper,
    /// not a refactor). Retries transient VideoToolbox/AVAssetWriter
    /// failures: the gate runs test classes in parallel processes, and
    /// concurrent encoder sessions can fail a single attempt. `nonisolated`:
    /// the AVAssetWriter work runs off the main thread.
    nonisolated static func writeShortMP4(
        to url: URL,
        pixelWidth: Int,
        pixelHeight: Int,
        frameCount: Int = 6,
        fps: Int32 = 30
    ) async throws {
        var attempts = 0
        while true {
            attempts += 1
            do {
                try await writeShortMP4Attempt(
                    to: url,
                    pixelWidth: pixelWidth,
                    pixelHeight: pixelHeight,
                    frameCount: frameCount,
                    fps: fps
                )
                return
            } catch {
                guard attempts < 3 else { throw error }
                try? await Task.sleep(for: .milliseconds(250))
            }
        }
    }

    /// One encode attempt (the `writeOneFrameMP4` builder shape, looping
    /// over `frameCount` frames).
    private nonisolated static func writeShortMP4Attempt(
        to url: URL,
        pixelWidth: Int,
        pixelHeight: Int,
        frameCount: Int,
        fps: Int32
    ) async throws {
        try? FileManager.default.removeItem(at: url)
        let writer = try AVAssetWriter(outputURL: url, fileType: .mp4)
        let settings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: pixelWidth,
            AVVideoHeightKey: pixelHeight,
        ]
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: settings)
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: input,
            sourcePixelBufferAttributes: [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
                kCVPixelBufferWidthKey as String: pixelWidth,
                kCVPixelBufferHeightKey as String: pixelHeight,
            ]
        )
        writer.add(input)
        guard writer.startWriting() else { throw MediaFixtureError.encodeFailed }
        writer.startSession(atSourceTime: .zero)
        defer { input.markAsFinished() }

        guard let pool = adaptor.pixelBufferPool else { throw MediaFixtureError.pixelBufferPoolUnavailable }
        for frame in 0 ..< frameCount {
            var pooled: CVPixelBuffer?
            guard CVPixelBufferPoolCreatePixelBuffer(kCFAllocatorDefault, pool, &pooled) == kCVReturnSuccess,
                  let buffer = pooled else { throw MediaFixtureError.pixelBufferUnavailable }
            try fill(buffer, pixelWidth: pixelWidth, pixelHeight: pixelHeight)

            var waits = 0
            while input.isReadyForMoreMediaData == false {
                usleep(1000)
                waits += 1
                if waits > 2000 {
                    throw MediaFixtureError.encoderNotReady
                }
            }
            let time = CMTime(value: CMTimeValue(frame), timescale: fps)
            guard adaptor.append(buffer, withPresentationTime: time) else { throw MediaFixtureError.sampleAppendFailed }
        }
        writer.endSession(atSourceTime: CMTime(value: CMTimeValue(frameCount), timescale: fps))
        await writer.finishWriting()
        guard writer.status == .completed else { throw MediaFixtureError.encodeFailed }
    }

    /// Instance convenience: a real short multi-frame MP4 named `name`
    /// inside the fixture tree (async test bodies call this directly).
    @discardableResult
    func writeShortMP4(
        named name: String = "clip.mp4",
        pixelWidth: Int = 64,
        pixelHeight: Int = 32,
        frameCount: Int = 6,
        fps: Int32 = 30,
        into folder: URL? = nil
    ) async throws -> URL {
        let url = (folder ?? root).appending(path: name)
        try await Self.writeShortMP4(
            to: url,
            pixelWidth: pixelWidth,
            pixelHeight: pixelHeight,
            frameCount: frameCount,
            fps: fps
        )
        return url
    }
}

// MARK: - Short multi-frame clip with an audio track (E3-S2 design §10.2)

extension MediaFixture {
    /// Writes a tiny real multi-frame H.264 MP4 **with an AAC audio track**
    /// at `url` (E3-S2 design §10.2's fixture pattern: the pitch-pin rows
    /// need a session whose item really carries audio, so the pinned
    /// `audioTimePitchAlgorithm` is the algorithm that will render).
    /// Video frames are solid colors as in `writeShortMP4`; the audio
    /// track is silence — constant 16-bit mono PCM chunks appended to an
    /// AAC-encoding input (each track is chronological on its own;
    /// `AVAssetWriter` re-interleaves at finish). Same retry discipline as
    /// `writeShortMP4` (the gate runs test classes in parallel processes).
    /// `nonisolated`: the AVAssetWriter work runs off the main thread.
    nonisolated static func writeShortMP4WithAudio(
        to url: URL,
        pixelWidth: Int,
        pixelHeight: Int,
        frameCount: Int = 6,
        fps: Int32 = 30
    ) async throws {
        var attempts = 0
        while true {
            attempts += 1
            do {
                try await writeShortMP4WithAudioAttempt(
                    to: url,
                    pixelWidth: pixelWidth,
                    pixelHeight: pixelHeight,
                    frameCount: frameCount,
                    fps: fps
                )
                return
            } catch {
                // The AAC encoder contends harder than the video one under
                // the gate's parallel load (two encoders per attempt), so a
                // wider retry budget than `writeShortMP4`'s is warranted.
                guard attempts < 5 else { throw error }
                try? await Task.sleep(for: .milliseconds(250))
            }
        }
    }

    /// One encode attempt: the `writeShortMP4Attempt` builder shape plus
    /// the audio input and its silence chunks.
    private nonisolated static func writeShortMP4WithAudioAttempt(
        to url: URL,
        pixelWidth: Int,
        pixelHeight: Int,
        frameCount: Int,
        fps: Int32
    ) async throws {
        try? FileManager.default.removeItem(at: url)
        let writer = try AVAssetWriter(outputURL: url, fileType: .mp4)
        let settings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: pixelWidth,
            AVVideoHeightKey: pixelHeight,
        ]
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: settings)
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: input,
            sourcePixelBufferAttributes: [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
                kCVPixelBufferWidthKey as String: pixelWidth,
                kCVPixelBufferHeightKey as String: pixelHeight,
            ]
        )
        // The audio track: AAC, mono, 44.1 kHz — fed by constant PCM
        // silence chunks (the honest carrier for the pitch pin's item).
        let audioInput = AVAssetWriterInput(
            mediaType: .audio,
            outputSettings: [
                AVFormatIDKey: kAudioFormatMPEG4AAC,
                AVSampleRateKey: 44100,
                AVNumberOfChannelsKey: 1,
                AVEncoderBitRateKey: 64000,
            ]
        )
        writer.add(input)
        writer.add(audioInput)
        guard writer.startWriting() else { throw MediaFixtureError.encodeFailed }
        writer.startSession(atSourceTime: .zero)
        defer {
            input.markAsFinished()
            audioInput.markAsFinished()
        }

        guard let pool = adaptor.pixelBufferPool else { throw MediaFixtureError.pixelBufferPoolUnavailable }
        for frame in 0 ..< frameCount {
            var pooled: CVPixelBuffer?
            guard CVPixelBufferPoolCreatePixelBuffer(kCFAllocatorDefault, pool, &pooled) == kCVReturnSuccess,
                  let buffer = pooled else { throw MediaFixtureError.pixelBufferUnavailable }
            try fill(buffer, pixelWidth: pixelWidth, pixelHeight: pixelHeight)

            var waits = 0
            while input.isReadyForMoreMediaData == false {
                usleep(1000)
                waits += 1
                if waits > 2000 {
                    throw MediaFixtureError.encoderNotReady
                }
            }
            let time = CMTime(value: CMTimeValue(frame), timescale: fps)
            guard adaptor.append(buffer, withPresentationTime: time) else { throw MediaFixtureError.sampleAppendFailed }
        }

        // The silence chunks: 0.1 s each, covering the clip's whole video
        // duration (audio at least as long as video — the track exists and
        // renders for the clip's life).
        let sampleRate = 44100
        let chunkFrames = 4410
        let totalAudioFrames = Int((Double(frameCount) / Double(fps)) * Double(sampleRate))
        let format = try audioFormatDescription()
        var chunk = 0
        while chunk * chunkFrames < totalAudioFrames {
            let buffer = try silenceSampleBuffer(
                format: format,
                chunkFrames: chunkFrames,
                startFrame: chunk * chunkFrames,
                sampleRate: sampleRate
            )
            var waits = 0
            while audioInput.isReadyForMoreMediaData == false {
                usleep(1000)
                waits += 1
                if waits > 2000 {
                    throw MediaFixtureError.encoderNotReady
                }
            }
            guard audioInput.append(buffer) else { throw MediaFixtureError.sampleAppendFailed }
            chunk += 1
        }

        // Both tracks cover the same duration by construction — the
        // video end time is the session end.
        writer.endSession(atSourceTime: CMTime(value: CMTimeValue(frameCount), timescale: fps))
        await writer.finishWriting()
        guard writer.status == .completed else { throw MediaFixtureError.encodeFailed }
    }

    /// The PCM source format the silence chunks describe (16-bit signed
    /// mono at `sampleRate` Hz, packed — the AAC input's feed format).
    private nonisolated static func audioFormatDescription() throws -> CMAudioFormatDescription {
        var asbd = AudioStreamBasicDescription(
            mSampleRate: 44100,
            mFormatID: kAudioFormatLinearPCM,
            mFormatFlags: kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked,
            mBytesPerPacket: 2,
            mFramesPerPacket: 1,
            mBytesPerFrame: 2,
            mChannelsPerFrame: 1,
            mBitsPerChannel: 16,
            mReserved: 0
        )
        var format: CMAudioFormatDescription?
        let status = CMAudioFormatDescriptionCreate(
            allocator: kCFAllocatorDefault,
            asbd: &asbd,
            layoutSize: 0,
            layout: nil,
            magicCookieSize: 0,
            magicCookie: nil,
            extensions: nil,
            formatDescriptionOut: &format
        )
        guard status == noErr, let format else { throw MediaFixtureError.audioFormatUnavailable }
        return format
    }

    /// One chunk of 16-bit silence as a ready `CMSampleBuffer` at the
    /// chunk's presentation time.
    private nonisolated static func silenceSampleBuffer(
        format: CMAudioFormatDescription,
        chunkFrames: Int,
        startFrame: Int,
        sampleRate: Int
    ) throws -> CMSampleBuffer {
        let totalBytes = chunkFrames * 2
        var blockBuffer: CMBlockBuffer?
        let createStatus = CMBlockBufferCreateWithMemoryBlock(
            allocator: kCFAllocatorDefault,
            memoryBlock: nil,
            blockLength: totalBytes,
            blockAllocator: nil,
            customBlockSource: nil,
            offsetToData: 0,
            dataLength: totalBytes,
            flags: 0,
            blockBufferOut: &blockBuffer
        )
        guard createStatus == kCMBlockBufferNoErr, let blockBuffer else {
            throw MediaFixtureError.audioBlockBufferUnavailable
        }
        var zeros = [UInt8](repeating: 0, count: totalBytes)
        let fillStatus = CMBlockBufferReplaceDataBytes(
            with: &zeros,
            blockBuffer: blockBuffer,
            offsetIntoDestination: 0,
            dataLength: totalBytes
        )
        guard fillStatus == kCMBlockBufferNoErr else {
            throw MediaFixtureError.audioBlockBufferUnavailable
        }
        var sampleBuffer: CMSampleBuffer?
        let sampleStatus = CMAudioSampleBufferCreateWithPacketDescriptions(
            allocator: kCFAllocatorDefault,
            dataBuffer: blockBuffer,
            dataReady: true,
            makeDataReadyCallback: nil,
            refcon: nil,
            formatDescription: format,
            sampleCount: chunkFrames,
            presentationTimeStamp: CMTime(
                value: CMTimeValue(startFrame),
                timescale: CMTimeScale(sampleRate)
            ),
            packetDescriptions: nil,
            sampleBufferOut: &sampleBuffer
        )
        guard sampleStatus == noErr, let sampleBuffer else {
            throw MediaFixtureError.audioSampleBufferUnavailable
        }
        return sampleBuffer
    }

    /// Instance convenience: a real short multi-frame MP4 **with an audio
    /// track** named `name` inside the fixture tree.
    @discardableResult
    func writeShortMP4WithAudio(
        named name: String = "clip-audio.mp4",
        pixelWidth: Int = 64,
        pixelHeight: Int = 32,
        frameCount: Int = 6,
        fps: Int32 = 30,
        into folder: URL? = nil
    ) async throws -> URL {
        let url = (folder ?? root).appending(path: name)
        try await Self.writeShortMP4WithAudio(
            to: url,
            pixelWidth: pixelWidth,
            pixelHeight: pixelHeight,
            frameCount: frameCount,
            fps: fps
        )
        return url
    }
}
