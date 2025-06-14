import SwiftUI
import Combine
import AudioToolbox
import UIKit

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
                VStack(alignment: .leading, spacing: 20) {
                    Text("NOM").foregroundColor(.white)
                    TextField("Timer", text: $name)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .foregroundColor(.white)

                    Text("DURÉE").foregroundColor(.white)
                        .font(.caption)

                    CountDownPicker(duration: Binding(
                        get: { TimeInterval(hours * 3600 + minutes * 60 + seconds) },
                        set: {
                            let d = Int($0)
                            hours = d / 3600
                            minutes = (d % 3600) / 60
                            seconds = d % 60
                        }
                    ))
                    .frame(height: 150)
                    .background(Color.white.opacity(0.1))
                    .cornerRadius(8)

                    Spacer()
                }
                .padding()
            }
            .navigationTitle("Nouveau Timer")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") { isPresented = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Ajouter") {
                        let total = TimeInterval(hours * 3600 + minutes * 60 + seconds)
                        onAdd(name, total)
                        isPresented = false
                    }
                }
            }
            .preferredColorScheme(.dark)
        }
    }
}

struct CountDownPicker: UIViewRepresentable {
    @Binding var duration: TimeInterval

    func makeUIView(context: Context) -> UIPickerView {
        let picker = UIPickerView()
        picker.dataSource = context.coordinator
        picker.delegate = context.coordinator
        let total = Int(duration)
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        picker.selectRow(h, inComponent: 0, animated: false)
        picker.selectRow(m, inComponent: 1, animated: false)
        picker.selectRow(s, inComponent: 2, animated: false)
        return picker
    }

    func updateUIView(_ uiView: UIPickerView, context: Context) {
        let total = Int(duration)
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        if uiView.selectedRow(inComponent: 0) != h {
            uiView.selectRow(h, inComponent: 0, animated: false)
        }
        if uiView.selectedRow(inComponent: 1) != m {
            uiView.selectRow(m, inComponent: 1, animated: false)
        }
        if uiView.selectedRow(inComponent: 2) != s {
            uiView.selectRow(s, inComponent: 2, animated: false)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(duration: $duration)
    }

    class Coordinator: NSObject, UIPickerViewDataSource, UIPickerViewDelegate {
        var duration: Binding<TimeInterval>
        init(duration: Binding<TimeInterval>) {
            self.duration = duration
        }

        func numberOfComponents(in pickerView: UIPickerView) -> Int { 3 }
        func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
            switch component {
            case 0: return 24
            case 1: return 60
            default: return 60
            }
        }

        func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
            switch component {
            case 0: return "\(row) h"
            case 1: return "\(row) m"
            default: return "\(row) s"
            }
        }

        func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
            let h = pickerView.selectedRow(inComponent: 0)
            let m = pickerView.selectedRow(inComponent: 1)
            let s = pickerView.selectedRow(inComponent: 2)
            duration.wrappedValue = TimeInterval(h * 3600 + m * 60 + s)
        }

        func pickerView(_ pickerView: UIPickerView, widthForComponent component: Int) -> CGFloat {
            pickerView.bounds.width / 3.0
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

