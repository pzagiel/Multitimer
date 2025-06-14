import SwiftUI
import Combine
import AudioToolbox

class TimerItem: ObservableObject, Identifiable {
    let id = UUID()
    @Published var name: String
    let duration: TimeInterval
    @Published var remaining: TimeInterval
    @Published var isRunning: Bool = false {
        didSet { print("[TimerItem] isRunning toggled for \(name): \(isRunning)") }
    }

    init(name: String, duration: TimeInterval) {
        self.name = name
        self.duration = duration
        self.remaining = duration
        print("[TimerItem] Initialized: \(name), duration: \(duration)")
    }

    func reset() {
        print("[TimerItem] Reset called for \(name)")
        remaining = duration
        isRunning = false
    }
}

class TimerViewModel: ObservableObject {
    @Published var timers: [TimerItem] = []
    private var cancellable: AnyCancellable?

    init() {
        print("[TimerViewModel] Initialized with \(timers.count) user-defined timers")
        cancellable = Timer
            .publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in self?.tick() }
    }

    private func tick() {
        for item in timers where item.isRunning {
            if item.remaining > 0 {
                item.remaining -= 1
            } else {
                item.isRunning = false
                AudioServicesPlaySystemSound(1005)
            }
        }
    }

    func resetAll() {
        timers.forEach { $0.reset() }
    }

    func addTimer(name: String, duration: TimeInterval) {
        let new = TimerItem(name: name, duration: duration)
        timers.append(new)
        print("[TimerViewModel] Added new timer: \(name), \(duration)s")
    }
}

struct ContentView: View {
    @StateObject private var viewModel = TimerViewModel()
    @State private var showingAddSheet = false

    var body: some View {
        NavigationView {
            List {
                ForEach(viewModel.timers) { item in
                    TimerRow(timerItem: item)
                        .padding(.vertical, 4)
                }
                .onDelete { indices in
                    viewModel.timers.remove(atOffsets: indices)
                }
            }
            .listStyle(PlainListStyle())
            .navigationTitle("Multi-Minuterie")
            .toolbar {
                ToolbarItemGroup(placement: .navigationBarLeading) {
                    EditButton()
                    Button("Reset All") {
                        viewModel.resetAll()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        showingAddSheet = true
                    }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddSheet) {
                AddTimerView(isPresented: $showingAddSheet) { name, duration in
                    viewModel.addTimer(name: name, duration: duration)
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
                    .foregroundColor(.white)
                Spacer()
                Text(timeString)
                    .font(.title2)
                    .foregroundColor(timerItem.isRunning ? .green : .gray)
            }
            ProgressView(value: progressValue)
                .scaleEffect(y: 2)
                .accentColor(.green)
            HStack(spacing: 12) {
                Button(action: { timerItem.isRunning.toggle() }) {
                    Text(timerItem.isRunning ? "Pause" : "Start")
                        .foregroundColor(.black)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(timerItem.isRunning ? Color.yellow : Color.green)
                        .cornerRadius(8)
                }
                .buttonStyle(BorderlessButtonStyle())

                Button(action: { timerItem.reset() }) {
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
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct AddTimerView: View {
    @Binding var isPresented: Bool
    @State private var name: String = "Timer"
    @State private var durationText: String = "60"
    var onAdd: (String, TimeInterval) -> Void

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Nom").foregroundColor(.white)) {
                    TextField("Fonction", text: $name)
                        .foregroundColor(.white)
                }
                Section(header: Text("Durée (secondes)").foregroundColor(.white)) {
                    TextField("e.g. 60", text: $durationText)
                        .keyboardType(.numberPad)
                        .foregroundColor(.white)
                }
            }
            .background(Color.black)
            .navigationTitle("Nouveau Timer")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Ajouter") {
                        if let secs = TimeInterval(durationText), !name.isEmpty {
                            onAdd(name, secs)
                            isPresented = false
                        }
                    }
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") { isPresented = false }
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}

@main
struct MultiTimerApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(.dark)
        }
    }
}

