//
//  SyntaxTextView.swift
//  SavannaKit
//
//  Created by Louis D'hauwe on 23/01/2017.
//  Copyright © 2017 Silver Fox. All rights reserved.
//

import Foundation
import CoreGraphics

#if os(macOS)
import AppKit
#else
import UIKit
#endif

public protocol SyntaxTextViewDelegate: AnyObject {

    func didChangeText(_ syntaxTextView: SyntaxTextView)

    func didChangeSelectedRange(_ syntaxTextView: SyntaxTextView, selectedRange: NSRange, textPosition:TextPosition)

    func textViewDidBeginEditing(_ syntaxTextView: SyntaxTextView)

    func lexerForSource(_ source: String) -> Lexer

}

// Provide default empty implementations of methods that are optional.
public extension SyntaxTextViewDelegate {
    func didChangeText(_ syntaxTextView: SyntaxTextView) { }

    func didChangeSelectedRange(_ syntaxTextView: SyntaxTextView, selectedRange: NSRange, textPosition:TextPosition) { }

    func textViewDidBeginEditing(_ syntaxTextView: SyntaxTextView) { }
}

struct ThemeInfo {

    let theme: any SyntaxColorTheme

    /// Width of a space character in the theme's font.
    /// Useful for calculating tab indent size.
    let spaceWidth: CGFloat

}



public struct ContentSearchOptions:Decodable{
    public var caseSensitive:Bool
    public var matchMode:MatchMode
    public static var defaultValue:ContentSearchOptions = .init(caseSensitive: false, matchMode: .contains)
}

public enum MatchMode:Int,Decodable, CaseIterable, Identifiable{
    case contains
    case matchesWord
    case startsWith
    case endsWith
    case regex
    
    public var id: Self { self }
}

@IBDesignable
open class SyntaxTextView: _View {

    var previousSelectedRange: NSRange?

    private var textViewSelectedRangeObserver: NSKeyValueObservation?

    let textView: InnerTextView

    public var contentTextView: TextView {
        return textView
    }

    public weak var delegate: SyntaxTextViewDelegate? {
        didSet {
            refreshColors()
        }
    }
    
    open override var undoManager: MyUndoManager?{
        get{
            textView.myUndoManager
        }
        set{
            textView.myUndoManager = newValue
        }
    }

    var ignoreSelectionChange = false
    
    var updateColorTimer:Timer?
    var refreshTimer:Timer?
    var updateID:UUID = UUID()
    
    var lexer:Lexer?{
        didSet{
            refreshColors()
        }
    }

    #if os(macOS)

    let wrapperView = TextViewWrapperView()

    #endif

    #if os(iOS)

    public var contentInset: UIEdgeInsets = .zero {
        didSet {
            textView.contentInset = contentInset
            textView.scrollIndicatorInsets = contentInset
        }
    }

    open override var tintColor: UIColor! {
        didSet {

        }
    }

    #else

    public var tintColor: NSColor! {
        set {
            textView.tintColor = newValue
        }
        get {
            return textView.tintColor
        }
    }

    #endif
    
    public override init(frame: CGRect) {
        textView = SyntaxTextView.createInnerTextView()
        super.init(frame: frame)
        textView.parent = self
        textView.undoManager?.disableUndoRegistration()
        setup()
    }
    
    public required init?(coder aDecoder: NSCoder) {
        textView = SyntaxTextView.createInnerTextView()
        super.init(coder: aDecoder)
        textView.parent = self
        textView.undoManager?.disableUndoRegistration()
        setup()
    }
    
    deinit {
        searchTimer?.invalidate()
        refreshTimer?.invalidate()
        updateColorTimer?.invalidate()
    }
    
    public var selectedRange:NSRange{
        get{
            textView.selectedRange
        }
        set{
            textView.selectedRange = newValue
        }
    }
    
    public var isEditable:Bool{
        get{
            textView.isEditable
        }
        set{
            textView.isEditable = newValue
        }
    }

