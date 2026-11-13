import SwiftUI

/// Live preview of the first selected image inside the target frame.
/// The dashed frame is the box you asked for; in Fit mode the image
/// can be smaller than it, in Fill mode the image covers it and the
/// overflow is cropped.
struct ResizePreviewView: View {
    let image: UIImage?
    let target: CGSize
    let output: CGSize
    let mode: ResizeMode

    private let maxHeight: CGFloat = 260

    var body: some View {
        VStack(spacing: AppSpacing.sm) {
            GeometryReader { proxy in
                let box = frameSize(in: proxy.size)
                ZStack {
                    RoundedRectangle(cornerRadius: AppRadius.small, style: .continuous)
                        .strokeBorder(AppColors.accent.opacity(0.6), style: StrokeStyle(lineWidth: 1.5, dash: [6, 4]))
                        .frame(width: box.width, height: box.height)

                    if let image {
                        previewImage(image, box: box)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .animation(.snappy, value: target)
                .animation(.snappy, value: mode)
            }
            .frame(height: maxHeight)

            Text("Output: \(output.pixelDescription) px")
                .appSecondary()
                .contentTransition(.numericText())
                .animation(.snappy, value: output.pixelDescription)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Preview")
        .accessibilityValue("Output \(output.pixelDescription) pixels, \(mode.rawValue) mode")
    }

    @ViewBuilder
    private func previewImage(_ image: UIImage, box: CGSize) -> some View {
        switch mode {
        case .fill:
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: box.width, height: box.height)
                .clipShape(RoundedRectangle(cornerRadius: AppRadius.small, style: .continuous))
        case .fit:
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .frame(width: box.width, height: box.height)
                .clipShape(RoundedRectangle(cornerRadius: AppRadius.small, style: .continuous))
        }
    }

    /// The target aspect ratio scaled to fit the preview area.
    private func frameSize(in available: CGSize) -> CGSize {
        guard target.width > 0, target.height > 0 else { return .zero }
        let scale = min(available.width / target.width, maxHeight / target.height)
        return CGSize(width: target.width * scale, height: target.height * scale)
    }
}
