import SwiftUI
import UIKit

extension View {
    /// A "Done" button above the keyboard. Number pads have no Return key, and a TextField bound with
    /// `value:format:` only saves its value on Return or when it loses focus, so without this a form's
    /// Next/Save can stay disabled after the last number is typed.
    func keyboardDoneButton() -> some View {
        toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") {
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                }
            }
        }
    }
}
