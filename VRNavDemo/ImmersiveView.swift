//  ImmersiveView.swift
//  VRNavDemo
//  Created by Steve Talkowski on 7/17/25.

//
//  ImmersiveView.swift
//  VRNavDemo
//
//  Created by Steve Talkowski on 7/17/25.
//

import SwiftUI
import RealityKit
import RealityKitContent
import GameController
import Combine

struct ImmersiveView: View {
    @State private var controller: GCController?
    @State private var cameraController = CameraController()
    @State private var sceneRoot: Entity?
    @State private var teleportIndicator = ModelEntity()
//    MARK: Here we create the Tick
    @State private var timer = Timer.publish(every: 1.0 / 60.0, on: .main, in: .common).autoconnect()

    // Snap rotation and teleportation settings
    let snapRotationAngle: Float = .pi / 6 // 30 degrees
    let teleportDistance: Float = 1.0
    @State private var lastRightX: Float = 0
    @State private var lastRightY: Float = 0
    
    private func setupImmersiveScene(content: RealityViewContent) async {
        do {
            let immersiveScene = try await Entity(named: "Immersive", in: realityKitContentBundle)
            immersiveScene.name = "SceneRoot"
            content.add(immersiveScene)
            self.sceneRoot = immersiveScene

            let circleMesh = MeshResource.generateCylinder(height: 0.001, radius: 0.2)
            let circleMaterial = UnlitMaterial(color: UIColor.cyan.withAlphaComponent(0.4))
            self.teleportIndicator.model = ModelComponent(mesh: circleMesh, materials: [circleMaterial])
            self.teleportIndicator.isEnabled = false
            immersiveScene.addChild(self.teleportIndicator)

            print("✅ Immersive scene loaded")
        } catch {
            print("❌ Failed to load immersive scene: \(error)")
        }
    }

    var body: some View {
        RealityView { content in
            await self.setupImmersiveScene(content: content)
        }
        .onAppear {
            NotificationCenter.default.addObserver(forName: .GCControllerDidConnect, object: nil, queue: .main) { notification in
                if let newController = notification.object as? GCController {
                    self.controller = newController
                    print("✅ Controller connected: \(newController.vendorName ?? "Unknown")")
                }
            }
            GCController.startWirelessControllerDiscovery(completionHandler: nil)
        }
//        MARK: here we are reacting to the Tick
        .onReceive(timer) { _ in
            guard let controller = controller,
                  let gamepad = controller.extendedGamepad,
                  let sceneRoot = sceneRoot else { return }
            
            func facebuttonPressed(for controller: GCController) {
                controller.extendedGamepad?.allButtons.forEach { key in
                    if key.isPressed {
                        print("key pressed: \(key)")
                    }
                }
            }
            facebuttonPressed(for: controller)
            let leftX = gamepad.leftThumbstick.xAxis.value
            let leftY = gamepad.leftThumbstick.yAxis.value
            let rightX = gamepad.rightThumbstick.xAxis.value
            let rightY = gamepad.rightThumbstick.yAxis.value

            // Snap rotation
            if abs(rightX) > 0.7 && abs(lastRightX) < 0.7 {
                cameraController.yaw -= rightX > 0 ? snapRotationAngle : -snapRotationAngle
            }
            lastRightX = rightX

            // Snap teleportation (pull back to teleport forward)
            if rightY < -0.7 && lastRightY >= -0.7 {
                let yawQuat = simd_quatf(angle: cameraController.yaw, axis: [0, 1, 0])
                let forward = yawQuat.act(SIMD3<Float>(0, 0, -1))
                let target = cameraController.position + forward * teleportDistance
                cameraController.position = target
                print("🚀 Teleported to: \(target)")
            }
            lastRightY = rightY

            // Continuous movement
            let yawQuat = simd_quatf(angle: cameraController.yaw, axis: [0, 1, 0])
            let forward = yawQuat.act(SIMD3<Float>(0, 0, -1))
            let right = yawQuat.act(SIMD3<Float>(1, 0, 0))
            let movement = (leftY * forward + leftX * right) * 0.05
            cameraController.position += movement

            // Update scene position/rotation (move world instead of camera)
            let cameraTransform = matrix_multiply(
                float4x4(translation: cameraController.position),
                float4x4(rotation: yawQuat)
            )
            sceneRoot.transform.matrix = cameraTransform.inverse

            // Update teleport indicator if pulling back
            if rightY < -0.7 {
                let previewTarget = cameraController.position + forward * teleportDistance
                teleportIndicator.transform.translation = previewTarget
                teleportIndicator.isEnabled = true
            } else {
                teleportIndicator.isEnabled = false
            }
//            print("🎮 pos=\(cameraController.position) yaw=\(cameraController.yaw)") // causing to much output
            
        }
    }
}

struct CameraController {
    var position: SIMD3<Float> = [0, 0, 0]
    var yaw: Float = 0
}

import simd

extension float4x4 {
    init(translation t: SIMD3<Float>) {
        self = matrix_identity_float4x4
        columns.3 = SIMD4<Float>(t.x, t.y, t.z, 1)
    }

    init(rotation r: simd_quatf) {
        self = matrix_float4x4(r)
    }
}
