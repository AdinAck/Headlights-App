//
//  ControlView.swift
//  HeadlightsV2
//
//  Created by Adin Ackerman on 12/6/23.
//

import SwiftUI
import Common

struct ControlView: View {
    @EnvironmentObject var headlight: Headlight
    
    private let config: Config
    
    @State private var target: CGFloat
    @State private var prevTarget: UInt16
    
    @State private var monitor: Monitor
    
    init(control: Control, monitor: Monitor, config: Config) {
        self.target = CGFloat(control.target)
        self.prevTarget = control.target
        
        self.monitor = monitor
        
        self.config = config
    }
    
    var body: some View {
        List {
            LabeledContent("Target") {
                Text("\(UInt16(target))")
            }
            Slider(value: $target, in: 0...CGFloat(config.maxTargetCurrent))
            
            Section("Monitor") {
                GeometryReader { geometry in
                    let width = geometry.size.width
                    
                    HStack(spacing: 0) {
                        Rectangle()
                            .fill(.white)
                            .frame(width: CGFloat(monitor.lowerCurrent) * width / CGFloat(config.maxTargetCurrent), height: 20)
                        LinearGradient(colors: [.white, .clear], startPoint: .leading, endPoint: .trailing)
                            .frame(width: (CGFloat(monitor.upperCurrent) - CGFloat(monitor.lowerCurrent)) * width / CGFloat(config.maxTargetCurrent), height: 20)
                    }
                    .animation(.spring(), value: monitor)
                }
                
                LabeledContent("Duty") {
                    Text("\(Int(monitor.duty)*100/160)%")
                }
                
                LabeledContent("Upper Current") {
                    Text("\(monitor.upperCurrent)")
                }
                
                LabeledContent("Lower Current") {
                    Text("\(monitor.lowerCurrent)")
                }
                
                LabeledContent("Temperature") {
                    Text("\(sampleToCelsius(sample: monitor.temperature))C")
                }
            }
        }
        .task {
            while true {
                let actualTarget = UInt16(target)
                if actualTarget != prevTarget {
                    headlight.send(data: Control(target: actualTarget).serialize(), to: .control)
                    prevTarget = actualTarget
                }
                
                headlight.request(for: .monitor)
                
                guard let _ = try? await Task.sleep(for: .milliseconds(100)) else { return }
            }
        }
        .onChange(of: headlight.control) { _, newValue in
            withAnimation {
                target = CGFloat(newValue.target)
            }
        }
        .onChange(of: headlight.monitor) { _, newValue in
            monitor = newValue
        }
    }
}
