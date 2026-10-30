import SwiftUI
import CoreBluetooth
import UserNotifications
import AudioToolbox

// MARK: - Veri Modelleri
struct TargetDevice: Identifiable, Codable, Equatable {
    var id: String                  // Bluetooth UUID veya Cihaz Adı
    var label: String               // Kişi Adı (Örn: Ahmet)
    var maxDistanceMeters: Double   // Uyarı verilecek maksimum mesafe
    var customMessage: String       // Özel bildirim mesajı
    var enabled: Bool = true
    var vibrateEnabled: Bool = true
    var soundEnabled: Bool = true
    var alertCooldownSec: Int = 10
}

struct ScannedSignal: Identifiable {
    let id: String
    let name: String
    let rssi: Int
    let distanceMeters: Double
    let timestamp: Date
}

// MARK: - Bluetooth & Bildirim Radarı Yöneticisi (CoreBluetooth)
class BluetoothRadarManager: NSObject, ObservableObject, CBCentralManagerDelegate {
    @Published var savedTargets: [TargetDevice] = []
    @Published var trackedSignals: [String: ScannedSignal] = [:]
    @Published var discoverySignals: [ScannedSignal] = []
    @Published var isDiscoveryOpen: Bool = false
    @Published var bluetoothReady: Bool = false

    private var centralManager: CBCentralManager!
    private var smoothedRssiMap: [String: Double] = [:]
    private var lastAlertTimes: [String: Date] = [:]
    private var timer: Timer?

    private let storageKey = "yakinlik_radari_ios_targets"

