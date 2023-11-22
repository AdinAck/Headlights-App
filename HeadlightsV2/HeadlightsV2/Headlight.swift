//
//  Headlight.swift
//  HeadlightsV2
//
//  Created by Adin Ackerman on 9/8/23.
//

import Foundation
import SwiftUI
import CoreBluetooth
import Combine

enum EndPoint {
    case request,
         status,
         brightness,
        monitor,
        pid
}

class Headlight: BLEDevice {
    static let SERVICE_UUID = CBUUID(string: "0b2adcf1-38a7-48f9-a61d-8311fe471b70")
    
    @Published var status: HeadlightStatusPacket!
    @Published var brightness: HeadlightBrightnessPacket!
    @Published var monitor: HeadlightMonitorPacket!
    @Published var pid: HeadlightPIDPacket!
    
    private var characteristic_uuids: [CBUUID: EndPoint] = [
        CBUUID(string: "9a00bcc5-89f1-4b9d-88bd-f2033440a5b4"): .request,
        CBUUID(string: "ccf82e46-5f1c-4671-b481-7ffd2854fed4"): .status,
        CBUUID(string: "eb483eeb-7b8e-45e0-910b-6c88fb3d75f3"): .brightness,
        CBUUID(string: "30f62c01-d9d8-4c14-9a66-36ad0d92edbf"): .monitor,
        CBUUID(string: "73e4b52c-4ae2-4901-b78b-8f95f3a60cdb"): .pid
    ]
    
    private let notify: [EndPoint] = [
        .status,
        .brightness,
        .monitor,
        .pid
    ]
    
    private var characteristics: [EndPoint: CBCharacteristic] = [:]
    private var ble_dispatch: [EndPoint: (CBCharacteristic) -> Void] = [:]
    
    required init(peripheral: CBPeripheral, disconnect: @escaping (CBPeripheral) -> Void) {
        super.init(peripheral: peripheral, disconnect: disconnect)
        
        // init dispatch
        ble_dispatch = [
            .status: { characteristic in
                if let status = HeadlightStatusPacket(from: characteristic.value!) {
                    self.status = status
                } else {
                    print("[BLE] [WARN] Received bad value for \"status\".")
                }
            },
            .brightness: { characteristic in
                if let brightness = HeadlightBrightnessPacket(from: characteristic.value!) {
                    self.brightness = brightness
                } else {
                    print("[BLE] [WARN] Received bad value for \"brightness\".")
                }
            },
            .monitor: { characteristic in
                if let monitor = HeadlightMonitorPacket(from: characteristic.value!) {
                    self.monitor = monitor
                } else {
                    print("[BLE] [WARN] Received bad value for \"monitor\".")
                }
            },
            .pid: { characteristic in
                if let pid = HeadlightPIDPacket(from: characteristic.value!) {
                    self.pid = pid
                } else {
                    print("[BLE] [WARN] Received bad value for \"pid\".")
                }
            },
        ]
    }
    
    func load() {
        print("[BLE] [INFO] Discovering services for peripheral with uuid: \(peripheral.identifier).")
        peripheral.discoverServices([Self.SERVICE_UUID])
    }
    
    func request(for request: HeadlightRequest) {
        peripheral.writeValue(Data([request.rawValue]), for: characteristics[.request]!, type: .withResponse)
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard let services = peripheral.services else { return }
        
        print("[BLE] [INFO] Discovered services: \(services)")
        
        for service in services {
            print("[BLE] [INFO] Discovering characteristics for service: \(service)")
            peripheral.discoverCharacteristics(characteristic_uuids.keys.shuffled() /* idk about this */, for: service)
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard let discovered = service.characteristics else { return }
        
        for characteristic in discovered {
            characteristics[
                characteristic_uuids[
                    characteristic.uuid
                ]!
            ] = characteristic
        }
        
        guard characteristics.count == characteristic_uuids.count else {
            withAnimation {
                invalid_characteristics = true
            }
            
            disconnect()
            print("[BLE] [INFO] Device is invalid. (insufficient characteristics):")
            
            for endpoint in characteristic_uuids.values {
                if !characteristics.keys.contains(endpoint) {
                    print("\t - Missing \"\(endpoint)\"...")
                }
            }
            
            return
        }
        
        for endpoint in notify {
            peripheral.setNotifyValue(true, for: characteristics[endpoint]!)
        }
        
        withAnimation {
            loaded = true
        }
        
        print("[BLE] [INFO] All expected characteristics discovered.")
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        guard let endpoint = characteristic_uuids[characteristic.uuid] else {
            print("[BLE] [WARN] Received value for characteristic with uuid \"\(characteristic.uuid)\" with no associated endpoint.")
            return
        }
        guard let dispatched = ble_dispatch[endpoint] else {
            print("[BLE] [WARN] No dispatch handler for endpoint \"\(endpoint)\" is defined.")
            return
        }
        
//        print("[BLE] [INFO] New value for \"\(endpoint)\".")
        
        withAnimation {
            dispatched(characteristic)
        }
    }
}

struct HeadlightView: View {
    @EnvironmentObject var model: Headlight
    
    var body: some View {
        PredicateView {
            model.status != nil &&
            model.brightness != nil &&
            model.monitor != nil &&
            model.pid != nil
        } inactive: {
            VStack {
                ProgressView()
                    .frame(maxHeight: .infinity)
                
                Button("Disconnect") {
                    model.disconnect()
                }
                .buttonStyle(.borderedProminent)
                .padding()
            }
        } active: {
            List {
                Section("Status") {
                    HStack {
                        Text("State")
                        Spacer()
                        Text("\(model.status.state.rawValue)")
                            .foregroundStyle(.secondary)
                    }
                    
                    HStack {
                        Text("Error")
                        Spacer()
                        Text("\(model.status.error.rawValue)")
                            .foregroundStyle(.secondary)
                    }
                }
                
                Section("Brightness") {
                    HStack {
                        Text("Brightness")
                        Spacer()
                        Text("\(model.brightness.brightness)")
                            .foregroundStyle(.secondary)
                    }
                }
                
                Section("Monitor") {
                    HStack {
                        Text("Duty")
                        Spacer()
                        Text("\(model.monitor.duty)")
                            .foregroundStyle(.secondary)
                    }
                    
                    HStack {
                        Text("Current")
                        Spacer()
                        Text("\(model.monitor.current)")
                            .foregroundStyle(.secondary)
                    }
                    
                    HStack {
                        Text("Temperature")
                        Spacer()
                        Text("\(model.monitor.temperature)")
                            .foregroundStyle(.secondary)
                    }
                }
                
                Section("PIDs") {
                    HStack {
                        Text("k_p")
                        Spacer()
                        Text("\(model.pid.k_p)")
                            .foregroundStyle(.secondary)
                    }
                    
                    HStack {
                        Text("k_i")
                        Spacer()
                        Text("\(model.pid.k_i)")
                            .foregroundStyle(.secondary)
                    }
                    
                    HStack {
                        Text("k_d")
                        Spacer()
                        Text("\(model.pid.k_d)")
                            .foregroundStyle(.secondary)
                    }
                    
                    HStack {
                        Text("div")
                        Spacer()
                        Text("\(model.pid.div)")
                            .foregroundStyle(.secondary)
                    }
                }
                
                Button("Disconnect") {
                    model.disconnect()
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .onAppear {
            model.request(for: .status)
            model.request(for: .brightness)
            model.request(for: .monitor)
        }
    }
}
