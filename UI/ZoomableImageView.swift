import SwiftUI
import UIKit

/// Pinch-zoom + pan + double-tap-toggle image viewer.
///
/// 默认 fit-to-bounds；pinch 上限 = 4×；双击在 fit 与 2.5× fit 之间切换。
/// 用 UIScrollView 而非 SwiftUI 手势实现 —— 滚动/缩放边界、惯性、橡皮筋都更稳。
///
/// 实现细节：自定义 `CenteringScrollView` 子类，在 `layoutSubviews` 中当
/// bounds size 变化时回调 recenter —— 解决首次显示时 bounds 还没 layout、
/// `fit` 算成 0、imageView 被 zoom-to-zero 卡在左上角的问题。
struct ZoomableImageView: UIViewRepresentable {
    let image: UIImage

    func makeUIView(context: Context) -> CenteringScrollView {
        let scrollView = CenteringScrollView()
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

        scrollView.onBoundsSizeChange = { [weak scrollView] _ in
            guard let scrollView else { return }
            context.coordinator.recenter(in: scrollView)
        }

        context.coordinator.imageView = imageView
        return scrollView
    }

    func updateUIView(_ scrollView: CenteringScrollView, context: Context) {
        guard let imageView = context.coordinator.imageView,
              let image = imageView.image else { return }
        imageView.frame = CGRect(origin: .zero, size: image.size)
        scrollView.contentSize = image.size
        // updateUIView 自身不主动 recenter —— 让 layoutSubviews 的
        // onBoundsSizeChange 来统一驱动，避免重复计算
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
            guard bounds.width > 0, bounds.height > 0 else { return }
            let imageSize = image.size
            let widthScale = bounds.width / imageSize.width
            let heightScale = bounds.height / imageSize.height
            let fit = min(widthScale, heightScale)
            scrollView.minimumZoomScale = fit
            scrollView.maximumZoomScale = fit * 4
            if scrollView.zoomScale < fit {
                scrollView.zoomScale = fit
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

/// UIScrollView 子类 —— 把 bounds size 变化回调给宿主，
/// 确保 image 在首次 layout 后立即居中并启用缩放。
///
/// 实现要点：`layoutSubviews()` 被调用时 bounds 已经被父视图布局成新值，
/// 所以"读 bounds → 比 oldSize"会错过首次变化。改为在实例上保存上一次
/// 报告的 size，下次 layoutSubviews 时与当前 bounds 比较。
final class CenteringScrollView: UIScrollView {
    var onBoundsSizeChange: ((CGRect) -> Void)?
    private var lastReportedSize: CGSize = .zero

    override func layoutSubviews() {
        super.layoutSubviews()
        if lastReportedSize != bounds.size, bounds.width > 0 {
            lastReportedSize = bounds.size
            onBoundsSizeChange?(bounds)
        }
    }
}