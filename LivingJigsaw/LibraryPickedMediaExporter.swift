import AVFoundation
import CoreImage
import CoreTransferable
import Foundation
import PhotosUI
import SwiftUI
import UIKit
import UniformTypeIdentifiers

enum LibraryPickedMediaExportError: LocalizedError {
    case unsupportedKind
    case transferFailed(String)

    var errorDescription: String? {
        switch self {
        case .unsupportedKind:
            return String(localized: "home_pick_media_unsupported")
        case .transferFailed(let s):
            return s
        }
    }
}

/// Xuất `PhotosPickerItem` → file URL dùng được với `AVPlayer` (video copy; ảnh → MP4 tĩnh ngắn).
enum LibraryPickedMediaExporter {
    static func exportToTempVideoURL(from item: PhotosPickerItem) async throws -> URL {
        // Thử load video trực tiếp
        if let v = try? await item.loadTransferable(type: ImportedVideoMovie.self) {
            return try await reexportVideoWithCorrectOrientation(v.url)
        }
        if let v = try? await item.loadTransferable(type: ImportedVideoMPEG4.self) {
            return try await reexportVideoWithCorrectOrientation(v.url)
        }
        if let v = try? await item.loadTransferable(type: ImportedVideoQuickTime.self) {
            return try await reexportVideoWithCorrectOrientation(v.url)
        }
        
        // Ảnh → video tĩnh
        if let img = try? await item.loadTransferable(type: ImportedRasterImage.self) {
            return try await StillImageVideoExporter.writeShortLoopVideo(from: img.uiImage, durationSeconds: 3)
        }
        if let data = try? await item.loadTransferable(type: Data.self),
           let ui = UIImage(data: data) {
            return try await StillImageVideoExporter.writeShortLoopVideo(from: ui, durationSeconds: 3)
        }
        throw LibraryPickedMediaExportError.unsupportedKind
    }
    
    /// Re-export video với preferredTransform được áp dụng để orientation luôn đúng
    private static func reexportVideoWithCorrectOrientation(_ sourceURL: URL) async throws -> URL {
        let asset = AVURLAsset(url: sourceURL)
        
        // Kiểm tra xem video có cần transform không
        let tracks = try await asset.load(.tracks)
        guard let videoTrack = tracks.first(where: { $0.mediaType == .video }) else {
            // Không có video track, return nguyên file
            return sourceURL
        }
        
        let transform = try await videoTrack.load(.preferredTransform)
        let naturalSize = try await videoTrack.load(.naturalSize)
        
        // Cần re-export với orientation đúng
        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("oriented-\(UUID().uuidString).mp4", isDirectory: false)
        
        if FileManager.default.fileExists(atPath: outputURL.path) {
            try? FileManager.default.removeItem(at: outputURL)
        }
        
        guard let exportSession = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetHighestQuality) else {
            throw LibraryPickedMediaExportError.transferFailed("Cannot create export session")
        }
        
        exportSession.outputURL = outputURL
        exportSession.outputFileType = .mp4
        exportSession.shouldOptimizeForNetworkUse = true
        
        // Video composition: đưa khung đã xoay về gốc (0,0) — chỉ `setTransform(preferred)` dễ bị lệch/clipping khi origin âm.
        let videoComposition = AVMutableVideoComposition()
        let rawTransformed = CGRect(origin: .zero, size: naturalSize).applying(transform)
        let renderW = abs(rawTransformed.width)
        let renderH = abs(rawTransformed.height)
        videoComposition.renderSize = CGSize(width: renderW, height: renderH)
        videoComposition.frameDuration = CMTime(value: 1, timescale: 30)
        
        let instruction = AVMutableVideoCompositionInstruction()
        instruction.timeRange = CMTimeRange(start: .zero, duration: try await asset.load(.duration))
        
        let layerInstruction = AVMutableVideoCompositionLayerInstruction(assetTrack: videoTrack)
        let normalizeOrigin = CGAffineTransform(translationX: -rawTransformed.origin.x, y: -rawTransformed.origin.y)
        // `normalize.concatenating(transform)` * p = normalize * (transform * p)
        let exportTransform = normalizeOrigin.concatenating(transform)
        layerInstruction.setTransform(exportTransform, at: .zero)
        
        instruction.layerInstructions = [layerInstruction]
        videoComposition.instructions = [instruction]
        
        exportSession.videoComposition = videoComposition
        
        await exportSession.export()
        
        switch exportSession.status {
        case .completed:
            return outputURL
        case .failed:
            throw LibraryPickedMediaExportError.transferFailed(
                exportSession.error?.localizedDescription ?? "Export failed"
            )
        case .cancelled:
            throw LibraryPickedMediaExportError.transferFailed("Export cancelled")
        default:
            throw LibraryPickedMediaExportError.transferFailed("Export unknown error")
        }
    }
}

// MARK: - Transferable (PhotosPicker → file / UIImage)

private func copyPickedMediaToTemp(_ src: URL, defaultExt: String) throws -> URL {
    let ext = src.pathExtension.isEmpty ? defaultExt : src.pathExtension
    let dest = FileManager.default.temporaryDirectory.appendingPathComponent("lib-\(UUID().uuidString).\(ext)", isDirectory: false)
    if FileManager.default.fileExists(atPath: dest.path) {
        try? FileManager.default.removeItem(at: dest)
    }
    try FileManager.default.copyItem(at: src, to: dest)
    return dest
}

private struct ImportedVideoMovie: Transferable {
    let url: URL
    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(importedContentType: .movie) { received in
            ImportedVideoMovie(url: try copyPickedMediaToTemp(received.file, defaultExt: "mov"))
        }
    }
}

