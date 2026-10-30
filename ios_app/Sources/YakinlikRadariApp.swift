import SwiftUI
import UserNotifications

@main
struct YakinlikRadariApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(.dark)
        }
    }
}

// Uygulama açıkken de bildirimlerin üstten (Heads-Up) düşmesini sağlar
class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .list, .sound])
    }
}

struct ContentView: View {
    @StateObject private var radar = BluetoothRadarManager()
    @State private var showingEditor = false
    @State private var editingTarget: TargetDevice? = nil
    @State private var prefillId: String = ""
    @State private var prefillLabel: String = ""
    @State private var selectedFilterIndex: Int = 0

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                // Başlık
                Text("📡 Yakınlık Radarı (iOS)")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.white)

                Text("Sadece eklediğiniz ve seçtiğiniz kişileri yüksek hızlı Bluetooth radarı ile anlık takip eder. Yabancı cihazları taramaz, kasma yapmaz.")
                    .font(.system(size: 13))
                    .foregroundColor(Color(red: 0.58, green: 0.64, blue: 0.72))

                // Sistem Durum Kutusu
                HStack {
                    Text(radar.bluetoothReady
                         ? "⚡ Yüksek Hızlı Radar Hazır • Aktif Hedef: \(radar.savedTargets.filter { $0.enabled }.count)"
                         : "❗ Bluetooth Kapalı veya İzin Bekleniyor (Lütfen Bluetooth'u açın)")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white)
                    Spacer()
                }
                .padding(12)
                .background(radar.bluetoothReady ? Color(red: 0.02, green: 0.37, blue: 0.27) : Color(red: 0.70, green: 0.32, blue: 0.04))
                .cornerRadius(8)

                // Üst Kontrol Kartı
                VStack(alignment: .leading, spacing: 12) {
                    let activeCount = radar.savedTargets.filter { $0.enabled }.count
                    Text(activeCount > 0
                         ? "● ANLIK BLUETOOTH RADARI AKTİF (\(activeCount) Kişi)"
                         : "● TAKİP BEKLEMEDE (Tarama Yapılmıyor)")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(activeCount > 0 ? Color.green : Color.yellow)

                    if !radar.savedTargets.isEmpty {
                        HStack(spacing: 8) {
                            Button("👥 Tümünü Takip Et") {
                                radar.enableAllTargets()
                            }
                            .font(.system(size: 12, weight: .semibold))
                            .padding(.vertical, 8)
                            .padding(.horizontal, 10)
                            .background(Color(red: 0.2, green: 0.25, blue: 0.33))
                            .foregroundColor(.white)
                            .cornerRadius(6)

                            Button("⏸️ Takibi Durdur") {
                                radar.pauseAllTargets()
                            }
                            .font(.system(size: 12, weight: .semibold))
                            .padding(.vertical, 8)
                            .padding(.horizontal, 10)
                            .background(Color(red: 0.2, green: 0.25, blue: 0.33))
                            .foregroundColor(.white)
                            .cornerRadius(6)
                        }
                    }

                    // Aksiyon Butonları
                    HStack(spacing: 8) {
                        Button(action: {
                            if radar.isDiscoveryOpen {
                                radar.stopNewPersonScanner()
                            } else {
                                radar.startNewPersonScanner()
                            }
                        }) {
                            Text(radar.isDiscoveryOpen ? "⏹ Aramayı Kapat" : "➕ YENİ KİŞİ EKLE")
                                .font(.system(size: 12, weight: .bold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 11)
                                .background(radar.isDiscoveryOpen ? Color.red : Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(8)
                        }

                        Button(action: {
                            editingTarget = nil
                            prefillId = ""
                            prefillLabel = ""
                            showingEditor = true
                        }) {
                            Text("⌨️ Elle Ekle")
                                .font(.system(size: 12, weight: .semibold))
                                .padding(.vertical, 11)
                                .padding(.horizontal, 12)
                                .background(Color(red: 0.28, green: 0.33, blue: 0.41))
                                .foregroundColor(.white)
                                .cornerRadius(8)
                        }

                        Button(action: {
                            radar.sendTestAlert()
                        }) {
                            Text("🔔 Test")
                                .font(.system(size: 12, weight: .semibold))
                                .padding(.vertical, 11)
                                .padding(.horizontal, 12)
                                .background(Color(red: 0.02, green: 0.59, blue: 0.41))
                                .foregroundColor(.white)
                                .cornerRadius(8)
                        }
                    }
                }
                .padding(14)
                .background(Color(red: 0.12, green: 0.16, blue: 0.23))
                .cornerRadius(12)

                // BÖLÜM 2: YENİ KİŞİ EKLEME PANELİ
                if radar.isDiscoveryOpen {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("🔍 YENİ KİŞİ EKLE (Cihaz Seçin)")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(Color(red: 0.58, green: 0.77, blue: 0.99))
                            Spacer()
                            Button("✖ Kapat") {
                                radar.stopNewPersonScanner()
                            }
                            .font(.system(size: 11, weight: .bold))
                            .padding(.vertical, 6)
                            .padding(.horizontal, 10)
                            .background(Color.red)
                            .foregroundColor(.white)
                            .cornerRadius(6)
                        }

                        if radar.discoverySignals.isEmpty {
                            Text("Etraftaki Bluetooth cihazları aranıyor...")
                                .font(.system(size: 12))
                                .foregroundColor(.yellow)
                                .padding(.vertical, 6)
                        } else {
                            ForEach(radar.discoverySignals.sorted(by: { $0.distanceMeters < $1.distanceMeters })) { sig in
                                HStack {
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text("🔹 \(sig.name)")
                                            .font(.system(size: 14, weight: .bold))
                                            .foregroundColor(.white)
                                        Text("Anlık: ~\(String(format: "%.1f", sig.distanceMeters)) m (\(sig.rssi) dBm)")
                                            .font(.system(size: 12))
                                            .foregroundColor(.gray)
                                    }
                                    Spacer()
                                    Button("➕ SEÇ & EKLE") {
                                        editingTarget = nil
                                        prefillId = sig.id
                                        prefillLabel = sig.name
                                        radar.stopNewPersonScanner()
                                        showingEditor = true
                                    }
                                    .font(.system(size: 12, weight: .bold))
                                    .padding(.vertical, 8)
                                    .padding(.horizontal, 12)
                                    .background(Color.green)
                                    .foregroundColor(.white)
                                    .cornerRadius(6)
                                }
                                .padding(10)
                                .background(Color(red: 0.06, green: 0.09, blue: 0.16))
                                .cornerRadius(8)
                            }
                        }
                    }
                    .padding(14)
                    .background(Color(red: 0.12, green: 0.23, blue: 0.54))
                    .cornerRadius(12)
                }

                // BÖLÜM 1: EKLEDİĞİM KİŞİLER LİSTESİ
                HStack {
                    Text("👥 EKLEDİĞİM KİŞİLER")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(Color(red: 0.22, green: 0.74, blue: 0.97))
                    Spacer()
                    if !radar.savedTargets.isEmpty {
                        Button("🗑️ Tümünü Çıkar") {
                            radar.clearAllTargets()
                        }
                        .font(.system(size: 11, weight: .bold))
                        .padding(.vertical, 6)
                        .padding(.horizontal, 10)
                        .background(Color(red: 0.6, green: 0.1, blue: 0.1))
                        .foregroundColor(.white)
                        .cornerRadius(6)
                    }
                }
                .padding(.top, 6)

                if radar.savedTargets.isEmpty {
                    Text("Henüz eklediğiniz bir kişi yok.\n\n👉 Kişi eklemek için yukarıdaki mavi '➕ YENİ KİŞİ EKLE' butonuna veya '⌨️ Elle Ekle' butonuna basın.")
                        .font(.system(size: 13))
                        .foregroundColor(.gray)
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(red: 0.12, green: 0.16, blue: 0.23))
                        .cornerRadius(10)
                } else {
                    ForEach(radar.savedTargets) { target in
                        let live = radar.trackedSignals[target.id.uppercased()]
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Toggle(isOn: Binding(
                                    get: { target.enabled },
                                    set: { newVal in
                                        var updated = target
                                        updated.enabled = newVal
                                        radar.addOrUpdateTarget(updated)
                                    }
                                )) {
                                    Text(target.label)
                                        .font(.system(size: 16, weight: .bold))
                                        .foregroundColor(target.enabled ? .white : .gray)
                                }
                                .toggleStyle(SwitchToggleStyle(tint: .blue))

                                Spacer()

                                if !target.enabled {
                                    Text("⏸️ Pasif")
                                        .font(.system(size: 13, weight: .bold))
                                        .foregroundColor(.gray)
                                } else if let sig = live {
                                    let inside = sig.distanceMeters <= target.maxDistanceMeters
                                    Text(inside ? "🚨 YAKINDA: \(String(format: "%.1f", sig.distanceMeters)) m" : "📏 Mesafe: \(String(format: "%.1f", sig.distanceMeters)) m")
                                        .font(.system(size: 13, weight: .bold))
                                        .foregroundColor(inside ? .green : .yellow)
                                } else {
                                    Text("Takipte (Menzil Dışı)")
                                        .font(.system(size: 13, weight: .bold))
                                        .foregroundColor(Color(red: 0.22, green: 0.74, blue: 0.97))
                                }
                            }

                            if let sig = live, target.enabled {
                                Text("📡 Anlık Sinyal: \(sig.rssi) dBm")
                                    .font(.system(size: 12))
                                    .foregroundColor(Color(red: 0.22, green: 0.74, blue: 0.97))
                            }

                            Text("📏 Sınır: \(String(format: "%.1f", target.maxDistanceMeters)) m • 💬 Mesaj: \"\(target.customMessage)\"")
                                .font(.system(size: 12.5))
                                .foregroundColor(Color(red: 0.8, green: 0.84, blue: 0.88))

                            HStack(spacing: 8) {
                                Button("🎯 Sadece Bu") {
                                    radar.selectOnlyTarget(target.id)
                                }
                                .font(.system(size: 11, weight: .semibold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                                .background(Color(red: 0.01, green: 0.52, blue: 0.78))
                                .foregroundColor(.white)
                                .cornerRadius(6)

                                Button("✏️ Ayarlar") {
                                    editingTarget = target
                                    prefillId = target.id
                                    prefillLabel = target.label
                                    showingEditor = true
                                }
                                .font(.system(size: 11, weight: .semibold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(6)

                                Button("🗑️ Çıkar / Sil") {
                                    radar.removeTarget(target)
                                }
                                .font(.system(size: 11, weight: .bold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                                .background(Color.red)
                                .foregroundColor(.white)
                                .cornerRadius(6)
                            }
                        }
                        .padding(14)
                        .background(target.enabled ? Color(red: 0.12, green: 0.16, blue: 0.23) : Color(red: 0.08, green: 0.11, blue: 0.16))
                        .cornerRadius(12)
                    }
                }
            }
            .padding(16)
        }
        .background(Color(red: 0.06, green: 0.09, blue: 0.16).ignoresSafeArea())
        .sheet(isPresented: $showingEditor) {
            TargetEditorSheet(
                existing: editingTarget,
                defaultId: prefillId,
                defaultLabel: prefillLabel
            ) { saved in
                radar.addOrUpdateTarget(saved)
            }
        }
    }
}

