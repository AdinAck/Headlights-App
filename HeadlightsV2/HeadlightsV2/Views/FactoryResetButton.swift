//
//  FactoryResetButton.swift
//  HeadlightsV2
//
//  Created by Adin Ackerman on 12/7/23.
//

import SwiftUI
import Common

struct FactoryResetButton: View {
    @EnvironmentObject var headlight: Headlight
    
    @State private var presentAlert = false
    
    var body: some View {
        Button(role: .destructive) {
            presentAlert = true
        } label: {
            Text("Reset to Factory Defaults")
        }
        .alert("Confirm Factory Reset", isPresented: $presentAlert) {
            Button(role: .destructive) {
                headlight.send(data: Reset.factory.serialize(), to: .reset)
            } label: {
                Text("Factory Reset")
            }
        } message: {
            Text("Are you sure you want to factory reset? (This action cannot be undone)")
        }

    }
}

#Preview {
    FactoryResetButton()
}
