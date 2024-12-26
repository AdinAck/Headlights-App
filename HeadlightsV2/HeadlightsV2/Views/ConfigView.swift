//
//  ConfigView.swift
//  HeadlightsV2
//
//  Created by Adin Ackerman on 12/5/23.
//

import SwiftUI
import Common

struct ConfigView: View {
    @EnvironmentObject var headlight: Headlight
    
    @State var localConfig: Config
    
    init(config: Config) {
        self.localConfig = config
    }
    
    var body: some View {
        VStack {
            NavigationStack {
                List {
                    Section("Startup") {
                        Toggle(isOn: $localConfig.enabled) {
                            Text("Enabled")
                        }
                        
                        LabeledContent("Target") {
                            NumberInput(value: $localConfig.startupControl.target)
                                .frame(maxWidth: 100)
                            Text("mA")
                        }
                    }
                    
                    Section("Load") {
                        LabeledContent("Max Target Current") {
                            NumberInput(value: $localConfig.maxTargetCurrent)
                                .frame(maxWidth: 100)
                            Text("mA")
                        }
                        
                        LabeledContent("Absolute Max. Load Current") {
                            NumberInput(value: $localConfig.absMaxLoadCurrent)
                                .frame(maxWidth: 100)
                            Text("mA")
                        }
                    }
                    
                    Section("Regulation") {
                        LabeledContent("Gain") {
                            NumberInput(value: $localConfig.gain)
                                .frame(maxWidth: 100)
                        }
                        
                        LabeledContent("PWM Frequency") {
                            NumberInput(value: $localConfig.pwmFreq)
                                .frame(maxWidth: 100)
                            Text("kHz")
                        }
                    }
                    
                    Section("Temperature") {
                        LabeledContent("Throttle Start") {
                            NumberInput(value: $localConfig.throttleStart)
                                .frame(maxWidth: 100)
                            Text("kHz")
                        }
                        
                        LabeledContent("Throttle Stop") {
                            NumberInput(value: $localConfig.throttleStop)
                                .frame(maxWidth: 100)
                            Text("kHz")
                        }
                    }
                }
                .refreshable {
                    localConfig = headlight.config
                }
            }
            
            HStack {
                Button("Save") {
                    headlight.send(data: localConfig.serialize(), to: .config)
                    headlight.request(for: .config)
                }
                .buttonStyle(.borderedProminent)
                .padding()
                .disabled(localConfig == headlight.config)
            }
        }
    }
}