struct TargetEditorSheet: View {
    @Environment(\.dismiss) var dismiss
    let existing: TargetDevice?
    let defaultId: String
    let defaultLabel: String
    let onSave: (TargetDevice) -> Void

    @State private var label: String = ""
    @State private var deviceId: String = ""
    @State private var maxDistance: Double = 5.0
    @State private var customMessage: String = "Dikkat! Seçtiğiniz kişi yakınınıza geldi!"
    @State private var vibrateEnabled: Bool = true
    @State private var soundEnabled: Bool = true
    @State private var cooldownSec: Int = 10

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Kişi ve Cihaz Bilgisi")) {
                    TextField("Kişi Adı (Örn: Ahmet)", text: $label)
                    TextField("Bluetooth Cihaz Adı veya UUID", text: $deviceId)
                }

                Section(header: Text("Yaklaşma Mesafesi: \(String(format: "%.1f", maxDistance)) Metre")) {
                    Slider(value: $maxDistance, in: 1.0...30.0, step: 0.5)
                }

                Section(header: Text("Özel Bildirim Mesajı")) {
                    TextField("Yaklaştığında ne yazsın?", text: $customMessage)
                }

                Section(header: Text("Bildirim ve Titreşim Ayarları")) {
                    Toggle("Yaklaştığında Telefon Titresin", isOn: $vibrateEnabled)
                    Toggle("Bildirim Sesi Çalsın", isOn: $soundEnabled)
                    Picker("Tekrar Uyarı Süresi", selection: $cooldownSec) {
                        Text("Her 5 Saniyede Bir").tag(5)
                        Text("Her 10 Saniyede Bir").tag(10)
                        Text("Her 20 Saniyede Bir").tag(20)
                        Text("Her 45 Saniyede Bir").tag(45)
                    }
                }
            }
            .navigationTitle("🎯 Kişi Ayarları")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("İptal") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Kaydet ve Ekle") {
                        let finalId = deviceId.trimmingCharacters(in: .whitespaces).isEmpty ? label : deviceId
                        let finalLabel = label.trimmingCharacters(in: .whitespaces).isEmpty ? finalId : label
                        guard !finalId.isEmpty else { return }

                        let item = TargetDevice(
                            id: finalId,
                            label: finalLabel,
                            maxDistanceMeters: maxDistance,
                            customMessage: customMessage.isEmpty ? "\(finalLabel) yakınınıza geldi!" : customMessage,
                            enabled: true,
                            vibrateEnabled: vibrateEnabled,
                            soundEnabled: soundEnabled,
                            alertCooldownSec: cooldownSec
                        )
                        onSave(item)
                        dismiss()
                    }
                }
            }
            .onAppear {
                if let ex = existing {
                    label = ex.label
                    deviceId = ex.id
                    maxDistance = ex.maxDistanceMeters
                    customMessage = ex.customMessage
                    vibrateEnabled = ex.vibrateEnabled
                    soundEnabled = ex.soundEnabled
                    cooldownSec = ex.alertCooldownSec
                } else {
                    label = defaultLabel
                    deviceId = defaultId
                    if !defaultLabel.isEmpty {
                        customMessage = "\(defaultLabel) yakınınıza geldi!"
                    }
                }
            }
        }
    }
}
