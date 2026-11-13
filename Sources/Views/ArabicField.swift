import SwiftUI
import UIKit

/// خانة كتابة مبنية على UITextField الأصلية (مثل واتساب) بدل TextField في SwiftUI،
/// على أمل أن تُظهر لوحة المفاتيح العربية أرقامها العربية. الأرقام الإنجليزية تُحوَّل إلى عربية أثناء الكتابة.
struct ArabicField: UIViewRepresentable {
    @Binding var text: String
    var placeholder: String
    @Binding var isFocused: Bool
    var onSubmit: () -> Void

    func makeUIView(context: Context) -> UITextField {
        let tf = UITextField()
        tf.placeholder = placeholder
        tf.font = UIFont.preferredFont(forTextStyle: .body)
        tf.adjustsFontForContentSizeCategory = true
        tf.textColor = UIColor(hex: 0x2B1E16)
        tf.tintColor = UIColor(hex: 0x4A3326)
        tf.textAlignment = .natural
        tf.returnKeyType = .next
        tf.autocorrectionType = .no
        tf.delegate = context.coordinator
        tf.addTarget(context.coordinator, action: #selector(Coordinator.changed(_:)), for: .editingChanged)
        tf.setContentHuggingPriority(.defaultLow, for: .horizontal)
        tf.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return tf
    }

    func updateUIView(_ tf: UITextField, context: Context) {
        context.coordinator.parent = self
        if tf.text != text { tf.text = text }
        if isFocused && !tf.isFirstResponder {
            DispatchQueue.main.async { tf.becomeFirstResponder() }
        } else if !isFocused && tf.isFirstResponder {
            DispatchQueue.main.async { tf.resignFirstResponder() }
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, UITextFieldDelegate {
        var parent: ArabicField
        init(_ parent: ArabicField) { self.parent = parent }

        @objc func changed(_ tf: UITextField) {
            let v = Fmt.ar(tf.text ?? "")
            if tf.text != v { tf.text = v }
            parent.text = v
        }

        func textFieldDidBeginEditing(_ tf: UITextField) {
            if !parent.isFocused { DispatchQueue.main.async { self.parent.isFocused = true } }
        }

        func textFieldDidEndEditing(_ tf: UITextField) {
            if parent.isFocused { DispatchQueue.main.async { self.parent.isFocused = false } }
        }

        func textFieldShouldReturn(_ tf: UITextField) -> Bool {
            parent.onSubmit()
            return false
        }
    }
}
