import AppKit
import SwiftUI

final class SettingsWindowController: NSWindowController {
    convenience init() {
        let contentView = SettingsView()
        let hostingController = NSHostingController(rootView: contentView)
        
        let window = NSWindow(contentViewController: hostingController)
        window.title = "MagicMouseClick"
        window.setContentSize(NSSize(width: 600, height: 450))
        window.styleMask = [.titled, .closable, .miniaturizable]
        window.center()
        window.isReleasedWhenClosed = false
        
        self.init(window: window)
    }
    
    override func showWindow(_ sender: Any?) {
        super.showWindow(sender)
        window?.makeKeyAndOrderFront(nil)
    }
}

struct SettingsView: View {
    @State private var gesturesEnabled = SettingsManager.shared.gesturesEnabled
    @State private var tapDuration = SettingsManager.shared.tapDuration
    @State private var movementThreshold = SettingsManager.shared.movementThreshold
    @State private var launchAtLogin = SettingsManager.shared.launchAtLogin
    
    var body: some View {
        HSplitView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Settings")
                    .font(.title)
                    .fontWeight(.bold)
                    .padding(.bottom, 10)
                
                Toggle("Enable Tap-to-Click", isOn: $gesturesEnabled)
                    .onChange(of: gesturesEnabled) { _, newValue in
                        SettingsManager.shared.gesturesEnabled = newValue
                    }
                
                Divider()
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Tap Duration")
                        .font(.headline)
                    Text("How long a touch must last to register as a tap")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    HStack {
                        Slider(value: $tapDuration, in: 0.1...0.35, step: 0.01)
                            .frame(width: 200)
                            .onChange(of: tapDuration) { _, newValue in
                                SettingsManager.shared.tapDuration = newValue
                            }
                        Text("\(Int(tapDuration * 1000))ms")
                            .font(.system(.body, design: .monospaced))
                            .frame(width: 50)
                    }
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Movement Threshold")
                        .font(.headline)
                    Text("Maximum finger movement during a tap")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    HStack {
                        Slider(value: $movementThreshold, in: 0.01...0.1, step: 0.005)
                            .frame(width: 200)
                            .onChange(of: movementThreshold) { _, newValue in
                                SettingsManager.shared.movementThreshold = newValue
                            }
                        Text(String(format: "%.2f", movementThreshold))
                            .font(.system(.body, design: .monospaced))
                            .frame(width: 50)
                    }
                }
                
                Divider()
                
                Toggle("Launch at Login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, newValue in
                        SettingsManager.shared.launchAtLogin = newValue
                    }
                
                Spacer()
                
                HStack {
                    Button("Check Permissions") {
                        PermissionChecker.shared.requestAccessibilityPermission()
                    }
                    Spacer()
                }
            }
            .padding()
            .frame(minWidth: 280)
            
            TouchVisualizerView()
                .frame(minWidth: 280)
        }
    }
}
