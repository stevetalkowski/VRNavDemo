//
//  GamepadInputHandler.swift
//  RealityKitContent
//
//  Created by Steve Talkowski on 7/17/25.
//
import Foundation
import GameController
import simd
import Combine

class GamepadInputHandler: ObservableObject {
    
    @Published private(set) var move = SIMD3<Float>(repeating: 0)
    @Published private(set) var look = SIMD2<Float>(repeating: 0)

    func updateMove(_ newMove: SIMD3<Float>) {
        DispatchQueue.main.async {
            self.move = newMove
            self.objectWillChange.send()
        }
    }

    func updateLook(_ newLook: SIMD2<Float>) {
        DispatchQueue.main.async {
            self.look = newLook
            self.objectWillChange.send()
        }
    }
    private var controllerObserver: Any?

    init() {
        controllerObserver = NotificationCenter.default.addObserver(
            forName: .GCControllerDidConnect,
            object: nil,
            queue: .main
        ) { _ in
            self.setupControllerObservers()
        }

        // Setup immediately if a controller is already connected
        if let controller = GCController.controllers().first {
            setupObservers(for: controller)
        }
    }

    private func setupControllerObservers() {
        for controller in GCController.controllers() {
            setupObservers(for: controller)
        }
    }

    private func setupObservers(for controller: GCController) {
        print("✅ Controller connected: \(controller.vendorName ?? "Unknown")")

        guard let gamepad = controller.extendedGamepad else {
            print("❌ No extended gamepad profile.")
            return
        }

        controller.playerIndex = .index1  // This is valid
        // Removed `controller.isPaused = false` — not part of GCController

        gamepad.leftThumbstick.valueChangedHandler = { [weak self] _, x, y in
            print("🎮 Left stick moved: x=\(x), y=\(y)")
            self?.updateMove(SIMD3<Float>(x, 0, y))
        }

        gamepad.rightThumbstick.valueChangedHandler = { [weak self] _, x, y in
            print("🎮 Right stick moved: x=\(x), y=\(y)")
            self?.updateLook(SIMD2<Float>(x, y))
        }
    }

    deinit {
        if let observer = controllerObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }
}

