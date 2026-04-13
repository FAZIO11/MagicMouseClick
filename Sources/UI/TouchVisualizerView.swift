import SwiftUI

struct TouchVisualizerView: View {
    @StateObject private var visualizer = TouchVisualizer()
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Live Visualizer")
                    .font(.headline)
                Spacer()
                if visualizer.isConnected {
                    Label("Connected", systemImage: "circle.fill")
                        .labelStyle(.iconOnly)
                        .foregroundStyle(.green)
                        .font(.caption)
                }
            }
            
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(nsColor: .controlBackgroundColor))
                
                GeometryReader { geometry in
                    MagicMouseSilhouette()
                        .stroke(Color.secondary.opacity(0.5), lineWidth: 2)
                        .padding(20)
                    
                    ForEach(visualizer.activeTouches.indices, id: \.self) { index in
                        let touch = visualizer.activeTouches[index]
                        
                        Circle()
                            .fill(touchColor(for: index))
                            .frame(width: 20, height: 20)
                            .shadow(color: touchColor(for: index).opacity(0.5), radius: 4)
                            .position(
                                x: 20 + (touch.position.x * (geometry.size.width - 40)),
                                y: 20 + ((1 - touch.position.y) * (geometry.size.height - 40))
                            )
                            .animation(.easeOut(duration: 0.1), value: touch.position)
                    }
                }
            }
            .frame(height: 180)
            .background(Color(nsColor: .textBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
            )
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Event Log")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    if !visualizer.activeTouches.isEmpty {
                        Text("\(visualizer.activeTouches.count) active")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 2) {
                        ForEach(visualizer.eventLog.reversed()) { event in
                            HStack(spacing: 6) {
                                Circle()
                                    .fill(eventColor(for: event))
                                    .frame(width: 6, height: 6)
                                Text(event.description)
                                    .font(.system(.caption, design: .monospaced))
                                Spacer()
                                Text(event.fingerLabel)
                                    .font(.system(.caption2, design: .monospaced))
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 2)
                            .padding(.horizontal, 4)
                            .background(
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(event == visualizer.eventLog.last ? Color.accentColor.opacity(0.1) : Color.clear)
                            )
                        }
                    }
                }
                .frame(maxHeight: 100)
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
        
        let mouseRect = CGRect(x: 0, y: 0, width: width, height: height * 0.75)
        path.addEllipse(in: mouseRect)
        
        let neckRect = CGRect(x: width * 0.35, y: height * 0.7, width: width * 0.3, height: height * 0.3)
        path.addRect(neckRect)
        
        return path
    }
}

struct GestureEventLog: Identifiable, Equatable {
    let id = UUID()
    let event: GestureEvent
    let fingerCount: Int
    let timestamp: Date
    
    var description: String {
        event.description
    }
    
    var fingerLabel: String {
        "\(fingerCount)f"
    }
    
    static func == (lhs: GestureEventLog, rhs: GestureEventLog) -> Bool {
        lhs.id == rhs.id
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
        MultitouchBridge.shared.start()
    }
    
    func stop() {
        MultitouchBridge.shared.stop()
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
    
    func multitouchBridgeDidConnect(_ bridge: MultitouchBridge) {
        DispatchQueue.main.async {
            self.isConnected = true
        }
    }
    
    func multitouchBridgeDidDisconnect(_ bridge: MultitouchBridge) {
        DispatchQueue.main.async {
            self.isConnected = false
            self.activeTouches = []
        }
    }
}
