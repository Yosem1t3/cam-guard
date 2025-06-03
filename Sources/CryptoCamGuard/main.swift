import SwiftUI
import AppKit

// MARK: - Models
struct ActivityRecord: Identifiable {
    let id = UUID()
    let appName: String
    let timestamp: Date
    let icon: String
}

class SecurityMonitor: ObservableObject {
    @Published var isRecording = false
    @Published var showAlert = false
    @Published var activities: [ActivityRecord] = []
    private var usedApps = Set<String>()
    
    init() {
        // Add initial activities with unique apps
        let initialActivities = [
            ("Zoom", "video", -3600.0),
            ("Discord", "bubble.left", -7200.0),
            ("Chrome", "globe", -10800.0)
        ]
        
        for (app, icon, timeOffset) in initialActivities {
            addActivity(app: app, icon: icon, timestamp: Date().addingTimeInterval(timeOffset))
        }
    }
    
    func addActivity(app: String, icon: String, timestamp: Date = Date()) {
        // Only add if this app isn't already in the recent activities
        if !usedApps.contains(app) {
            let activity = ActivityRecord(
                appName: app,
                timestamp: timestamp,
                icon: icon
            )
            activities.insert(activity, at: 0)
            usedApps.insert(app)
            
            // Remove oldest activity if we have too many
            if activities.count > 5 {
                if let removedApp = activities.last?.appName {
                    usedApps.remove(removedApp)
                }
                activities.removeLast()
            }
        }
    }
}

class AppController: NSObject, NSApplicationDelegate {
    private var statusBar: NSStatusBar!
    private var statusItem: NSStatusItem!
    private var monitor: SecurityMonitor!
    private var popover: NSPopover!
    private var timer: Timer?
    
    override init() {
        super.init()
        statusBar = NSStatusBar.system
        monitor = SecurityMonitor()
    }
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        setupStatusItem()
        startMonitoring()
    }
    
    private func setupStatusItem() {
        statusItem = statusBar.statusItem(withLength: NSStatusItem.squareLength)
        
        guard let button = statusItem.button else { return }
        button.image = NSImage(systemSymbolName: "camera", accessibilityDescription: "Security Monitor")
        
        popover = NSPopover()
        popover.contentSize = NSSize(width: 300, height: 400)
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(rootView: PopoverView(monitor: monitor))
        
        button.action = #selector(togglePopover)
        button.target = self
    }
    
    @objc private func togglePopover() {
        if popover.isShown {
            popover.performClose(nil)
        } else if let button = statusItem.button {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        }
    }
    
    private func startMonitoring() {
        timer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            self?.checkForActivity()
        }
    }
    
    private func checkForActivity() {
        if Int.random(in: 0...4) == 0 {
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                
                // Update status item
                if let button = self.statusItem.button {
                    button.image = NSImage(systemSymbolName: "camera.fill", accessibilityDescription: "Security Monitor")
                    button.contentTintColor = .systemRed
                }
                
                // Add new activity
                let apps = ["Zoom", "Discord", "Chrome", "Skype", "Teams"]
                let icons = ["video", "bubble.left", "globe", "video.fill", "person.2"]
                let randomIndex = Int.random(in: 0..<apps.count)
                let randomApp = apps[randomIndex]
                let randomIcon = icons[randomIndex]  // Use matching icon for the app
                
                self.monitor.addActivity(app: randomApp, icon: randomIcon)
                
                self.monitor.isRecording = true
                self.monitor.showAlert = true
                
                // Reset after delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
                    if let button = self?.statusItem.button {
                        button.image = NSImage(systemSymbolName: "camera", accessibilityDescription: "Security Monitor")
                        button.contentTintColor = nil
                    }
                    self?.monitor.isRecording = false
                    self?.monitor.showAlert = false
                }
            }
        }
    }
}

struct PopoverView: View {
    @ObservedObject var monitor: SecurityMonitor
    
    var body: some View {
        VStack(spacing: 16) {
            Text("Security Monitor")
                .font(.system(size: 24, weight: .bold, design: .rounded))
            
            if monitor.showAlert {
                AlertView()
            }
            
            List(monitor.activities) { activity in
                HStack {
                    Image(systemName: activity.icon)
                        .foregroundColor(.accentColor)
                    VStack(alignment: .leading) {
                        Text(activity.appName)
                            .font(.headline)
                        Text(activity.timestamp, style: .relative)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .frame(height: 200)
            
            Button(action: {
                monitor.isRecording = false
                monitor.showAlert = false
            }) {
                Text("Block Now")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.red)
                    .cornerRadius(10)
            }
            .buttonStyle(.plain)
        }
        .padding()
    }
}

struct AlertView: View {
    var body: some View {
        HStack {
            Text("🙈")
                .font(.system(size: 40))
            VStack(alignment: .leading) {
                Text("Suspicious Activity Detected!")
                    .font(.headline)
                Text("Camera access detected")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color.red.opacity(0.2))
        .cornerRadius(10)
    }
}

// MARK: - Main
let app = NSApplication.shared
let controller = AppController()
app.delegate = controller
_ = NSApplicationMain(CommandLine.argc, CommandLine.unsafeArgv) 