//
//  ContentView.swift
//  HeadlightsV2
//
//  Created by Adin Ackerman on 9/8/23.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var scanner = BLERouter<Headlight>(scan: [Headlight.SERVICE_UUID], count: 1)
    
    var body: some View {
        scanner.discovery { devices in
            if let first = devices.first {
                HeadlightView()
                    .environmentObject(first)
            }
        }
    }
}

//struct ContentView_Previews: PreviewProvider {
//    static var previews: some View {
//        ContentView()
//    }
//}
