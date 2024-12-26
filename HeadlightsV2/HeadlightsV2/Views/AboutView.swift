//
//  AboutView.swift
//  HeadlightsV2
//
//  Created by Adin Ackerman on 12/13/23.
//

import SwiftUI
import Common

struct AboutView: View {
    let properties: Properties
    
    var body: some View {
        List {
            Section("Version") {
                LabeledContent("Hardware") {
                    Text("\(String(describing: properties.version.hw))")
                }
                
                LabeledContent("Firmware") {
                    Text("\(String(describing: properties.version.fw))")
                }
            }
            
            Section("Safety Limits") {
                LabeledContent("Abs. Max. Current") {
                    Text("\(properties.absMaxMa)mA")
                }
                
                LabeledContent("Abs. Max. Temp") {
                    Text("\(sampleToCelsius(sample: properties.absMaxTemp))C")
                }
                
                LabeledContent("Min. PWM Freq.") {
                    Text("\(properties.minPwmFreq)kHz")
                }
                
                LabeledContent("Max. PWM Freq.") {
                    Text("\(properties.maxPwmFreq)kHz")
                }
                
                LabeledContent("Max ADC Error") {
                    Text("\(properties.maxAdcError)mA")
                }
            }
        }
    }
}

#Preview {
    AboutView(properties: Properties(version: Version(hw: Hardware.v2Rev3, fw: Firmware.v0p1), absMaxMa: 1000, absMaxTemp: 2511, minPwmFreq: 50, maxPwmFreq: 500, maxAdcError: 10))
}
