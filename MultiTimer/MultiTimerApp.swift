import SwiftUI
import Combine
import UserNotifications
import AudioToolbox
import UIKit
import AVFoundation

@main
struct MultiTimerApp: App {
    init() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, error in
            if let error = error {
                print("Notification permission error: \(error)")
            }
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(.dark)
        }
    }
}

class TimerItem: ObservableObject, Identifiable {
    let id = UUID().uuidString
    @Published var name: String
    let duration: TimeInterval
    @Published private(set) var remaining: TimeInterval
    @Published var isRunning: Bool = false
    private var endDate: Date?

    init(name: String, duration: TimeInterval) {
        self.name = name
        self.duration = duration
        self.remaining = duration
    }

    func start() {
        guard !isRunning else { return }
        isRunning = true
        endDate = Date().addingTimeInterval(remaining)
        scheduleNotification()
    }

    func pause() {
        guard isRunning, let end = endDate else { return }
        remaining = max(end.timeIntervalSinceNow, 0)
        isRunning = false
        cancelNotification()
        endDate = nil
    }

    func reset() {
        isRunning = false
        remaining = duration
        endDate = nil
        cancelNotification()
    }

    func tick() {
        guard isRunning, let end = endDate else { return }
        let newRemaining = end.timeIntervalSinceNow
        if newRemaining <= 0 {
            remaining = 0
            isRunning = false
            //AudioServicesPlaySystemSound(1005)
            speak(name)
        } else {
            remaining = newRemaining
        }
    }
    private func speak(_ text: String) {
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "fr-FR") // ou "en-US", selon le nom du timer
        let synthesizer = AVSpeechSynthesizer()
        synthesizer.speak(utterance)
    }

    private func scheduleNotification() {
        let content = UNMutableNotificationContent()
        content.title = name
        content.body = "Le timer est terminé !"
        content.sound = .default
        //content.sound = UNNotificationSound(named: UNNotificationSoundName("cafe_pret.caf"))

        guard let end = endDate else { return }
        let interval = max(end.timeIntervalSinceNow, 0)
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Notification scheduling error: \(error)")
            }
        }
    }

    private func cancelNotification() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [id])
    }
}

class TimerViewModel: ObservableObject {
    @Published var timers: [TimerItem] = []
    private var cancellable: AnyCancellable?

    init() {
        cancellable = Timer
            .publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.timers.forEach { $0.tick() }
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
                Button(action: {
                    if timerItem.isRunning {
                        timerItem.pause()
                    } else {
                        timerItem.start()
                    }
                }) {
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
                    CountDownPicker(duration: Binding(
                        get: { TimeInterval(hours * 3600 + minutes * 60 + seconds) },
                        set: {
                            let total = Int($0)
                            hours = total / 3600
                            minutes = (total % 3600) / 60
                            seconds = total % 60
                        }
                    ))
                    HStack {
                        Text("NOM")
                            .foregroundColor(.white)
                        TextField("Timer", text: $name)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                    }
                    .padding()
                    .background(Color.white.opacity(0.1))
                    .cornerRadius(8)


//                    Text("DURÉE").foregroundColor(.white)
//                        .font(.caption)

                   // second frame inutile
//                    .frame(height: 150)
//                    .background(Color.white.opacity(0.1))
//                    .cornerRadius(8)

                    Spacer()
                }
                .padding()
            }
            .navigationTitle("New Timer")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { isPresented = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        let total = TimeInterval(hours * 3600 + minutes * 60 + seconds)
                        onAdd(name, total)
                        isPresented = false
                    }
                }
            }
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

