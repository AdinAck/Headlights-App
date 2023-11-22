//
//  PredicateView.swift
//  HeadlightsV2
//
//  Created by Adin Ackerman on 11/4/23.
//

import SwiftUI

struct PredicateView<A: View, B: View>: View {
    let state: () -> Bool
    
    @ViewBuilder let inactive: () -> A
    @ViewBuilder let active: () -> B
    
    init(_ state: @escaping () -> Bool, @ViewBuilder inactive: @escaping () -> A, @ViewBuilder active: @escaping () -> B) {
        self.state = state
        self.inactive = inactive
        self.active = active
    }
    
    var body: some View {
        if state() {
            active()
        } else {
            inactive()
        }
    }
}