    override init() {
        super.init()
        loadTargets()
        requestNotificationPermission()
        centralManager = CBCentralManager(delegate: self, queue: .main)

        timer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.cleanupOldSignals()
        }
    }

    func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
    }

    // MARK: - Kalıcı Hafıza (UserDefaults)
    func loadTargets() {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let decoded = try? JSONDecoder().decode([TargetDevice].self, from: data) {
            savedTargets = decoded
        }
    }

    func saveTargets() {
        if let data = try? JSONEncoder().encode(savedTargets) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
        updateScanState()
    }

    func addOrUpdateTarget(_ target: TargetDevice) {
        if let idx = savedTargets.firstIndex(where: {
            $0.id.lowercased() == target.id.lowercased() || $0.label.lowercased() == target.label.lowercased()
        }) {
            savedTargets[idx] = target
        } else {
            savedTargets.append(target)
        }
        stopNewPersonScanner()
        saveTargets()
    }

    func removeTarget(_ target: TargetDevice) {
        savedTargets.removeAll { $0.id == target.id }
        trackedSignals.removeValue(forKey: target.id.uppercased())
        saveTargets()
    }

    func clearAllTargets() {
        savedTargets.removeAll()
        trackedSignals.removeAll()
        saveTargets()
    }

    func selectOnlyTarget(_ id: String) {
        for i in savedTargets.indices {
            savedTargets[i].enabled = (savedTargets[i].id == id)
        }
        saveTargets()
    }

    func enableAllTargets() {
        for i in savedTargets.indices {
            savedTargets[i].enabled = true
        }
        saveTargets()
    }

    func pauseAllTargets() {
        for i in savedTargets.indices {
            savedTargets[i].enabled = false
        }
        saveTargets()
    }

    // MARK: - Yeni Kişi Ekleme ve Sadece Eklenenleri Takip Etme Modu
    func startNewPersonScanner() {
        isDiscoveryOpen = true
        discoverySignals.removeAll()
        updateScanState()
    }

    func stopNewPersonScanner() {
        isDiscoveryOpen = false
        discoverySignals.removeAll()
        updateScanState()
    }

    func updateScanState() {
        guard centralManager != nil, centralManager.state == .poweredOn else { return }
        centralManager.stopScan()

        let hasActiveTargets = savedTargets.contains(where: { $0.enabled })
        if isDiscoveryOpen || hasActiveTargets {
            // Sadece Yeni Kişi Ekle açıkken veya aktif takip edilen kişi varken tarama çalışır
            centralManager.scanForPeripherals(
                withServices: nil,
                options: [CBCentralManagerScanOptionAllowDuplicatesKey: true]
            )
        }
    }

    // MARK: - CBCentralManagerDelegate
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        bluetoothReady = (central.state == .poweredOn)
        updateScanState()
    }

    func centralManager(_ central: CBCentralManager,
                        didDiscover peripheral: CBPeripheral,
                        advertisementData: [String: Any],
                        rssi RSSI: NSNumber) {
        let rawRssi = RSSI.intValue
        if rawRssi == 127 || rawRssi == 0 { return } // Geçersiz sinyal

        let uuidStr = peripheral.identifier.uuidString.uppercased()
        let advName = advertisementData[CBAdvertisementDataLocalNameKey] as? String
        let devName = peripheral.name ?? advName ?? "Bluetooth Cihazı (\(uuidStr.prefix(6)))"

        let dist = calculateRealtimeDistance(key: uuidStr, rawRssi: rawRssi)
        let signal = ScannedSignal(
            id: uuidStr,
            name: devName,
            rssi: rawRssi,
            distanceMeters: dist,
            timestamp: Date()
        )

        // 1) Yeni Kişi Ekle ekranı açıksa oraya ekle
        if isDiscoveryOpen {
            let savedIds = Set(savedTargets.map { $0.id.uppercased() })
            if !savedIds.contains(uuidStr) {
                if let idx = discoverySignals.firstIndex(where: { $0.id == uuidStr }) {
                    discoverySignals[idx] = signal
                } else {
                    discoverySignals.append(signal)
                }
            }
        }

        // 2) Sadece eklenen ve aktif olan kişilerden biri mi kontrol et
        let activeTargets = savedTargets.filter { $0.enabled }
        guard let matched = activeTargets.first(where: {
            $0.id.caseInsensitiveCompare(uuidStr) == .orderedSame ||
            (!devName.starts(with: "Bluetooth Cihazı") && (
                $0.id.caseInsensitiveCompare(devName) == .orderedSame ||
                $0.label.caseInsensitiveCompare(devName) == .orderedSame
            ))
        }) else { return }

        let targetKey = matched.id.uppercased()
        trackedSignals[targetKey] = signal

        // Mesafe sınırına girdiyse bildirim ve güçlü titreşim gönder
        if dist <= matched.maxDistanceMeters {
            let now = Date()
            let lastTime = lastAlertTimes[targetKey] ?? Date.distantPast
            if now.timeIntervalSince(lastTime) >= Double(max(5, matched.alertCooldownSec)) {
                lastAlertTimes[targetKey] = now
                triggerAlert(for: matched, distance: dist)
            }
        }
    }

    // MARK: - Anlık EMA Mesafe Hesaplama
    func calculateRealtimeDistance(key: String, rawRssi: Int) -> Double {
        let prev = smoothedRssiMap[key]
        let filtered = (prev == nil) ? Double(rawRssi) : (Double(rawRssi) * 0.65 + prev! * 0.35)
        smoothedRssiMap[key] = filtered

        let txPower = -59.0
        let envFactor = 2.2
        let rawDist = pow(10.0, (txPower - filtered) / (10.0 * envFactor))
        let rounded = (rawDist * 10.0).rounded() / 10.0
        return min(max(rounded, 0.1), 99.9)
    }

    private func cleanupOldSignals() {
        let now = Date()
        for (k, v) in trackedSignals {
            if now.timeIntervalSince(v.timestamp) > 20.0 {
                trackedSignals.removeValue(forKey: k)
            }
        }
    }

    // MARK: - Bildirim ve Güçlü iPhone Titreşimi (Haptic + SystemVibrate)
    func triggerAlert(for target: TargetDevice, distance: Double) {
        if target.vibrateEnabled {
            AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
                AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
            }
        }

        if target.soundEnabled {
            AudioServicesPlaySystemSound(1007) // iOS Tri-tone bildirim sesi
        }

        let content = UNMutableNotificationContent()
        content.title = "⚠️ \(target.label) Yakında! (~\(distance) m)"
        content.body = "\(target.customMessage)\n(Anlık Mesafe: \(distance) m • Sınır: \(target.maxDistanceMeters) m)"
        if target.soundEnabled {
            content.sound = .default
        }

        let req = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(req)
    }

    func sendTestAlert() {
        let sample = savedTargets.first(where: { $0.enabled }) ?? savedTargets.first ?? TargetDevice(
            id: "TEST",
            label: "Seçili Kişi",
            maxDistanceMeters: 3.0,
            customMessage: "Bu sizin özel test mesajınızdır! Seçtiğiniz kişi yaklaştığında tam olarak böyle görünecek."
        )
        triggerAlert(for: sample, distance: 1.4)
    }
}
