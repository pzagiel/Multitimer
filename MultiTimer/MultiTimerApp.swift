import SwiftUI
import Combine
import AudioToolbox

class TimerItem: ObservableObject, Identifiable {
    let id = UUID()
    let name: String
    let duration: TimeInterval
    @Published var remaining: TimeInterval
    @Published var isRunning: Bool = false {
        didSet {
            print("[TimerItem] isRunning toggled for \(name) (ID: \(id)): \(isRunning)")
        }
    }

    init(name: String, duration: TimeInterval) {
        self.name = name
        self.duration = duration
        self.remaining = duration
        print("[TimerItem] Initialized: \(name) (ID: \(id)), duration: \(duration)")
    }

    func reset() {
        print("[TimerItem] Reset called for \(name) (ID: \(id))")
        remaining = duration
        isRunning = false
    }
}

class TimerViewModel: ObservableObject {
    @Published var timers: [TimerItem]
    private var cancellable: AnyCancellable?

    init() {
        timers = [
            TimerItem(name: "Test 10s", duration: 10),
            TimerItem(name: "Test 5s", duration: 5),
            TimerItem(name: "Thé vert", duration: 180)
        ]
        print("[TimerViewModel] Initialized with \(timers.count) timers")
        cancellable = Timer
            .publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.tick()
            }
    }

    private func tick() {
        print("[TimerViewModel] Tick")
        for item in timers {
            print("  - Checking \(item.name): remaining=\(item.remaining), isRunning=\(item.isRunning)")
            guard item.isRunning else { continue }
            if item.remaining > 0 {
                item.remaining -= 1
                print("    > Decremented \(item.name): now \(item.remaining)")
            } else {
                item.isRunning = false
                print("    ! Timer finished for \(item.name)")
                AudioServicesPlaySystemSound(1005)
            }
        }
    }

    func resetAll() {
        print("[TimerViewModel] resetAll called")
        timers.forEach { $0.reset() }
    }
}

struct ContentView: View {
    @StateObject private var viewModel = TimerViewModel()

    var body: some View {
        NavigationView {
            List {
                ForEach(viewModel.timers) { item in
                    TimerRow(timerItem: item)
                        .padding(.vertical, 4)
                }
            }
            .listStyle(PlainListStyle())
            .navigationTitle("Multi-Minuterie")
            .toolbar {
                Button("Reset All") {
                    viewModel.resetAll()
                }
            }
        }
    }
}

struct TimerRow: View {
    @ObservedObject var timerItem: TimerItem

    private var timeString: String {
        let min = Int(timerItem.remaining) / 60
        let sec = Int(timerItem.remaining) % 60
        return String(format: "%02d:%02d", min, sec)
    }

    private var progressValue: Double {
        guard timerItem.duration > 0 else { return 0 }
        return (timerItem.duration - timerItem.remaining) / timerItem.duration
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(timerItem.name)
                    .font(.headline)
                Spacer()
                Text(timeString)
                    .font(.title2)
                    .foregroundColor(timerItem.isRunning ? .blue : .gray)
            }
            ProgressView(value: progressValue)
                .scaleEffect(y: 2)
            HStack(spacing: 12) {
                Button(action: {
                    print("[TimerRow] Button tapped for \(timerItem.name): current isRunning=\(timerItem.isRunning)")
                    timerItem.isRunning.toggle()
                }) {
                    Text(timerItem.isRunning ? "Pause" : "Start")
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(timerItem.isRunning ? Color.orange : Color.green)
                        .cornerRadius(8)
                }
                .buttonStyle(BorderlessButtonStyle())

                Button(action: {
                    print("[TimerRow] Reset button tapped for \(timerItem.name)")
                    timerItem.reset()
                }) {
                    Text("Reset")
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.red)
                        .cornerRadius(8)
                }
                .buttonStyle(BorderlessButtonStyle())

                Spacer()
            }
        }
        .padding(8)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
}

@main
struct MultiTimerApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