private struct ImportedVideoMPEG4: Transferable {
    let url: URL
    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(importedContentType: .mpeg4Movie) { received in
            ImportedVideoMPEG4(url: try copyPickedMediaToTemp(received.file, defaultExt: "mp4"))
        }
    }
}

private struct ImportedVideoQuickTime: Transferable {
    let url: URL
    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(importedContentType: .quickTimeMovie) { received in
            ImportedVideoQuickTime(url: try copyPickedMediaToTemp(received.file, defaultExt: "mov"))
        }
    }
}

private struct ImportedRasterImage: Transferable {
    let uiImage: UIImage
    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(importedContentType: .image) { received in
            guard let ui = UIImage(contentsOfFile: received.file.path) else {
                throw LibraryPickedMediaExportError.unsupportedKind
            }
            return ImportedRasterImage(uiImage: ui)
        }
    }
}

// MARK: - Ảnh → MP4 (một khung lặp)

private enum StillImageVideoExporter {
    enum ExportError: LocalizedError {
        case noImage
        case writerFailed
        case encodingFailed(Error?)

        var errorDescription: String? {
            switch self {
            case .noImage: return String(localized: "home_pick_media_unsupported")
            case .writerFailed: return String(localized: "home_pick_media_failed")
            case .encodingFailed(let e): return e?.localizedDescription ?? String(localized: "home_pick_media_failed")
            }
        }
    }

    static func writeShortLoopVideo(from image: UIImage, durationSeconds: Double = 3) async throws -> URL {
        let normalized = normalizedUpImage(image)
        guard let cg = scaledEvenCGImage(from: normalized) else { throw ExportError.noImage }
        let w = cg.width
        let h = cg.height
        let out = FileManager.default.temporaryDirectory.appendingPathComponent("libstill-\(UUID().uuidString).mp4", isDirectory: false)
        if FileManager.default.fileExists(atPath: out.path) {
            try? FileManager.default.removeItem(at: out)
        }

        let writer = try AVAssetWriter(outputURL: out, fileType: .mp4)
        let settings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: w,
            AVVideoHeightKey: h,
            AVVideoCompressionPropertiesKey: [
                AVVideoAverageBitRateKey: w * h * 2,
                AVVideoProfileLevelKey: AVVideoProfileLevelH264BaselineAutoLevel
            ] as [String: Any]
        ]
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: settings)
        input.expectsMediaDataInRealTime = false
        let attrs: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA),
            kCVPixelBufferWidthKey as String: w,
            kCVPixelBufferHeightKey as String: h,
            kCVPixelBufferCGImageCompatibilityKey as String: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey as String: true
        ]
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: attrs)
        guard writer.canAdd(input) else { throw ExportError.writerFailed }
        writer.add(input)
        guard writer.startWriting() else { throw writer.error ?? ExportError.writerFailed }
        writer.startSession(atSourceTime: .zero)

        guard let pixelBuffer = makePixelBuffer(from: cg, width: w, height: h) else { throw ExportError.noImage }

        let fps: Int32 = 30
        let frameCount = max(1, Int(durationSeconds * Double(fps)))
        let frameDuration = CMTime(value: 1, timescale: fps)

        for i in 0..<frameCount {
            let t = CMTimeMultiply(frameDuration, multiplier: Int32(i))
            var waited = 0
            while !input.isReadyForMoreMediaData {
                try await Task.sleep(nanoseconds: 2_000_000)
                waited += 1
                if waited > 500 { throw ExportError.encodingFailed(nil) }
            }
            guard adaptor.append(pixelBuffer, withPresentationTime: t) else {
                throw ExportError.encodingFailed(writer.error)
            }
        }
        input.markAsFinished()
        await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
            writer.finishWriting {
                cont.resume()
            }
        }
        if writer.status == .failed {
            throw ExportError.encodingFailed(writer.error)
        }
        return out
    }

    private static func scaledEvenCGImage(from image: UIImage) -> CGImage? {
        let maxLong: CGFloat = 1080
        let iw = image.size.width * image.scale
        let ih = image.size.height * image.scale
        let scale = min(1, maxLong / max(iw, ih, 1))
        var tw = Int((iw * scale) / 2) * 2
        var th = Int((ih * scale) / 2) * 2
        tw = max(tw, 32)
        th = max(th, 32)
        let r = UIGraphicsImageRenderer(size: CGSize(width: tw, height: th))
        let out = r.image { _ in
            image.draw(in: CGRect(x: 0, y: 0, width: tw, height: th))
        }
        return out.cgImage
    }

    /// Chuẩn hóa orientation metadata về pixel `.up` để tránh xuất MP4 bị quay ngang.
    private static func normalizedUpImage(_ image: UIImage) -> UIImage {
        if image.imageOrientation == .up { return image }
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = image.scale
        let renderer = UIGraphicsImageRenderer(size: image.size, format: format)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: image.size))
        }
    }

    private static func makePixelBuffer(from cgImage: CGImage, width: Int, height: Int) -> CVPixelBuffer? {
        var optionalBuffer: CVPixelBuffer?
        CVPixelBufferCreate(
            kCFAllocatorDefault,
            width,
            height,
            kCVPixelFormatType_32BGRA,
            [
                kCVPixelBufferCGImageCompatibilityKey as String: true,
                kCVPixelBufferCGBitmapContextCompatibilityKey as String: true
            ] as CFDictionary,
            &optionalBuffer
        )
        guard let buffer = optionalBuffer else { return nil }
        let ci = CIImage(cgImage: cgImage)
        let ctx = CIContext(options: [.useSoftwareRenderer: false])
        ctx.render(ci, to: buffer, bounds: CGRect(x: 0, y: 0, width: width, height: height), colorSpace: CGColorSpaceCreateDeviceRGB())
        return buffer
    }
}
