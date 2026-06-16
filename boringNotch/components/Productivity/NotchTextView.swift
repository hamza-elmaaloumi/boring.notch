import SwiftUI

struct NotchTextView: NSViewRepresentable {
    @Binding var text: String
    var placeholder: String = ""
    var textColor: NSColor = .white
    var font: NSFont = .systemFont(ofSize: 11)

    func makeNSView(context: Context) -> NSTextView {
        let textView = NotchNSTextView()
        textView.isEditable = true
        textView.isSelectable = true
        textView.isRichText = false
        textView.font = font
        textView.textColor = textColor
        textView.drawsBackground = false
        textView.delegate = context.coordinator
        textView.allowsUndo = true

        textView.string = text
        return textView
    }

    func updateNSView(_ nsView: NSTextView, context: Context) {
        if nsView.string != text {
            nsView.string = text
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text)
    }

    class Coordinator: NSObject, NSTextViewDelegate {
        @Binding var text: String

        init(text: Binding<String>) {
            _text = text
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            text = textView.string
        }
    }
}

private class NotchNSTextView: NSTextView {
    override var acceptsFirstResponder: Bool { true }

    override func becomeFirstResponder() -> Bool {
        let result = super.becomeFirstResponder()
        if result {
            (window as? BoringNotchSkyLightWindow)?.allowsTextInput = true
        }
        return result
    }

    override func resignFirstResponder() -> Bool {
        let result = super.resignFirstResponder()
        if result {
            (window as? BoringNotchSkyLightWindow)?.allowsTextInput = false
        }
        return result
    }

    override var acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }
}
