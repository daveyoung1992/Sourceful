//
//  SourceCodeTextEditor.swift
//
//  Created by Andrew Eades on 14/08/2020.
//

import Foundation

#if canImport(SwiftUI)

import SwiftUI

#if os(macOS)

public typealias _ViewRepresentable = NSViewRepresentable

#endif

#if os(iOS)

public typealias _ViewRepresentable = UIViewRepresentable

#endif


public struct SourceCodeTextEditor: _ViewRepresentable {
    
    public struct Customization {
        var didChangeText: (SourceCodeTextEditor) -> Void
        var didChangeSelectedRange: (SourceCodeTextEditor,NSRange,TextPosition) -> Void
        var insertionPointColor: () -> Sourceful.Color
        var lexerForSource: (String) -> Lexer
        var textViewDidBeginEditing: (SourceCodeTextEditor) -> Void
        
        /// Creates a **Customization** to pass into the *init()* of a **SourceCodeTextEditor**.
        ///
        /// - Parameters:
        ///     - didChangeText: A SyntaxTextView delegate action.
        ///     - lexerForSource: The lexer to use (default: SwiftLexer()).
        ///     - insertionPointColor: To customize color of insertion point caret (default: .white).
        ///     - textViewDidBeginEditing: A SyntaxTextView delegate action.
        ///     - theme: Custom theme (default: DefaultSourceCodeTheme()).
        public init(
            didChangeText: @escaping (SourceCodeTextEditor) -> Void={_ in },
            didChangeSelectedRange: @escaping (SourceCodeTextEditor,NSRange,TextPosition) -> Void={_,_,_ in},
            insertionPointColor: @escaping () -> Sourceful.Color={ Sourceful.Color.white },
            lexerForSource: @escaping (String) -> Lexer={ _ in EmptyLexer() },
            textViewDidBeginEditing: @escaping (SourceCodeTextEditor) -> Void={ _ in },
            theme: @escaping () -> SourceCodeTheme={ DefaultSourceCodeTheme() }
        ) {
            self.didChangeText = didChangeText
            self.didChangeSelectedRange = didChangeSelectedRange
            self.insertionPointColor = insertionPointColor
            self.lexerForSource = lexerForSource
            self.textViewDidBeginEditing = textViewDidBeginEditing
        }
    }
    
    @Binding var text: String
    @Binding private var textPosition: TextPosition
    @Binding private var selectedRange:NSRange
    @Binding private var theme:SourceCodeTheme
    private var shouldBecomeFirstResponder: Bool
    private var custom: Customization
    private var textView: SyntaxTextView
    
    public init(
        text: Binding<String>,
        textPosition: Binding<TextPosition>,
        selectedRange: Binding<NSRange>,
        theme:Binding<SourceCodeTheme>,
        customization: Customization = Customization(
            didChangeText: {_ in },
            didChangeSelectedRange: {_,_,_ in},
            insertionPointColor: { Sourceful.Color.white },
            lexerForSource: { _ in EmptyLexer() },
            textViewDidBeginEditing: { _ in }
        ),
        shouldBecomeFirstResponder: Bool = false
    ) {
        self._text = text
        self._textPosition = textPosition
        self._selectedRange = selectedRange
        self._theme = theme
        self.custom = customization
        self.shouldBecomeFirstResponder = shouldBecomeFirstResponder
        self.textView = SyntaxTextView()
    }
    
    public func goLine(_ line:Int){
        textView.goLine(line)
    }
    
    public func goRange(_ range:NSRange){
        textView.setSeletctTextRange(range)
    }
    
    public func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    public var previousSelectedRange:NSRange?{
        get{
            textView.previousSelectedRange
        }
        set{
            textView.previousSelectedRange = newValue
        }
    }
    
    #if os(iOS)

    public func becomeFirstResponder() -> Bool {
        return textView.becomeFirstResponder()
    }
    
    public func resignFirstResponder() -> Bool {
        return textView.resignFirstResponder()
    }
    public func makeUIView(context: Context) -> SyntaxTextView {
        let wrappedView = textView
        wrappedView.delegate = context.coordinator
        wrappedView.theme = theme
//        wrappedView.contentTextView.insertionPointColor = custom.insertionPointColor()
        
        context.coordinator.wrappedView = wrappedView
        context.coordinator.wrappedView.previousSelectedRange = selectedRange
        context.coordinator.wrappedView.text = text
        
        return wrappedView
    }
    
    public func updateUIView(_ view: SyntaxTextView, context: Context) {
        if shouldBecomeFirstResponder {
            view.becomeFirstResponder()
        }
        view.theme = theme
        view.previousSelectedRange = selectedRange
        view.text = text
    }
    #endif
    
    #if os(macOS)
    public func makeNSView(context: Context) -> SyntaxTextView {
        let wrappedView = SyntaxTextView()
        wrappedView.delegate = context.coordinator
        wrappedView.theme = custom.theme()
        wrappedView.contentTextView.insertionPointColor = custom.insertionPointColor()
        
        context.coordinator.wrappedView = wrappedView
        context.coordinator.wrappedView.text = text
        context.coordinator.wrappedView.previousSelectedRange = selectedRange
        context.coordinator.wrappedView.selectedRange = selectedRange
        
        return wrappedView
    }
    
    public func updateNSView(_ view: SyntaxTextView, context: Context) {
        view.text = text
        view.previousSelectedRange = selectedRange
        view.selectedRange = selectedRange
    }
    #endif
    

}

extension SourceCodeTextEditor {
    
    public class Coordinator: SyntaxTextViewDelegate {
        let parent: SourceCodeTextEditor
        var wrappedView: SyntaxTextView!
        
        init(_ parent: SourceCodeTextEditor) {
            self.parent = parent
        }
        
        public func lexerForSource(_ source: String) -> Lexer {
            parent.custom.lexerForSource(source)
        }
        
        public func didChangeSelectedRange(_ syntaxTextView: SyntaxTextView, selectedRange: NSRange, textPosition:TextPosition){
            if self.parent.textPosition != textPosition || self.parent.selectedRange != selectedRange{
                self.parent.textPosition = textPosition
                self.parent.selectedRange = selectedRange
                parent.custom.didChangeSelectedRange(parent,selectedRange,textPosition)
            }
        }
        
        public func didChangeText(_ syntaxTextView: SyntaxTextView) {
            DispatchQueue.main.async {
                self.parent.text = syntaxTextView.text
                self.parent.custom.didChangeText(self.parent)
            }
        }
        
        public func textViewDidBeginEditing(_ syntaxTextView: SyntaxTextView) {
            parent.custom.textViewDidBeginEditing(parent)
        }
    }
}

#endif

