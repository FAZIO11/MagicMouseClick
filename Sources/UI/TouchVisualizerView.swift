import SwiftUI

struct TouchVisualizerView: View {
    @StateObject private var visualizer = TouchVisualizer()
    
    var body: some View {
        VStack(spacing: 12) {
            Text("Live Visualizer")
                .font(.headline)
            
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(nsColor: .controlBackgroundColor))
                
                MagicMouseSilhouette()
                    .stroke(Color.secondary.opacity(0.5), lineWidth: 2)
                    .padding(20)
                
                ForEach(visualizer.activeTouches.indices, id: \.self) { index in
                    let touch = visualizer.activeTouches[index]
                    Circle()
                        .fill(touchColor(for: index))
                        .frame(width: 24, height: 24)
                        .position(
                            x: 20 + (touch.position.x * (visualizerBounds.width - 40)),
                            y: 20 + ((1 - touch.position.y) * (visualizerBounds.height - 40))
                        )
                }
            }
            .frame(height: 200)
            .background(Color(nsColor: .textBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
            )
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Event Log")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 2) {
                        ForEach(visualizer.eventLog.reversed()) { event in
                            HStack {
                                Circle()
                                    .fill(eventColor(for: event))
                                    .frame(width: 8, height: 8)
                                Text(event.description)
                                    .font(.system(.caption, design: .monospaced))
                                Spacer()
                                Text("\(event.fingerCount) finger\(event.fingerCount > 1 ? "s" : "")")
                                    .font(.system(.caption2, design: .monospaced))
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                .frame(maxHeight: 120)
            }
            
            HStack {
                Circle()
                    .fill(visualizer.isConnected ? Color.green : Color.red)
                    .frame(width: 10, height: 10)
                Text(visualizer.isConnected ? "Connected" : "No Magic Mouse")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .onAppear {
            visualizer.start()
        }
        .onDisappear {
            visualizer.stop()
        }
    }
    
    private var visualizerBounds: CGSize {
        CGSize(width: 200, height: 160)
    }
    
    private func touchColor(for index: Int) -> Color {
        index == 0 ? .blue : .orange
    }
    
    private func eventColor(for event: GestureEventLog) -> Color {
        switch event.event {
        case .leftClick: return .blue
        case .rightClick: return .orange
        case .touchStart: return .green
        case .touchEnd: return .gray
        case .unknown: return .secondary
        }
    }
}

struct MagicMouseSilhouette: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let width = rect.width
        let height = rect.height
        
        path.addEllipse(in: CGRect(x: 0, y: 0, width: width, height: height * 0.8))
        path.addRect(CGRect(x: width * 0.3, y: height * 0.75, width: width * 0.4, height: height * 0.25))
        
        return path
    }
}

struct GestureEventLog: Identifiable {
    let id = UUID()
    let event: GestureEvent
    let fingerCount: Int
    let timestamp: Date
    
    var description: String {
        event.description
    }
}

final class TouchVisualizer: NSObject, ObservableObject, MultitouchBridgeDelegate {
    @Published var activeTouches: [TouchData] = []
    @Published var eventLog: [GestureEventLog] = []
    @Published var isConnected = false
    
    private var maxLogEntries = 8
    
    override init() {
        super.init()
        MultitouchBridge.shared.delegate = self
    }
    
    func start() {
        isConnected = true
        MultitouchBridge.shared.start()
    }
    
    func stop() {
        MultitouchBridge.shared.stop()
        isConnected = false
    }
    
    func multitouchBridge(_ bridge: MultitouchBridge, didReceiveTouches touches: [TouchData]) {
        DispatchQueue.main.async {
            self.activeTouches = touches
        }
    }
    
    func multitouchBridge(_ bridge: MultitouchBridge, didDetectGesture event: GestureEvent, fingerCount: Int) {
        DispatchQueue.main.async {
            let logEntry = GestureEventLog(event: event, fingerCount: fingerCount, timestamp: Date())
            self.eventLog.append(logEntry)
            
            if self.eventLog.count > self.maxLogEntries {
                self.eventLog.removeFirst()
            }
        }
    }
}
