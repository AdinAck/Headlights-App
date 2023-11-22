//
//  BLERouter.swift
//  HeadlightsV2
//
//  Created by Adin Ackerman on 9/8/23.
//

import Foundation
import SwiftUI
import CoreBluetooth

extension UUID: RawRepresentable {
    public typealias RawValue = String
    
    public var rawValue: String {
        self.uuidString
    }
    
    public init?(rawValue: RawValue) {
        self.init(uuidString: rawValue)
    }
}

protocol BLEGATT {
    static var SERVICE_UUID: CBUUID { get }
    
    func load()
}

class BLEDispatch: NSObject, ObservableObject, CBPeripheralDelegate {
    var peripheral: CBPeripheral!
    
    @Published var connected: Bool = false
    @Published var loaded: Bool = false
    @Published var invalid_characteristics: Bool = false
    
    private let _disconnect: (CBPeripheral) -> Void
    
    required init(peripheral: CBPeripheral, disconnect: @escaping (CBPeripheral) -> Void) {
        self.peripheral = peripheral
        self._disconnect = disconnect
        super.init()
        self.peripheral.delegate = self
    }
    
    func disconnect() {
        _disconnect(peripheral)
    }
}

typealias BLEDevice = BLEDispatch & BLEGATT

class BLERouter<Device: BLEDevice>: NSObject, ObservableObject, CBCentralManagerDelegate {
    private var centralManager: CBCentralManager!
    private let scan_uuids: [CBUUID]
    private let count: Int
    
    @Published var discovered: [Device] = []
    @Published var loaded: [Device] = []
    
    @AppStorage("favorite") var favorite: UUID?
    @AppStorage("auto-connect") var auto_connect: Bool = true // maybe should be per peripheral
    
    var max_conn: Int {
        count
    }
    
    init(scan: [CBUUID], count: Int) {
        scan_uuids = scan
        self.count = count
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: nil)
    }
    
    func discovery<Content: View>(@ViewBuilder content: @escaping ([Device]) -> Content) -> some View {
        DiscoveryView<Device, Content>(content: content)
        .environmentObject(self)
    }
    
    func startScanning() {
        print("Scanning")
        
        withAnimation {
            discovered = discovered.filter({ device in
                device.connected
            })
        }
        
        centralManager.scanForPeripherals(withServices: scan_uuids)
    }
    
    func stopScanning() {
        centralManager.stopScan()
    }
    
    func connect(to device: Device) {
        print("[BLE] [INFO] Connecting to peripheral with uuid: \(device.peripheral.identifier).")
        centralManager.connect(device.peripheral)
    }
    
    func disconnect(from device: Device) {
        centralManager.cancelPeripheralConnection(device.peripheral)
    }
    
    func discovered_device(from peripheral: CBPeripheral) -> Device? {
        discovered.first { device in
            device.peripheral == peripheral
        }
    }
    
    func loaded_device(from peripheral: CBPeripheral) -> Device? {
        loaded.first { device in
            device.peripheral == peripheral
        }
    }
    
    func load(device: Device) {
        if loaded.contains(device) {
            print("[WARN] Attempted to load device with ID: \"\(device.peripheral.identifier)\" more than once.")
            return
        }
        
        loaded.append(device)
    }
    
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn:
            print("[BLE] [INFO] Central Manager is ready.")
            startScanning()
        default:
            print("[BLE] [ERR] Central Manager is in an invalid state: \(central.state). Abort.")
        }
    }
    
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        print("[BLE] [INFO] Discovered peripheral: \(peripheral).")
        
        if !discovered.map({ device in
            device.peripheral
        }).contains(peripheral) {
            withAnimation {
                discovered.append(Device(peripheral: peripheral, disconnect: { [self] peripheral in
                    self.centralManager.cancelPeripheralConnection(peripheral)
                    
                    /*
                     because if they manually disconnected they
                     probably don't want it to reconnect
                     */
                    auto_connect = false
                }))
            }
        }
    }
    
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        print("[BLE] [INFO] Connected!")
        
        guard let device = discovered_device(from: peripheral) else {
            print("[BLE] [WARN] Attempted to connect to peripheral that is no longer discovered.")
            return
        }
        
        guard loaded.count < count else {
            centralManager.cancelPeripheralConnection(peripheral)
            return
        }
        
        withAnimation {
            device.connected = true
        }
        
        device.load()
    }
    
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        print("[BLE] [INFO] Disconnected.")
        
        guard let device = loaded_device(from: peripheral) else {
            guard let device = discovered_device(from: peripheral) else {
                print("[BLE] [WARN] Attempted to disconnect from unkown peripheral.")
                return
            }
            
            withAnimation {
                device.connected = false
            }
            
            return
        }
        
        withAnimation {
            device.connected = false
            device.loaded = false
            
            loaded.removeAll { _device in
                device == _device
            }
        }
    }
}

