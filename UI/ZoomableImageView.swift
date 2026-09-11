import SwiftUI
import UIKit

/// Pinch-zoom + pan + double-tap-toggle image viewer.
///
/// 默认 fit-to-bounds；pinch 上限 = 4×；双击在 fit 与 2.5× fit 之间切换。
/// 用 UIScrollView 而非 SwiftUI 手势实现 —— 滚动/缩放边界、惯性、橡皮筋都更稳。
struct ZoomableImageView: UIViewRepresentable {
    let image: UIImage

    func makeUIView(context: Context) -> UIScrollView {
        let scrollView = UIScrollView()
        scrollView.delegate = context.coordinator
        scrollView.bouncesZoom = true
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.showsVerticalScrollIndicator = false
        scrollView.backgroundColor = .clear
        scrollView.contentInsetAdjustmentBehavior = .never
        scrollView.maximumZoomScale = 4.0

        let imageView = UIImageView(image: image)
        imageView.contentMode = .scaleAspectFit
        imageView.isUserInteractionEnabled = true
        scrollView.addSubview(imageView)

        let doubleTap = UITapGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handleDoubleTap(_:))
        )
        doubleTap.numberOfTapsRequired = 2
        scrollView.addGestureRecognizer(doubleTap)

        context.coordinator.imageView = imageView
        return scrollView
    }

    func updateUIView(_ scrollView: UIScrollView, context: Context) {
        guard let imageView = context.coordinator.imageView,
              let image = imageView.image else { return }
        imageView.frame = CGRect(origin: .zero, size: image.size)
        scrollView.contentSize = image.size
        context.coordinator.recenter(in: scrollView)
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator: NSObject, UIScrollViewDelegate {
        weak var imageView: UIImageView?

        func viewForZooming(in scrollView: UIScrollView) -> UIView? { imageView }

        func scrollViewDidZoom(_ scrollView: UIScrollView) { recenter(in: scrollView) }

        /// 让缩放后的图片始终在 scroll view 居中（横向/纵向）
        func recenter(in scrollView: UIScrollView) {
            guard let imageView, let image = imageView.image else { return }
            let bounds = scrollView.bounds
            let imageSize = image.size
            let widthScale = bounds.width / imageSize.width
            let heightScale = bounds.height / imageSize.height
            let fit = min(widthScale, heightScale)
            if scrollView.minimumZoomScale != fit {
                scrollView.minimumZoomScale = fit
                scrollView.maximumZoomScale = fit * 4
                if scrollView.zoomScale < fit {
                    scrollView.zoomScale = fit
                }
            }
            let scaled = CGSize(
                width: imageSize.width * scrollView.zoomScale,
                height: imageSize.height * scrollView.zoomScale
            )
            let xInset = max(0, (bounds.width - scaled.width) / 2)
            let yInset = max(0, (bounds.height - scaled.height) / 2)
            scrollView.contentInset = UIEdgeInsets(top: yInset, left: xInset, bottom: yInset, right: xInset)
        }

        @objc func handleDoubleTap(_ gesture: UITapGestureRecognizer) {
            guard let scrollView = imageView?.superview as? UIScrollView else { return }
            if scrollView.zoomScale > scrollView.minimumZoomScale + 0.01 {
                scrollView.setZoomScale(scrollView.minimumZoomScale, animated: true)
            } else {
                let target = min(scrollView.maximumZoomScale, scrollView.minimumZoomScale * 2.5)
                scrollView.setZoomScale(target, animated: true)
            }
        }
    }
}