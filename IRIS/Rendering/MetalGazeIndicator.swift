//
//  MetalGazeIndicator.swift
//  IRIS
//
//  Metal-accelerated gaze indicator with shader rendering
//

import SwiftUI
import Metal
import QuartzCore

// MARK: - Metal Gaze Renderer

class SimpleMetalView: NSView {
    private var metalLayer: CAMetalLayer!
    private var device: MTLDevice!
    private var commandQueue: MTLCommandQueue!
    private var pipelineState: MTLRenderPipelineState!
    private var vertexBuffer: MTLBuffer!
    private var uniformsBuffer: MTLBuffer!

    var gazePoint: CGPoint = CGPoint(x: 960, y: 540) {
        didSet {
            needsDisplay = true
        }
    }

    struct Uniforms {
        var gazePoint: SIMD2<Float>
        var screenSize: SIMD2<Float>
        var pixelScale: Float
    }

    override init(frame: NSRect) {
        super.init(frame: frame)
        setupMetal()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupMetal()
    }

    private func setupMetal() {
        wantsLayer = true

        guard let device = MTLCreateSystemDefaultDevice() else {
            print("❌ Metal not supported")
            return
        }
        self.device = device

        guard let commandQueue = device.makeCommandQueue() else {
            print("❌ Failed to create command queue")
            return
        }
        self.commandQueue = commandQueue

        metalLayer = CAMetalLayer()
        metalLayer.device = device
        metalLayer.pixelFormat = .bgra8Unorm
        metalLayer.framebufferOnly = false
        metalLayer.isOpaque = false

        layer = metalLayer

        setupPipeline()
        setupBuffers()

        print("✅ Metal renderer ready")
    }

    private func setupPipeline() {
        // Load shader library
        let libraryPath = "IRIS/Rendering/default.metallib"
        var library: MTLLibrary?

        if FileManager.default.fileExists(atPath: libraryPath) {
            do {
                library = try device.makeLibrary(filepath: libraryPath)
            } catch {
                print("⚠️ Failed to load library from file: \(error)")
            }
        }

        if library == nil {
            library = device.makeDefaultLibrary()
        }

        guard let library = library,
              let vertexFunction = library.makeFunction(name: "vertex_main"),
              let fragmentFunction = library.makeFunction(name: "fragment_main") else {
            print("❌ Failed to load shader functions")
            return
        }

        let pipelineDescriptor = MTLRenderPipelineDescriptor()
        pipelineDescriptor.vertexFunction = vertexFunction
        pipelineDescriptor.fragmentFunction = fragmentFunction
        pipelineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm

        // Enable blending for transparency
        pipelineDescriptor.colorAttachments[0].isBlendingEnabled = true
        pipelineDescriptor.colorAttachments[0].rgbBlendOperation = .add
        pipelineDescriptor.colorAttachments[0].alphaBlendOperation = .add
        pipelineDescriptor.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha
        pipelineDescriptor.colorAttachments[0].sourceAlphaBlendFactor = .sourceAlpha
        pipelineDescriptor.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
        pipelineDescriptor.colorAttachments[0].destinationAlphaBlendFactor = .oneMinusSourceAlpha

        // Vertex descriptor
        let vertexDescriptor = MTLVertexDescriptor()
        vertexDescriptor.attributes[0].format = .float2
        vertexDescriptor.attributes[0].offset = 0
        vertexDescriptor.attributes[0].bufferIndex = 0
        vertexDescriptor.layouts[0].stride = MemoryLayout<SIMD2<Float>>.stride
        pipelineDescriptor.vertexDescriptor = vertexDescriptor

        do {
            pipelineState = try device.makeRenderPipelineState(descriptor: pipelineDescriptor)
        } catch {
            print("❌ Failed to create pipeline: \(error)")
        }
    }

    private func setupBuffers() {
        // Quad vertices (-1 to 1)
        let vertices: [SIMD2<Float>] = [
            SIMD2<Float>(-1.0, -1.0),
            SIMD2<Float>( 1.0, -1.0),
            SIMD2<Float>(-1.0,  1.0),
            SIMD2<Float>( 1.0, -1.0),
            SIMD2<Float>( 1.0,  1.0),
            SIMD2<Float>(-1.0,  1.0),
        ]

        vertexBuffer = device.makeBuffer(
            bytes: vertices,
            length: vertices.count * MemoryLayout<SIMD2<Float>>.stride,
            options: .storageModeShared
        )

        // Uniforms buffer
        var uniforms = Uniforms(
            gazePoint: SIMD2<Float>(960, 540),
            screenSize: SIMD2<Float>(1920, 1080),
            pixelScale: 1.0
        )
        uniformsBuffer = device.makeBuffer(
            bytes: &uniforms,
            length: MemoryLayout<Uniforms>.stride,
            options: .storageModeShared
        )
    }

    override func layout() {
        super.layout()
        metalLayer?.frame = bounds
        metalLayer?.drawableSize = CGSize(
            width: bounds.width * (window?.backingScaleFactor ?? 1.0),
            height: bounds.height * (window?.backingScaleFactor ?? 1.0)
        )
    }

    override var wantsUpdateLayer: Bool { true }

    override func updateLayer() {
        render()
    }

    func render() {
        guard let metalLayer = metalLayer,
              let drawable = metalLayer.nextDrawable(),
              let pipelineState = pipelineState else {
            return
        }

        // Update uniforms
        var uniforms = Uniforms(
            gazePoint: SIMD2<Float>(Float(gazePoint.x), Float(gazePoint.y)),
            screenSize: SIMD2<Float>(Float(bounds.width), Float(bounds.height)),
            pixelScale: Float(window?.backingScaleFactor ?? 1.0)
        )

        uniformsBuffer?.contents().copyMemory(
            from: &uniforms,
            byteCount: MemoryLayout<Uniforms>.stride
        )

        // Render
        let renderPassDescriptor = MTLRenderPassDescriptor()
        renderPassDescriptor.colorAttachments[0].texture = drawable.texture
        renderPassDescriptor.colorAttachments[0].loadAction = .clear
        renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 0)
        renderPassDescriptor.colorAttachments[0].storeAction = .store

        guard let commandBuffer = commandQueue.makeCommandBuffer(),
              let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else {
            return
        }

        encoder.setRenderPipelineState(pipelineState)
        encoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
        encoder.setVertexBuffer(uniformsBuffer, offset: 0, index: 1)

        // Draw 4 instances (4 circles)
        encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6, instanceCount: 4)

        encoder.endEncoding()
        commandBuffer.present(drawable)
        commandBuffer.commit()
    }
}

// MARK: - SwiftUI Wrapper

struct MetalGazeIndicatorView: NSViewRepresentable {
    let gazePoint: CGPoint

    func makeNSView(context: Context) -> SimpleMetalView {
        let view = SimpleMetalView(frame: .zero)

        // Set up timer for continuous rendering at 60 FPS
        context.coordinator.timer = Timer.scheduledTimer(withTimeInterval: 1.0/60.0, repeats: true) { _ in
            view.render()
        }

        return view
    }

    func updateNSView(_ nsView: SimpleMetalView, context: Context) {
        nsView.gazePoint = gazePoint
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    class Coordinator {
        var timer: Timer?

        deinit {
            timer?.invalidate()
        }
    }
}

// MARK: - Preview

#if DEBUG
struct MetalGazeIndicatorView_Previews: PreviewProvider {
    static var previews: some View {
        MetalGazeIndicatorView(gazePoint: CGPoint(x: 400, y: 300))
            .frame(width: 800, height: 600)
    }
}
#endif
