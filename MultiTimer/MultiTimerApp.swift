import SwiftUI
import Combine
import AudioToolbox

class TimerItem: ObservableObject, Identifiable {
    let id = UUID()
    @Published var name: String
    let duration: TimeInterval
    @Published var remaining: TimeInterval
    @Published var isRunning: Bool = false

    init(name: String, duration: TimeInterval) {
        self.name = name
        self.duration = duration
        self.remaining = duration
    }

    func reset() {
        remaining = duration
        isRunning = false
    }
}

class TimerViewModel: ObservableObject {
    @Published var timers: [TimerItem] = []
    private var cancellable: AnyCancellable?

    init() {
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
    }
}

struct ContentView: View {
    @StateObject private var viewModel = TimerViewModel()
    @State private var showingAddSheet = false

    var body: some View {
        NavigationView {
            ZStack {
                Color.black.edgesIgnoringSafeArea(.all)
                List {
                    ForEach(viewModel.timers) { item in
                        TimerRow(timerItem: item)
                            .listRowBackground(Color.black)
                    }
                    .onDelete { indices in
                        viewModel.timers.remove(atOffsets: indices)
                    }
                }
                .listStyle(PlainListStyle())
            }
            .navigationTitle("Multi-Minuterie")
            .toolbar {
                ToolbarItemGroup(placement: .navigationBarLeading) {
                    EditButton()
                    Button("Reset All") { viewModel.resetAll() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingAddSheet = true }) {
                        Image(systemName: "plus").foregroundColor(.white)
                    }
                }
            }
            .sheet(isPresented: $showingAddSheet) {
                AddTimerView(isPresented: $showingAddSheet) { name, duration in
                    viewModel.addTimer(name: name, duration: duration)
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}

struct TimerRow: View {
    @ObservedObject var timerItem: TimerItem

    private var timeString: String {
        let h = Int(timerItem.remaining) / 3600
        let m = (Int(timerItem.remaining) % 3600) / 60
        let s = Int(timerItem.remaining) % 60
        return String(format: "%02d:%02d:%02d", h, m, s)
    }

    private var progressValue: Double {
        guard timerItem.duration > 0 else { return 0 }
        return (timerItem.duration - timerItem.remaining) / timerItem.duration
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
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
            HStack(spacing: 16) {
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
            }
        }
        .padding()
        .background(Color.black)
        .cornerRadius(10)
    }
}

struct AddTimerView: View {
    @Binding var isPresented: Bool
    @State private var name: String = "Timer"
    @State private var hours = 0
    @State private var minutes = 0
    @State private var seconds = 0
    var onAdd: (String, TimeInterval) -> Void

    var body: some View {
        NavigationView {
            ZStack {
                Color.black.edgesIgnoringSafeArea(.all)
                VStack(spacing: 20) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Nom").foregroundColor(.white).font(.caption)
                        TextField("Fonction", text: $name)
                            .foregroundColor(.white)
                            .padding(12)
                            .background(Color(white: 0.1))
                            .cornerRadius(8)
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Durée").foregroundColor(.white).font(.caption)
                        GeometryReader { geometry in
                            let pickerWidth = geometry.size.width / 3
                            HStack(spacing: 0) {
                                Picker("Heures", selection: $hours) {
                                    ForEach(0..<24, id: \.self) { value in
                                        Text("\(value) h").tag(value)
                                    }
                                }
                                .pickerStyle(WheelPickerStyle())
                                .frame(width: pickerWidth, height: 150)

                                Picker("Minutes", selection: $minutes) {
                                    ForEach(0..<60, id: \.self) { value in
                                        Text("\(value) m").tag(value)
                                    }
                                }
                                .pickerStyle(WheelPickerStyle())
                                .frame(width: pickerWidth, height: 150)

                                Picker("Secondes", selection: $seconds) {
                                    ForEach(0..<60, id: \.self) { value in
                                        Text("\(value) s").tag(value)
                                    }
                                }
                                .pickerStyle(WheelPickerStyle())
                                .frame(width: pickerWidth, height: 150)
                            }
                        }
                        .frame(height: 150)
                    }
                    Spacer()
                }
                .padding()
            }
            .navigationTitle("Nouveau Timer")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Ajouter") {
                        let total = TimeInterval(hours * 3600 + minutes * 60 + seconds)
                        guard total > 0, !name.isEmpty else { return }
                        onAdd(name, total)
                        isPresented = false
                    }
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") { isPresented = false }
                }
            }
            .preferredColorScheme(.dark)
        }
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

