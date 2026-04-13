import AppKit
import SwiftUI

final class SetupWindowController: NSWindowController {
    static let shared = SetupWindowController()
    
    private init() {
        let contentView = SetupView()
        let hostingController = NSHostingController(rootView: contentView)
        
        let window = NSWindow(contentViewController: hostingController)
        window.title = "Welcome to MagicMouseClick"
        window.setContentSize(NSSize(width: 480, height: 360))
        window.styleMask = [.titled, .closable]
        window.center()
        window.isReleasedWhenClosed = false
        
        super.init(window: window)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func showSetup() {
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    func dismissSetup() {
        window?.close()
    }
}

struct SetupView: View {
    @State private var currentStep = 0
    @State private var permissionGranted = false
    
    private let steps = [
        SetupStep(
            title: "Welcome to MagicMouseClick",
            description: "This app enables tap-to-click on your Magic Mouse. Let's get started with a quick setup.",
            systemImage: "hand.tap.welcome"
        ),
        SetupStep(
            title: "Grant Accessibility Permission",
            description: "MagicMouseClick needs Accessibility permission to inject click events. Click the button below to open System Settings.",
            systemImage: "lock.shield"
        ),
        SetupStep(
            title: "You're All Set!",
            description: "Permission granted. Click the menu bar icon to access settings and start using tap-to-click.",
            systemImage: "checkmark.circle"
        )
    ]
    
    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            
            Image(systemName: steps[currentStep].systemImage)
                .font(.system(size: 64))
                .foregroundStyle(.blue)
            
            Text(steps[currentStep].title)
                .font(.title2)
                .fontWeight(.bold)
            
            Text(steps[currentStep].description)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 350)
            
            if currentStep == 1 {
                VStack(spacing: 8) {
                    Text("1. Click 'Open System Settings' below")
                        .font(.caption)
                    Text("2. Navigate to Privacy & Security → Accessibility")
                        .font(.caption)
                    Text("3. Enable MagicMouseClick")
                        .font(.caption)
                }
                .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            HStack {
                if currentStep > 0 {
                    Button("Back") {
                        withAnimation {
                            currentStep -= 1
                        }
                    }
                    .keyboardShortcut(.leftArrow, modifiers: [])
                }
                
                Spacer()
                
                if currentStep < steps.count - 1 {
                    Button("Continue") {
                        if currentStep == 1 {
                            PermissionChecker.shared.requestAccessibilityPermission()
                        }
                        withAnimation {
                            currentStep += 1
                        }
                    }
                    .buttonStyle(.borderedProminent)
                } else {
                    Button("Get Started") {
                        SetupWindowController.shared.dismissSetup()
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding(.horizontal)
        }
        .padding(32)
    }
}

struct SetupStep {
    let title: String
    let description: String
    let systemImage: String
}