    private static func createInnerTextView() -> InnerTextView {
        let textStorage = NSTextStorage()
        let layoutManager = SyntaxTextViewLayoutManager()
        #if os(macOS)
        let containerSize = CGSize(width: 0, height: CGFloat.greatestFiniteMagnitude)
        #endif

        #if os(iOS)
        let containerSize = CGSize(width: 0, height: 0)
        #endif

        let textContainer = NSTextContainer(size: containerSize)
        
        textContainer.widthTracksTextView = true

        #if os(iOS)
        textContainer.heightTracksTextView = true
        #endif
        layoutManager.addTextContainer(textContainer)
        textStorage.addLayoutManager(layoutManager)
        
        return InnerTextView(frame: .zero, textContainer: textContainer)
    }
    
    func getTextPostion(for range:NSRange)->TextPosition{
        for item in self.textView.lineRanges{
            if item.range.location<=range.location && item.range.location+item.range.length>=range.location{
                return TextPosition(rows: item.lineNumber, cols: range.location-item.range.location+1)
            }
        }
        return .zero
    }
    
    func goLine(_ line:Int){
        let pos = 0
        let rows:Int = max(0,line - 1)
        if self.textView.lineRanges.count > 0{
            let lineRange:LineRange
            if rows >= self.textView.lineRanges.count {
                lineRange = self.textView.lineRanges.last!
            }
            else{
                lineRange = self.textView.lineRanges[rows]
            }
            updateSelectedRange(NSRange(location: lineRange.range.location, length: 0))
            self.becomeFirstResponder()
        }
    }
    
    func setSeletctTextRange(_ range:NSRange,getFocus:Bool=true){
        updateSelectedRange(range)
        if getFocus{
            self.becomeFirstResponder()
        }
        else{
            if let cursorPosition = textView.selectedTextRange?.start{
                let caretRect = textView.caretRect(for: cursorPosition)
                textView.scrollRectToVisible(caretRect, animated: true)
            }
        }
    }

    #if os(macOS)

    public let scrollView = NSScrollView()

    #endif

