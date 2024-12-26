//
//  ResourceDependent.swift
//  HeadlightsV2
//
//  Created by Adin Ackerman on 11/4/23.
//

import SwiftUI

struct ResourceDependent<T, A: View>: View {
    @Binding var value: T?
    let fresh: Bool
    
    let acquire: () -> Void
    
    @ViewBuilder let active: (Binding<T>) -> A
    
    @State private var waited = false
    
    var body: some View {
        if let value = self.value {
            active(Binding(get: {
                value
            }, set: { newValue in
                print("new: \(newValue)")
                self.value = newValue
            }))
            .onDisappear {
                if fresh {
                    self.value = nil
                }
            }
        } else {
            ProgressView()
                .task {
                    acquire()
                    
                    if let _ = try? await Task.sleep(for: .seconds(2)) {
                        withAnimation {
                            waited = true
                        }
                    }
                }
            
            if waited {
                Button("Retry") {
                    acquire()
                }
                .padding()
            }
        }
    }
}
