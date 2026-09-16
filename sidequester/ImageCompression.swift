import UIKit

/// Shared helper so every photo upload (activity proof, profile picture)
/// gets resized and compressed before it hits Firebase Storage — cuts
/// upload time and storage cost, especially for full-res camera photos.
enum ImageCompression {
    static func compress(_ image: UIImage, maxDimension: CGFloat = 1600, quality: CGFloat = 0.7) -> Data? {
        resize(image, maxDimension: maxDimension).jpegData(compressionQuality: quality)
    }

    private static func resize(_ image: UIImage, maxDimension: CGFloat) -> UIImage {
        let size = image.size
        let largestSide = max(size.width, size.height)
        guard largestSide > maxDimension else { return image }

        let scale = maxDimension / largestSide
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)

        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}
