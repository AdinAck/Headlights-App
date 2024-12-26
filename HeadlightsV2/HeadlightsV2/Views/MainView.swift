//
//  MainView.swift
//  HeadlightsV2
//
//  Created by Adin Ackerman on 12/5/23.
//

import SwiftUI
import Common

struct MainView: View {
    @EnvironmentObject var headlight: Headlight
    
    @State private var presentAlert = false
    
    var body: some View {
        ResourceDependent(value: $headlight.status, fresh: true) {
            headlight.request(for: .status)
        } active: { $status in
            Group {
                if case let .runtime(runtimeError) = status.error {
                    let notify = UINotificationFeedbackGenerator()
                    
                    VStack {
                        Label("Fault reson: \(String(describing: runtimeError))", systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.red)
                        
                        Button("Reset") {
                            headlight.send(data: Reset.now.serialize(), to: .reset)
                        }
                        .buttonStyle(.bordered)
                        .padding()
                        
                        FactoryResetButton()
                            .environmentObject(headlight)
                            .buttonStyle(.bordered)
                            .padding()
                    }
                    .onAppear {
                        notify.notificationOccurred(.error)
                    }
                } else {
                    NavigationStack {
                        List {
                            Section {
                                NavigationLink("Config") {
                                    ResourceDependent(value: $headlight.config, fresh: true) {
                                        headlight.request(for: .config)
                                    } active: { $config in
                                        ConfigView(config: config)
                                            .environmentObject(headlight)
                                    }
                                    .navigationTitle("Config")
                                }
                                
                                NavigationLink("Control") {
                                    ResourceDependent(value: Binding<(control: Control, monitor: Monitor, config: Config)?>(get: {
                                        guard let control = headlight.control else { return nil }
                                        guard let monitor = headlight.monitor else { return nil }
                                        guard let config = headlight.config else { return nil }
                                        
                                        return (control: control, monitor: monitor, config: config)
                                    }, set: { resources in
                                        if let resources {
                                            headlight.control = resources.control
                                            headlight.monitor = resources.monitor
                                            headlight.config = resources.config
                                        } else {
                                            headlight.control = nil
                                            headlight.monitor = nil
                                            headlight.config = nil
                                        }
                                        
                                    }), fresh: true) {
                                        headlight.request(for: .control)
                                        headlight.request(for: .monitor)
                                        headlight.request(for: .config)
                                    } active: { $resources in
                                        ControlView(control: resources.control, monitor: resources.monitor, config: resources.config)
                                            .environmentObject(headlight)
                                    }
                                    .navigationTitle("Control")
                                }
                                
                                NavigationLink("About") {
                                    AboutView(properties: headlight.properties)
                                        .navigationTitle("About")
                                }
                            }
                            
                            Section {
                                Button("Reset") {
                                    headlight.send(data: Reset.now.serialize(), to: .reset)
                                }
                                
                                FactoryResetButton()
                                    .environmentObject(headlight)
                            }
                            
                            Section {
                                Button("Disconnect") {
                                    headlight.disconnect()
                                }
                            }
                            
                        }
                        .navigationTitle("Diagnostic")
                        .refreshable {
                            headlight.request(for: .status)
                        }
                    }
                }
            }
            .onChange(of: status.error, initial: true) { _, newValue in
                if case .config(_) = status.error {
                    presentAlert = true
                }
            }
            .alert("Config Error", isPresented: $presentAlert, presenting: $status.error) { details in
                Button("Ok") {
                    status.error = .none
                }
                
                Button("Reset") {
                    headlight.send(data: Reset.now.serialize(), to: .reset)
                }
            } message: { details in
                Text("Headlight reported error: \(String(describing: details))")
            }
            .onChange(of: headlight.appError, { _, newValue in
                if let newValue {
                    print("[APP] [ERR] \(String(describing: newValue))")
                }
            })
            .animation(.default, value: status)
        }
    }
}
