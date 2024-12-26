//
//  NumberInput.swift
//  HeadlightsV2
//
//  Created by Adin Ackerman on 12/5/23.
//

import SwiftUI

struct NumberInput<T>: View where T: Numeric, T: LosslessStringConvertible {
    @Binding var value: T
    
    @State private var localString = ""
    
    @FocusState private var focused: Bool
    
    init(value: Binding<T>) {
        self._value = value
        self.localString = value.wrappedValue.description
        self.focused = false
    }
    
    var body: some View {
        TextField("", text: Binding(get: {
            value.description
        }, set: { string in
            localString = string
        }))
            .textFieldStyle(.roundedBorder)
            .keyboardType(.numberPad)
            .focused($focused)
            .toolbar {
                if focused { // fixes duplicate toolbar bug
                    ToolbarItemGroup(placement: .keyboard) {
                        Button("Cancel") {
                            localString = value.description
                            focused = false
                        }
                        .tint(.red)
                        
                        Spacer()
                        
                        Button("Done") {
                            value = T.init(localString)!
                            focused = false
                        }
                        .disabled(T.init(localString) == nil)
                    }
                }
            }
            .onChange(of: focused, initial: true) { _, newValue in
                localString = value.description
            }
    }
}

private struct PreviewNumberInput: View {
    @State var value = 55
    
    var body: some View {
        NumberInput<Int>(value: $value)
    }
}

#Preview {
    PreviewNumberInput()
}