struct PeripheralDetailView<Device: BLEDevice>: View {
    @EnvironmentObject private var router: BLERouter<Device>
    
    let peripheral: CBPeripheral
    
    var body: some View {
        List {
            Section("Settings") {
                HStack {
                    let favorite = router.favorite == peripheral.identifier
                    
                    Text("Favorite")
                    Spacer()
                    Button {
                        withAnimation {
                            if favorite {
                                router.favorite = nil
                            } else {
                                router.favorite = peripheral.identifier
                            }
                        }
                    } label: {
                        Image(systemName: favorite ? "star.fill" : "star")
                            .animation(.none, value: favorite)
                    }
                    .tint(.yellow)
                }
                
                Toggle("Auto Connect", isOn: $router.auto_connect)
            }
            
            Section("ADV Data") {
                HStack {
                    Text("Name")
                    Spacer()
                    Text(peripheral.name ?? "UNKNOWN")
                        .font(.headline)
                }
                
                HStack {
                    Text("ID")
                    Spacer()
                    ScrollView(.horizontal, showsIndicators: false) {
                        Text("\(peripheral.identifier)")
                            .monospaced()
                            .bold()
                            .textSelection(.enabled)
                    }
                }
            }
        }
    }
}

struct DiscoveryRow<Device: BLEDevice>: View {
    @EnvironmentObject private var router: BLERouter<Device>
    @EnvironmentObject private var device: Device
    
    @State private var present_details: Bool = false
    
    private let notify = UINotificationFeedbackGenerator()
    private let impact = UIImpactFeedbackGenerator()
    
    var body: some View {
        HStack {
            if router.favorite == device.peripheral.identifier {
                Image(systemName: "star.fill")
                    .foregroundColor(.yellow)
            }
            
            Text(device.peripheral.name ?? "UNKNOWN")
                .font(.headline)
                .frame(maxWidth: 100)
            Spacer()
            Button {
                present_details.toggle()
            } label: {
                Image(systemName: "ellipsis.circle")
            }
            .buttonStyle(.bordered)
            .tint(.secondary)
            
            Button {
                if !device.invalid_characteristics {
                    impact.impactOccurred()
                    if !device.connected {
                        router.connect(to: device)
                    } else {
                        router.disconnect(from: device)
                    }
                }
            } label: {
                if device.invalid_characteristics {
                    Image(systemName: "exclamationmark.triangle.fill")
                } else if !device.connected {
                    Image(systemName: "arrowshape.right.fill")
                } else if !device.loaded {
                    ProgressView()
                } else {
                    Image(systemName: "arrowshape.left.fill")
                }
            }
            .buttonStyle(.bordered)
            .tint(device.invalid_characteristics ? .red : device.loaded ? .blue : device.connected || device.peripheral.state == .connecting ? .orange : .green)
        }
        .sheet(isPresented: $present_details) {
            PeripheralDetailView<Device>(peripheral: device.peripheral)
                .environmentObject(router)
        }
        .onAppear {
            if router.favorite == device.peripheral.identifier && router.auto_connect {
                router.connect(to: device)
            }
        }
        .onChange(of: device.loaded) { loaded in
            if loaded {
                notify.notificationOccurred(.success)
                withAnimation {
                    router.load(device: device) // unfortunate the view has to do this
                }
            }
        }
        .onChange(of: device.invalid_characteristics) { invalid in
            if invalid {
                notify.notificationOccurred(.error)
            }
        }
    }
}

struct DiscoveryView<Device: BLEDevice, Content: View>: View {
    @EnvironmentObject var router: BLERouter<Device>
    let content: ([Device]) -> Content
    
    init(content: @escaping ([Device]) -> Content) {
        self.content = content
    }
    
    var body: some View {
        if router.loaded.count == router.max_conn {
            content(router.loaded)
                .onAppear {
                    router.stopScanning()
                    router.discovered = [] // view shouldn't do this
                }
                .onDisappear {
                    router.startScanning()
                }
        } else {
            ZStack {
                List(router.discovered, id: \.peripheral.identifier) { device in
                    DiscoveryRow<Device>()
                        .environmentObject(device)
                        .environmentObject(router)
                }
                .refreshable {
                    router.stopScanning()
                    router.startScanning()
                }
                
                let count = router.discovered.count
                
                VStack {
                    ProgressView()
                    Text("Searching for devices...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding()
                }
                .opacity(count == 0 ? 1 : 0)
                .animation(.default.delay(count == 0 ? 2 : 0), value: count)
            }
        }
    }
}
