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
            theme: @escaping () -> any SourceCodeTheme={ DefaultSourceCodeTheme() }
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
    @Binding private var lexer:Lexer
    @Binding private var theme:CustomSourceCodeTheme?
    @Binding var enableSearch:Bool
    var onSearching:()->Void = {}
    var onSearchResult:(Int)->Void = {_ in }
    var onSearchIndexChanged:(Int)->Void = {_ in }
    
    private var shouldBecomeFirstResponder: Bool
    private var custom: Customization
    private var textView: SyntaxTextView
    
    
    public init(
        text: Binding<String>,
        textPosition: Binding<TextPosition>,
        selectedRange: Binding<NSRange>,
        lexer: Binding<Lexer>,
        theme:Binding<CustomSourceCodeTheme?>,
        enableSearch:Binding<Bool>,
        onSearching:@escaping ()->Void = {},
        onSearchResult:@escaping (Int)->Void = {_ in },
        onSearchIndexChanged:@escaping (Int)->Void = {_ in },
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
        self._lexer = lexer
        self._enableSearch = enableSearch
        self.custom = customization
        self.onSearching = onSearching
        self.onSearchResult = onSearchResult
        self.onSearchIndexChanged = onSearchIndexChanged
        self.shouldBecomeFirstResponder = shouldBecomeFirstResponder
        self.textView = SyntaxTextView()
    }
    
    public var undoManage:MyUndoManager?{
        get{
            textView.undoManager
        }
        set{
            textView.undoManager = newValue
        }
    }
    
    public var innerTextView:InnerTextView{
        textView.textView
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
        wrappedView.lexer = lexer
        wrappedView.enableSearch = enableSearch
        wrappedView.onSearchResult = onSearchResult
        wrappedView.onSearching = onSearching
        wrappedView.onSearchIndexChanged = onSearchIndexChanged
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
        if view.theme != theme{
            view.theme = theme
        }
        if view.previousSelectedRange != selectedRange{
            view.previousSelectedRange = selectedRange
        }
        if view.text != text{
            view.text = text
        }
        if view.lexer?.id != lexer.id{
            view.lexer = lexer
        }
        if view.enableSearch != enableSearch{
            view.enableSearch = enableSearch
        }
        view.onSearchResult = onSearchResult
        view.onSearching = onSearching
        view.onSearchIndexChanged = onSearchIndexChanged
    }
    #endif
    
    #if os(macOS)
    public func makeNSView(context: Context) -> SyntaxTextView {
        let wrappedView = SyntaxTextView()
        wrappedView.delegate = context.coordinator
        wrappedView.theme = theme
        wrappedView.lexer = lexer
        wrappedView.enableSearch = enableSearch
        wrappedView.onSearchResult = onSearchResult
        wrappedView.onSearching = onSearching
        wrappedView.onSearchIndexChanged = onSearchIndexChanged
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
        view.lexer = lexer
        view.theme = theme
        view.enableSearch = enableSearch
        view.onSearchResult = onSearchResult
        view.onSearching = onSearching
        view.onSearchIndexChanged = onSearchIndexChanged
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

// MARK: - 跳转
extension SourceCodeTextEditor{
    public func goLine(_ line:Int){
        textView.goLine(line)
    }
    
    public func goRange(_ range:NSRange,getFocus:Bool=true){
        textView.setSeletctTextRange(range,getFocus:getFocus)
    }
}

//MARK: - 查找替换
extension SourceCodeTextEditor{
    public func jumpToSearchResult(for index:Int,getFocus:Bool=false){
        textView.jumpToSearchResult(for: index, getFocus: getFocus)
    }
    
    public func search(key: String, options: ContentSearchOptions){
        textView.search(key: key, options: options)
    }
    public func replace(index:Int,replaceTo:String,callback:@escaping () -> Void){
        textView.replace(index: index, replaceTo: replaceTo, callback: callback)
    }
    public func replaceAll(key:String,to replaceText:String, options:ContentSearchOptions,callback:@escaping () -> Void){
        textView.replaceAll(key: key, to: replaceText, options: options, callback: callback)
    }
}

//MARK: - 撤销/重做
extension SourceCodeTextEditor{
    public var canUndo:Bool{
        textView.canUndo
    }
    public var canRedo:Bool{
        textView.canRedo
    }
    
    public func undo(){
        textView.undo()
    }
    
    public func redo(){
        textView.redo()
    }
}

#endif