    private func setup() {

        textView.gutterWidth = 20

        #if os(iOS)

        textView.translatesAutoresizingMaskIntoConstraints = false

        #endif

        #if os(macOS)

        wrapperView.translatesAutoresizingMaskIntoConstraints = false

        scrollView.backgroundColor = .clear
        scrollView.drawsBackground = false

        scrollView.contentView.backgroundColor = .clear

        scrollView.translatesAutoresizingMaskIntoConstraints = false

        addSubview(scrollView)

        addSubview(wrapperView)


        scrollView.topAnchor.constraint(equalTo: self.topAnchor).isActive = true
        scrollView.bottomAnchor.constraint(equalTo: self.bottomAnchor).isActive = true
        scrollView.leadingAnchor.constraint(equalTo: self.leadingAnchor).isActive = true
        scrollView.trailingAnchor.constraint(equalTo: self.trailingAnchor).isActive = true

        wrapperView.topAnchor.constraint(equalTo: scrollView.topAnchor).isActive = true
        wrapperView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor).isActive = true
        wrapperView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor).isActive = true
        wrapperView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor).isActive = true


        scrollView.borderType = .noBorder
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.scrollerKnobStyle = .light

        scrollView.documentView = textView

        scrollView.contentView.postsBoundsChangedNotifications = true

        NotificationCenter.default.addObserver(self, selector: #selector(didScroll(_:)), name: NSView.boundsDidChangeNotification, object: scrollView.contentView)

        textView.minSize = NSSize(width: 0.0, height: self.bounds.height)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width, .height]
        textView.isEditable = true
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.allowsUndo = true

        textView.textContainer?.containerSize = NSSize(width: self.bounds.width, height: .greatestFiniteMagnitude)
        textView.textContainer?.widthTracksTextView = true

        //			textView.layerContentsRedrawPolicy = .beforeViewResize

        wrapperView.textView = textView

        #else

        self.addSubview(textView)
        textView.topAnchor.constraint(equalTo: self.topAnchor).isActive = true
        textView.bottomAnchor.constraint(equalTo: self.bottomAnchor).isActive = true
        textView.leadingAnchor.constraint(equalTo: self.leadingAnchor).isActive = true
        textView.trailingAnchor.constraint(equalTo: self.trailingAnchor).isActive = true

        self.contentMode = .redraw
        textView.contentMode = .topLeft

        textViewSelectedRangeObserver = contentTextView.observe(\UITextView.selectedTextRange) { [weak self] (textView, value) in

            if let `self` = self {
                self.delegate?.didChangeSelectedRange(self, selectedRange: self.contentTextView.selectedRange, textPosition: self.getTextPostion(for: self.contentTextView.selectedRange))
            }

        }

        #endif

        textView.innerDelegate = self
        textView.delegate = self

        textView.text = ""

        #if os(iOS)

        textView.autocapitalizationType = .none
        textView.keyboardType = .default
        textView.autocorrectionType = .no
        textView.spellCheckingType = .no

        if #available(iOS 11.0, *) {
            textView.smartQuotesType = .no
            textView.smartInsertDeleteType = .no
        }

        self.clipsToBounds = true

        #endif

    }

    #if os(macOS)

    open override func viewDidMoveToSuperview() {
        super.viewDidMoveToSuperview()

    }

    @objc func didScroll(_ notification: Notification) {

        wrapperView.setNeedsDisplay(wrapperView.bounds)

    }

    #endif

    // MARK: -

    #if os(iOS)

    open override func becomeFirstResponder() -> Bool {
        return textView.becomeFirstResponder()
    }
    
    open override func resignFirstResponder() -> Bool {
        return textView.resignFirstResponder()
    }
    override open var isFirstResponder: Bool {
        return textView.isFirstResponder
    }

    #endif

    @IBInspectable
    public var text: String {
        get {
            #if os(macOS)
            return textView.string
            #else
            return textView.text ?? ""
            #endif
        }
        set {
            if newValue == self.textView.text{
                return
            }
            #if os(macOS)
            textView.layer?.isOpaque = true
            textView.string = newValue
            refreshColors()
            #else
            // If the user sets this property as soon as they create the view, we get a strange UIKit bug where the text often misses a final line in some Dynamic Type configurations. The text isn't actually missing: if you background the app then foreground it the text reappears just fine, so there's some sort of drawing sync problem. A simple fix for this is to give UIKit a tiny bit of time to create all its data before we trigger the update, so we push the updating work to the runloop.
            
            DispatchQueue.main.async {[weak self] in
                guard let self else{return}
                self.textView.text = newValue
                self.textView.setNeedsDisplay()
                self.refreshColors()
            }
//            asyncSetText(newValue)
//            DispatchQueue.global(qos: .background).async {
//                DispatchQueue.main.async {
//                    let bufferSize = 3096
//                    let start = newValue.startIndex
//                    var end = newValue.index(start, offsetBy: min(newValue.count,bufferSize))
////                    self.textView.isEditable
//                    self.textView.text = String(newValue[start..<end])
//                    while end < newValue.endIndex{
//                        end = newValue.index(end, offsetBy: min(newValue.count-,bufferSize))
//                    }
//    //                self.textView.selectedRange = self.selectedRange
//                    self.textView.setNeedsDisplay()
//                    self.refreshColors()
//                }
//            }
            #endif

        }
    }
    
    private func asyncSetText(_ text:String){
        DispatchQueue.main.async {
            self.textView.text=""
        }
        DispatchQueue.global(qos: .background).async {
            let bufferSize = 3096
            var start = 0
            var end = min(bufferSize,text.count)
            repeat{
                let startIndex=text.index(text.startIndex, offsetBy: start)
                let endIndex=text.index(startIndex, offsetBy: end - start)
                
                DispatchQueue.main.async {[weak self] in
                    guard let self else{return}
                    self.textView.text.append(String(text[startIndex..<endIndex]))
//                    self.textView.setNeedsDisplay()
//                    self.refreshColors()
                }
                start = end
                end = start + min(bufferSize,text.count - start)
                Thread.sleep(forTimeInterval: 0.1)
            } while end < text.count
            
        }
    }

    // MARK: -

    public func insertText(_ text: String) {
        if shouldChangeText(insertingText: text) {
            #if os(macOS)
            contentTextView.insertText(text, replacementRange: contentTextView.selectedRange())
            #else
            contentTextView.insertText(text)
            #endif
        }
    }

    #if os(iOS)

    public func scrollViewDidScroll(_ scrollView: UIScrollView) {
        self.textView.setNeedsDisplay()
    }

    override open func layoutSubviews() {
        super.layoutSubviews()

        self.textView.invalidateCachedParagraphs()
        self.textView.setNeedsDisplay()
    }

    #endif
    
    var oldTheme:CustomSourceCodeTheme?

    public var theme: CustomSourceCodeTheme? {
        didSet {
            guard let theme = theme else {
                return
            }
            if let oldTheme,oldTheme == theme{
                return
            }
            oldTheme = theme
            cachedThemeInfo = nil
            #if os(iOS)
            backgroundColor = theme.backgroundColor
            #endif
            textView.backgroundColor = theme.backgroundColor
            
            // 设置默认样式
            let textStorage: NSTextStorage
            
            #if os(macOS)
            textStorage = textView.textStorage!
            #else
            textStorage = textView.textStorage
            #endif
            var attributes = [NSAttributedString.Key: Any]()

            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.paragraphSpacing = 2.0
            paragraphStyle.tabStops = []

            attributes[.paragraphStyle] = paragraphStyle
            let wholeRange = NSRange(location: 0, length: (textView.text as NSString).length)
            textStorage.setAttributes(attributes, range: wholeRange)
            textView.typingAttributes = attributes
            textView.theme = theme
            textView.font = theme.font
            textView.textColor = theme.foregroundColor
            refreshColors()
        }
    }

    var cachedThemeInfo: ThemeInfo?

    var themeInfo: ThemeInfo? {
        if let cached = cachedThemeInfo {
            return cached
        }

        guard let theme = theme else {
            return nil
        }

        let spaceAttrString = NSAttributedString(string: " ", attributes: [.font: theme.font])
        let spaceWidth = spaceAttrString.size().width

        let info = ThemeInfo(theme: theme, spaceWidth: spaceWidth)

        cachedThemeInfo = info

        return info
    }

    var cachedTokens: [CachedToken]?

    func invalidateCachedTokens() {
        cachedTokens = nil
    }
    
    func getLexer(_ source:String) -> Lexer{
        if let lexer{
            return lexer
        }
        if let delegate{
            return delegate.lexerForSource(source)
        }
        return EmptyLexer()
    }
    
    func cacheToken(callback:@escaping (String,[CachedToken])->Void){
        guard let source = textView.text else {
            return
        }
        if theme == nil{return}
        let lexer = getLexer(source)
        Task{
            DispatchQueue.global().async {[weak self] in
                var tokens = lexer.getSavannaTokens(input: source)
                let cachedTokens: [CachedToken] = tokens.map {
                    let nsRange = source.nsRange(fromRange: $0.range)
                    return CachedToken(token: $0, nsRange: nsRange)
                }
                self?.cachedTokens = cachedTokens
                callback(source,cachedTokens)
            }
        }
    }

    @MainActor
    func colorTextView(updateID:UUID) {
        guard let source = textView.text else {
            return
        }
        guard let theme = self.theme else {
            return
        }
        
        guard let themeInfo = self.themeInfo else {
            return
        }
        
        let textStorage: NSTextStorage
        
#if os(macOS)
        textStorage = textView.textStorage!
#else
        textStorage = textView.textStorage
#endif
        
        //		self.backgroundColor = theme.backgroundColor
        
        let tokens: [Token]
        
        if let cachedTokens = cachedTokens {
            updateAttributes(textStorage: textStorage, cachedTokens: cachedTokens, source: source)
        } else {
            cacheToken() {source,cachedTokens in
                DispatchQueue.main.async {[weak self] in
                    guard let self else{return}
                    guard updateID == self.updateID else{
                        print("已更改")
                        return
                    }
                    self.createAttributes(updateID: updateID, theme: theme, themeInfo: themeInfo, textStorage: textStorage, cachedTokens: cachedTokens, source: source)
                    if isSearching{
                        isSearching = false
                        onSearchResult(searchResult.count)
                    }
                }
            }
        }
    }

    func updateAttributes(textStorage: NSTextStorage, cachedTokens: [CachedToken], source: String) {

        let selectedRange = textView.selectedRange

        let fullRange = NSRange(location: 0, length: (source as NSString).length)

        var rangesToUpdate = [(NSRange, EditorPlaceholderState)]()

        textStorage.enumerateAttribute(.editorPlaceholder, in: fullRange, options: []) { (value, range, stop) in

            if let state = value as? EditorPlaceholderState {

                var newState: EditorPlaceholderState = .inactive

                if isEditorPlaceholderSelected(selectedRange: selectedRange, tokenRange: range) {
                    newState = .active
                }

                if newState != state {
                    rangesToUpdate.append((range, newState))
                }

            }

        }

        var didBeginEditing = false

        if !rangesToUpdate.isEmpty {
            textStorage.beginEditing()
            didBeginEditing = true
        }

        for (range, state) in rangesToUpdate {

            var attr = [NSAttributedString.Key: Any]()
            attr[.editorPlaceholder] = state

            textStorage.addAttributes(attr, range: range)

        }

        if didBeginEditing {
            textStorage.endEditing()
        }
    }
    
    func createAttributes(updateID:UUID, theme: any SyntaxColorTheme, themeInfo: ThemeInfo, textStorage: NSTextStorage, cachedTokens: [CachedToken], source: String) {
        let wholeRange = NSRange(location: 0, length: (source as NSString).length)
        let selectedRange = textView.selectedRange

        DispatchQueue.global(qos: .userInitiated).async {[weak self] in
            guard let self else{return}
            guard updateID == self.updateID else{
                print("已更改")
                return
            }
            var attributes = [NSAttributedString.Key: Any]()
            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.paragraphSpacing = 2.0
            paragraphStyle.defaultTabInterval = themeInfo.spaceWidth * 4
            paragraphStyle.tabStops = []

            attributes[.paragraphStyle] = paragraphStyle

            for (attr, value) in theme.globalAttributes() {
                attributes[attr] = value
            }
            var attributesToAdd = [(attributes: [NSAttributedString.Key: Any], range: NSRange)]()

            for cachedToken in cachedTokens {
                guard updateID == self.updateID else{
                    print("已更改")
                    return
                }
                let token = cachedToken.token

                if token.isPlain {
                    continue
                }

                let range = cachedToken.nsRange

                if token.isEditorPlaceholder {
                    let startRange = NSRange(location: range.lowerBound, length: 2)
                    let endRange = NSRange(location: range.upperBound - 2, length: 2)
                    let contentRange = NSRange(location: range.lowerBound + 2, length: range.length - 4)

                    var attr = [NSAttributedString.Key: Any]()
                    var state: EditorPlaceholderState = .inactive

                    if self.isEditorPlaceholderSelected(selectedRange: selectedRange, tokenRange: range) {
                        state = .active
                    }

                    attr[.editorPlaceholder] = state

                    attributesToAdd.append((theme.attributes(for: token), contentRange))
                    attributesToAdd.append(([.foregroundColor: Color.clear, .font: Font.systemFont(ofSize: 0.01)], startRange))
                    attributesToAdd.append(([.foregroundColor: Color.clear, .font: Font.systemFont(ofSize: 0.01)], endRange))
                    attributesToAdd.append((attr, range))
                } else {
                    attributesToAdd.append((theme.attributes(for: token), range))
                }
            }
            
            // 搜索结果
            if enableSearch{
                for range in self.searchResult{
                    guard updateID == self.updateID else{
                        print("已更改")
                        return
                    }
                    var attr = [NSAttributedString.Key: Any]()
                    attr[.backgroundColor] = range == selectedRange ? theme.activeMatchResultBgColor : theme.matchResultBgColor
                    attributesToAdd.append((attr,range))
                }
            }
            
//            if !self.isFirstResponder{
//                // 选中文本
//                var attr = [NSAttributedString.Key: Any]()
//                attr[.backgroundColor] = UIColor.red
//                attributesToAdd.append((attr,selectedRange))
//            }
            

            DispatchQueue.main.async {[weak self] in
                guard let self else{return}
                guard updateID == self.updateID else{
                    print("已更改")
                    return
                }
                textStorage.beginEditing()
                textStorage.setAttributes(attributes, range: wholeRange)
                for (attr, range) in attributesToAdd {
                    guard updateID == self.updateID else{
                        print("已更改")
                        return
                    }
                    textStorage.addAttributes(attr, range: range)
                }
                textStorage.endEditing()
            }
        }
    }
    
    // MARK: - 查找替换
    
    var ignoreTextChange:Bool = false
    
    var searchKey:String = ""
    private var searchOptions:ContentSearchOptions = .init(caseSensitive: false, matchMode: .contains)
    var enableSearch:Bool = false{
        didSet{
            if !enableSearch{
                DispatchQueue.main.async {[weak self] in
                    guard let self else{return}
                    searchKey = ""
                    searchResult = []
                    refreshColors()
                }
            }
        }
    }
    private var isSearching:Bool = false{
        didSet{
            if isSearching{
                onSearching()
            }
        }
    }
    var onSearching:()->Void = {}
    var onSearchResult:(Int)->Void = {_ in }
    var onSearchIndexChanged:(Int)->Void = {_ in }
    private(set) var searchResult:[NSRange]=[]{
        didSet{
            DispatchQueue.main.async {[weak self] in
                self?.refreshColors()
            }
        }
    }
    private(set) var selectedSearchResultIndex:Int = 0
    
    public func jumpToSearchResult(for index:Int,getFocus:Bool=false){
        let index = min(index,searchResult.count-1)
        if index >= 0{
            let range = searchResult[index]
            setSeletctTextRange(range, getFocus: getFocus)
            
            
            let textStorage: NSTextStorage
            
            #if os(macOS)
            textStorage = textView.textStorage!
            #else
            textStorage = textView.textStorage
            #endif
            textStorage.beginEditing()
            if selectedSearchResultIndex >= 0 && selectedSearchResultIndex < searchResult.count{
                let oldRange = searchResult[selectedSearchResultIndex]
                var attr = [NSAttributedString.Key: Any]()
                attr[.backgroundColor] = theme?.matchResultBgColor
                textStorage.addAttributes(attr, range: oldRange)
            }
            var attr = [NSAttributedString.Key: Any]()
            attr[.backgroundColor] = theme?.activeMatchResultBgColor
            textStorage.addAttributes(attr, range: range)
            textStorage.endEditing()
        }
        selectedSearchResultIndex = index
        onSearchIndexChanged(index)
    }
    
    private func restoreDefaultAttributes(){
        
        guard let theme = self.theme else {
            return
        }
        
        guard let themeInfo = self.themeInfo else {
            return
        }
        guard let source = textView.text else {
            return
        }
        let wholeRange = NSRange(location: 0, length: (source as NSString).length)
        let textStorage: NSTextStorage
#if os(macOS)
        textStorage = textView.textStorage!
#else
        textStorage = textView.textStorage
#endif
        textStorage.beginEditing()
        var attributes = [NSAttributedString.Key: Any]()
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.paragraphSpacing = 2.0
        paragraphStyle.defaultTabInterval = themeInfo.spaceWidth * 4
        paragraphStyle.tabStops = []
        
        attributes[.paragraphStyle] = paragraphStyle
        for (attr, value) in theme.globalAttributes() {
            attributes[attr] = value
        }
        attributes[.backgroundColor] = UIColor.clear
        textStorage.setAttributes(attributes, range: wholeRange)
        textStorage.endEditing()
    }
    
    private func searchText(key: String, options: ContentSearchOptions, source:String, callback: @escaping (String,[NSRange]) -> Void) {
        Task {
            DispatchQueue.global(qos: .userInitiated).async {[weak self] in
                guard let self else{return}
                if key != self.searchKey{
                    print("关键词已更改")
                    return
                }
                var result: [NSRange] = []
                var reOptions: NSRegularExpression.Options = []
                if !options.caseSensitive {
                    reOptions.formUnion(.caseInsensitive)
                }
                let pattern:String
                switch options.matchMode {
                case .contains:
                    pattern = "\(NSRegularExpression.escapedPattern(for: searchKey))"
                case .matchesWord:
                    pattern = "\\b\(NSRegularExpression.escapedPattern(for: searchKey))\\b"
                case .startsWith:
                    pattern = "\\b\(NSRegularExpression.escapedPattern(for: searchKey))"
                case .endsWith:
                    pattern = "\(NSRegularExpression.escapedPattern(for: searchKey))\\b"
                case .regex:
                    pattern = key
                }
                
                if let re = try? NSRegularExpression(pattern: pattern, options: reOptions) {
                    let matches = re.matches(in: source, range: NSRange(location: 0, length: source.utf16.count))
                    for match in matches {
                        if key != self.searchKey{
                            print("关键词已更改")
                            return
                        }
                        if let range = Range(match.range, in: source) {
                            result.append(source.nsRange(fromRange: range))
                        }
                    }
                }
                callback(key,result)
            }
        }
    }
        
    func search(key: String, options: ContentSearchOptions){
        searchKey = key
        searchOptions = options
        search()
    }
    
    private var searchTimer:Timer?
    
    func search(){
        searchTimer?.invalidate()
        if searchKey.isEmpty{
            isSearching = true
            searchResult = []
            return
        }
        searchTimer = .scheduledTimer(withTimeInterval: 0.5, repeats: false, block: { [weak self]_ in
            guard let self else{return}
            guard let source = textView.text else{return}
            isSearching = true
            searchText(key: searchKey, options: searchOptions, source: source) { key,result in
                DispatchQueue.main.async {[weak self] in
                    guard let self else{return}
                    if key != self.searchKey{
                        print("关键词已更改")
                        return
                    }
//                    self.isSearching = false
                    self.searchResult = result
//                    self.onSearchResult(result.count)
                    if result.count > 0 && !isFirstResponder{
                        self.jumpToSearchResult(for: 0, getFocus: false)
                    }
                }
            }
        })
    }
    
    private func range(from nsRange: NSRange, in string: String) -> Range<String.Index>? {
        guard
            let from17 = string.index(string.startIndex, offsetBy: nsRange.location, limitedBy: string.endIndex),
            let to17 = string.index(from17, offsetBy: nsRange.length, limitedBy: string.endIndex)
        else { return nil }
        
        return from17..<to17
    }
    
    func replace(index:Int,replaceTo:String,callback:@escaping () -> Void){
        if var source = textView.text{
            if index>=0 && index<searchResult.count{
                DispatchQueue.global(qos:.userInitiated).async{[weak self] in
                    guard let self else{return}
                    let range = searchResult[index]
                    let offset = replaceTo.count - searchResult[index].length
                    for i in searchResult[index...].indices{
                        searchResult[i].location += offset
                    }
                    searchResult.remove(at: index)
                    DispatchQueue.main.async {[weak self] in
                        guard let self else{return}
                        ignoreTextChange = true
                        textView.replace(to: replaceTo, in: range)
                        onSearchResult(searchResult.count)
//                        restoreDefaultAttributes()
                        delegate?.didChangeText(self)
                        jumpToSearchResult(for: index)
                        refreshColors(allowDelay: false)
                        ignoreTextChange = false
                    }
                    callback()
                    return
                }
            }
        }
        callback()
    }
    func replaceAll(key:String, to replaceText:String, options: ContentSearchOptions,callback:@escaping () -> Void){
        let taskID = UUID()
        if var source = textView.text{
            isSearching = true
            let searchResult = self.searchResult
            DispatchQueue.global(qos: .userInitiated).async{[weak self] in
                guard let self else{return} 
                print("Step1.\(Date().timeIntervalSince1970)")
                let pattern:String
                switch options.matchMode {
                case .contains:
                    pattern = "\(NSRegularExpression.escapedPattern(for: key))"
                case .matchesWord:
                    pattern = "\\b\(NSRegularExpression.escapedPattern(for: key))\\b"
                case .startsWith:
                    pattern = "\\b\(NSRegularExpression.escapedPattern(for: key))"
                case .endsWith:
                    pattern = "\(NSRegularExpression.escapedPattern(for: key))\\b"
                case .regex:
                    pattern = key
                }
                
                var reOptions: NSRegularExpression.Options = []
                if !options.caseSensitive {
                    reOptions.formUnion(.caseInsensitive)
                }
                if let re = try? NSRegularExpression(pattern: pattern, options: reOptions) {
                    source = re.stringByReplacingMatches(in: source, range: NSRange(location: 0, length: source.count), withTemplate: replaceText)
                }
                print("Step2.\(Date().timeIntervalSince1970)")
                self.searchResult = []
                DispatchQueue.main.async {[weak self] in
                    guard let self else{return}
                    isSearching = false
                    onSearchResult(self.searchResult.count)
                    ignoreTextChange = true
                    print("Step4.\(Date().timeIntervalSince1970)")
                    if let undoManager = textView.myUndoManager,undoManager.isUndoRegistrationEnabled{
                        let oldText = self.textView.text
                        undoManager.registerUndo(withTarget: undoManager, handler: {this in
                            guard let target = this.target else { return }
                            
                            // 执行撤销操作，同时将替换操作保存为 redo 操作
                            this.registerUndo(withTarget: this, handler: { this in
                                guard let target = this.target else { return }
                                target.replaceAll(key: key, to: replaceText, options: options, callback: {})
                            })
                            this.disableUndoRegistration()
                            // 替换为旧文本
                            target.textStorage.replaceCharacters(in: .init(location: 0, length: target.text.count), with: oldText ?? "")
                            this.enableUndoRegistration()
                        })
                    }
                    textView.textStorage.replaceCharacters(in: .init(location: 0, length: textView.text.count), with: source)
                    print("Step5.\(Date().timeIntervalSince1970)")
                    delegate?.didChangeText(self)
                    jumpToSearchResult(for: -1)
                    refreshColors(allowDelay: false)
                    ignoreTextChange = false
                    print("Step6.\(Date().timeIntervalSince1970)")
                }
                print("Step3.\(Date().timeIntervalSince1970)")
                callback()
            }
        }
        else{
            callback()
        }
    }

    
    // MARK: - 撤销/重做

    var canUndo:Bool{
        textView.canUndo
    }
    
    var canRedo:Bool{
        textView.canRedo
    }
    
    func undo(){
        if textView.canUndo{
            textView.undo()
            restoreDefaultAttributes()
            delegate?.didChangeText(self)
            refreshColors(allowDelay: false)
        }
    }
    
    func redo(){
        if textView.canRedo{
            textView.redo()
            restoreDefaultAttributes()
            delegate?.didChangeText(self)
            refreshColors(allowDelay: false)
        }
    }
}
//extension String {
//    func replaceOccurrencesWithNSRange(_ ranges: [NSRange], replaceTo: String) -> String {
//        var buffer = [Character]()
//        buffer.reserveCapacity(self.count + (replaceTo.count - ranges.reduce(0) { $0 + $1.length }) * ranges.count)
//        
//        var lastIndex = 0  // 记录字符的索引位置
//        
//        for nsRange in ranges {
//            let lowerBound = self.utf16.index(self.utf16.startIndex, offsetBy: nsRange.location)
//            let upperBound = self.utf16.index(lowerBound, offsetBy: nsRange.length)
//            
//            // 将范围内的内容拼接
//            buffer.append(contentsOf: self.utf16.prefix(upTo: lowerBound).map { Character(UnicodeScalar($0)!) })
//            // 拼接替换内容
//            buffer.append(contentsOf: replaceTo)
//            
//            lastIndex = nsRange.location + nsRange.length
//        }
//        
//        // 拼接剩余未替换的内容
//        buffer.append(contentsOf: self.utf16.suffix(from: self.utf16.index(self.utf16.startIndex, offsetBy: lastIndex)).map { Character(UnicodeScalar($0)!) })
//        
//        return String(buffer)
//    }
//}
