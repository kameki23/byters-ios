import SwiftUI

struct ImageCropperView: View {
    let image: UIImage
    let onCropped: (UIImage) -> Void
    let onCancel: () -> Void

    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero

    var body: some View {
        GeometryReader { geometry in
            let cropSize = min(geometry.size.width, geometry.size.height) * 0.8

            ZStack {
                Color.black.ignoresSafeArea()

                // Image layer
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: cropSize, height: cropSize)
                    .scaleEffect(scale)
                    .offset(offset)
                    .gesture(
                        SimultaneousGesture(
                            MagnificationGesture()
                                .onChanged { value in
                                    let newScale = lastScale * value
                                    scale = min(max(newScale, 1.0), 5.0)
                                }
                                .onEnded { _ in
                                    lastScale = scale
                                },
                            DragGesture()
                                .onChanged { value in
                                    offset = CGSize(
                                        width: lastOffset.width + value.translation.width,
                                        height: lastOffset.height + value.translation.height
                                    )
                                }
                                .onEnded { _ in
                                    lastOffset = offset
                                }
                        )
                    )
                    .clipShape(Circle())

                // Overlay mask with circular cutout
                CropOverlay(cropSize: cropSize)
                    .allowsHitTesting(false)

                // Buttons
                VStack {
                    Spacer()
                    HStack(spacing: 40) {
                        Button {
                            onCancel()
                        } label: {
                            Text("キャンセル")
                                .font(.body.weight(.medium))
                                .foregroundColor(.white)
                                .padding(.horizontal, 24)
                                .padding(.vertical, 12)
                                .background(Color.white.opacity(0.2))
                                .cornerRadius(8)
                        }

                        Button {
                            let cropped = cropImage(
                                image: image,
                                cropSize: cropSize,
                                viewSize: geometry.size,
                                scale: scale,
                                offset: offset
                            )
                            onCropped(cropped ?? image)
                        } label: {
                            Text("使用する")
                                .font(.body.weight(.bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 24)
                                .padding(.vertical, 12)
                                .background(Color.blue)
                                .cornerRadius(8)
                        }
                    }
                    .padding(.bottom, 40)
                }
            }
        }
    }

    // MARK: - Crop Logic

    private func cropImage(
        image: UIImage,
        cropSize: CGFloat,
        viewSize: CGSize,
        scale: CGFloat,
        offset: CGSize
    ) -> UIImage? {
        let imageSize = image.size
        _ = cropSize * scale
        _ = cropSize * scale

        // Determine the scale factor between displayed image and actual image
        let imageAspect = imageSize.width / imageSize.height
        let displayAspect: CGFloat = 1.0 // square crop area

        let scaleFactor: CGFloat
        if imageAspect > displayAspect {
            // Image is wider: height fills crop area
            scaleFactor = imageSize.height / (cropSize / scale)
        } else {
            // Image is taller: width fills crop area
            scaleFactor = imageSize.width / (cropSize / scale)
        }

        // Calculate the crop rect in image coordinates
        let centerX = imageSize.width / 2 - offset.width * scaleFactor
        let centerY = imageSize.height / 2 - offset.height * scaleFactor
        let cropRectSize = cropSize * scaleFactor / scale

        let cropRect = CGRect(
            x: centerX - cropRectSize / 2,
            y: centerY - cropRectSize / 2,
            width: cropRectSize,
            height: cropRectSize
        )

        // Clamp to image bounds
        let clampedRect = cropRect.intersection(CGRect(origin: .zero, size: imageSize))

        guard let cgImage = image.cgImage?.cropping(to: clampedRect) else {
            return nil
        }

        // Render as circular
        let outputSize: CGFloat = 600
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: outputSize, height: outputSize))
        return renderer.image { context in
            let rect = CGRect(origin: .zero, size: CGSize(width: outputSize, height: outputSize))
            UIBezierPath(ovalIn: rect).addClip()
            UIImage(cgImage: cgImage, scale: image.scale, orientation: image.imageOrientation)
                .draw(in: rect)
        }
    }
}

// MARK: - CropOverlay

private struct CropOverlay: View {
    let cropSize: CGFloat

    var body: some View {
        GeometryReader { geometry in
            Canvas { context, size in
                // Fill entire area with semi-transparent black
                context.fill(
                    Path(CGRect(origin: .zero, size: size)),
                    with: .color(.black.opacity(0.6))
                )

                // Cut out circular area
                let center = CGPoint(x: size.width / 2, y: size.height / 2)
                let circlePath = Path(ellipseIn: CGRect(
                    x: center.x - cropSize / 2,
                    y: center.y - cropSize / 2,
                    width: cropSize,
                    height: cropSize
                ))
                context.blendMode = .destinationOut
                context.fill(circlePath, with: .color(.white))
            }
            .compositingGroup()

            // Circle border
            Circle()
                .stroke(Color.white.opacity(0.8), lineWidth: 1.5)
                .frame(width: cropSize, height: cropSize)
                .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
        }
    }
}
