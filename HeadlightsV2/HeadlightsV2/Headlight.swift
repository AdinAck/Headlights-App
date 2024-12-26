//
//  Headlight.swift
//  HeadlightsV2
//
//  Created by Adin Ackerman on 9/8/23.
//

import Foundation
import SwiftUI
import CoreBluetooth
import Common

enum EndPoint {
    case properties,
         request,
         status,
         control,
         monitor,
         config,
         reset,
         appError
}

class Headlight: BLEDevice {
    static let SERVICE_UUID = CBUUID(string: "0b2adcf1-38a7-48f9-a61d-8311fe471b70")
    
    @Published var properties: Properties!
    @Published var status: Status!
    @Published var control: Control!
    @Published var monitor: Monitor!
    @Published var config: Config!
    @Published var appError: AppError!
    
    private let characteristic_uuids: [CBUUID: EndPoint] = [
        CBUUID(string: "939f1423-2a0f-4a87-931f-5dae0b1ded7a"): .properties,
        CBUUID(string: "9a00bcc5-89f1-4b9d-88bd-f2033440a5b4"): .request,
        CBUUID(string: "ccf82e46-5f1c-4671-b481-7ffd2854fed4"): .status,
        CBUUID(string: "eb483eeb-7b8e-45e0-910b-6c88fb3d75f3"): .control,
        CBUUID(string: "30f62c01-d9d8-4c14-9a66-36ad0d92edbf"): .monitor,
        CBUUID(string: "73e4b52c-4ae2-4901-b78b-8f95f3a60cdb"): .config,
        CBUUID(string: "a7e05ec9-ed47-49fe-8b5b-4d030c687032"): .reset,
        CBUUID(string: "a16bc310-eb50-414e-87b3-2199e79523c2"): .appError,
    ]
    
    private let notify: [EndPoint] = [
        .status,
        .control,
        .monitor,
        .config,
        .appError
    ]
    
    private var characteristics: [EndPoint: CBCharacteristic] = [:]
    private var ble_dispatch: [EndPoint: (CBCharacteristic) -> Void] = [:]
    
    required init(peripheral: CBPeripheral, disconnect: @escaping (CBPeripheral) -> Void) {
        super.init(peripheral: peripheral, disconnect: disconnect)
        
        // init dispatch
        ble_dispatch = [
            .status: { characteristic in
                if let status = Status(from: characteristic.value!) {
                    self.status = status
                }
            },
            .control: { characteristic in
                if let control = Control(from: characteristic.value!) {
                    self.control = control
                }
            },
            .monitor: { characteristic in
                if let monitor = Monitor(from: characteristic.value!) {
                    self.monitor = monitor
                }
            },
            .config: { characteristic in
                if let config = Config(from: characteristic.value!) {
                    self.config = config
                }
            },
            .appError: { characteristic in
                if let appError = AppError(from: characteristic.value!) {
                    self.appError = appError
                }
            },
        ]
    }
    
    func load() {
        print("[BLE] [INFO] Discovering services for peripheral with uuid: \(peripheral.identifier).")
        peripheral.discoverServices([Self.SERVICE_UUID])
    }
    
    func request(for request: Request) {
        send(data: request.serialize(), to: .request)
    }
    
    /*
     special because it does not necessitate
     UART usage, and is constant within a
     firmware version
     */
    func getProperties() {
        peripheral.readValue(for: characteristics[.properties]!)
    }
    
    func send(data: Data, to endpoint: EndPoint) {
        peripheral.writeValue(data, for: characteristics[endpoint]!, type: .withResponse)
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
        
        // only finalize connection once properties are loaded
        getProperties()
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        if loaded == false && characteristic_uuids[characteristic.uuid] == .properties {
            guard let properties = Properties(from: characteristic.value!) else { return }
            self.properties = properties
            
            withAnimation {
                loaded = true
            }
            
            print("[BLE] [INFO] All expected characteristics discovered and device properties loaded.")
        } else {
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
}
