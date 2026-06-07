//
//  ImageCompressor.swift
//  Haliable
//
//  Compress photos BEFORE upload. Supabase Storage on the free tier is only
//  1 GB, so we cap the longest edge at 1600px and encode JPEG at ~0.6 quality.
//  A typical product photo drops from several MB to ~150–300 KB.
//

import UIKit

enum ImageCompressor {
    static func compressedJPEG(_ image: UIImage,
                               maxDimension: CGFloat = 1600,
                               quality: CGFloat = 0.6) -> Data? {
        let resized = resize(image, maxDimension: maxDimension)
        return resized.jpegData(compressionQuality: quality)
    }

    private static func resize(_ image: UIImage, maxDimension: CGFloat) -> UIImage {
        let size = image.size
        let longest = max(size.width, size.height)
        guard longest > maxDimension else { return image }

        let scale = maxDimension / longest
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1   // we want pixel dimensions, not @2x/@3x
        let renderer = UIGraphicsImageRenderer(size: newSize, format: format)
        return renderer.image { _ in image.draw(in: CGRect(origin: .zero, size: newSize)) }
    }
}
