//
//  InnerTextView.swift
//  SavannaKit
//
//  Created by Louis D'hauwe on 09/07/2017.
//  Copyright © 2017 Silver Fox. All rights reserved.
//

import Foundation
import CoreGraphics

#if os(macOS)
	import AppKit
#else
	import UIKit
#endif

protocol InnerTextViewDelegate: AnyObject {
	func didUpdateCursorFloatingState()
}
struct LineRange{
    let lineNumber:Int
    let range:NSRange
}

public struct TextPosition:Hashable{
    public let rows:Int
    public let cols:Int
    public static let zero = TextPosition(rows: 0, cols: 0)
}

public class InnerTextView: TextView {
	
	weak var innerDelegate: InnerTextViewDelegate?
    
    unowned var parent:SyntaxTextView?
    
    var lineRanges:[LineRange] = []
	
    var theme: (any SyntaxColorTheme)?
	
	var cachedParagraphs: [Paragraph]?
    
    var myUndoManager:MyUndoManager?
	
	func invalidateCachedParagraphs() {
		cachedParagraphs = nil
	}
//    var langsWithInputMethod:[String] = ["zh","ja","ko","ar","he","ru","th"]
//    var langs:[String] = ["en-US","en"]
//    override var textInputMode: UITextInputMode?{
//        get{
//            let currentInputMode = super.textInputMode
//            if let currentLanguage = currentInputMode?.primaryLanguage,
//               langs.contains(where: {currentLanguage.hasPrefix($0)}){
//                if let inputMode = UITextInputMode.activeInputModes.first(where: { langsWithInputMethod.contains($0.primaryLanguage ?? "") }) {
//                    return inputMode
//                }
//            }
//            if let inputMode = UITextInputMode.activeInputModes.first(where: { langs.contains($0.primaryLanguage ?? "") }) {
//                return inputMode
//            }
//            return currentInputMode
//        }
//    }
	
	func hideGutter() {
		gutterWidth = theme?.gutterStyle.minimumWidth ?? 0.0
	}
	
	func updateGutterWidth(for numberOfCharacters: Int) {
		
		let leftInset: CGFloat = 4.0
		let rightInset: CGFloat = 4.0
		
		let charWidth: CGFloat = 10.0
		
		gutterWidth = max(theme?.gutterStyle.minimumWidth ?? 0.0, CGFloat(numberOfCharacters) * charWidth + leftInset + rightInset)
		
	}
	
	#if os(iOS)
	
	var isCursorFloating = false
	
    public override func beginFloatingCursor(at point: CGPoint) {
		super.beginFloatingCursor(at: point)
		
		isCursorFloating = true
		innerDelegate?.didUpdateCursorFloatingState()

	}
	
    public override func endFloatingCursor() {
		super.endFloatingCursor()
		
		isCursorFloating = false
		innerDelegate?.didUpdateCursorFloatingState()

	}
    
	
	override public func draw(_ rect: CGRect) {
		
		guard let theme = theme else {
			super.draw(rect)
			hideGutter()
			return
		}
		
		let textView = self

		if theme.lineNumbersStyle == nil  {

			hideGutter()

			let gutterRect = CGRect(x: 0, y: rect.minY, width: textView.gutterWidth, height: rect.height)
			let path = BezierPath(rect: gutterRect)
			path.fill()
			
		} else {
			
			let components = textView.text.components(separatedBy: .newlines)
			
			let count = components.count
			
			let maxNumberOfDigits = "\(count)".count
			
			textView.updateGutterWidth(for: maxNumberOfDigits)
            
            var paragraphs: [Paragraph]
            
            if let cached = textView.cachedParagraphs {
                
                paragraphs = cached
                
            } else {
                
                paragraphs = generateParagraphs(for: textView, flipRects: false)
                textView.cachedParagraphs = paragraphs
                
            }
			
			theme.gutterStyle.backgroundColor.setFill()
			
			let gutterRect = CGRect(x: 0, y: rect.minY, width: textView.gutterWidth, height: rect.height)
			let path = BezierPath(rect: gutterRect)
			path.fill()
			
			drawLineNumbers(paragraphs, in: rect, for: self)
			
		}
		

		super.draw(rect)

	}
	#endif
	
	var gutterWidth: CGFloat {
		set {
			
			#if os(macOS)
				textContainerInset = NSSize(width: newValue, height: 0)
			#else
				textContainerInset = UIEdgeInsets(top: 0, left: newValue, bottom: 0, right: 0)
			#endif
			
		}
		get {
			
			#if os(macOS)
				return textContainerInset.width
			#else
				return textContainerInset.left
			#endif
			
		}
	}
//	var gutterWidth: CGFloat = 0.0 {
//		didSet {
//
//			textContainer.exclusionPaths = [UIBezierPath(rect: CGRect(x: 0.0, y: 0.0, width: gutterWidth, height: .greatestFiniteMagnitude))]
//
//		}
//
//	}
	
	#if os(iOS)
	
    public override func caretRect(for position: UITextPosition) -> CGRect {
		
		var superRect = super.caretRect(for: position)
		
		guard let theme = theme else {
			return superRect
		}
		
		let font = theme.font
		
		// "descender" is expressed as a negative value,
		// so to add its height you must subtract its value
		superRect.size.height = font.pointSize - font.descender
		
		return superRect
	}
	
	#endif
    
    // MARK: - 查找替换
    func replace(to text:String,in range:NSRange){
        if let textRange = self.textRange(from: self.position(from: self.beginningOfDocument, offset: range.lowerBound)!, to: self.position(from: self.beginningOfDocument, offset: range.upperBound)!){
            self.replace(textRange, withText: text)
        }
    }
    
    // MARK: - 撤销/重做
    
    var canUndo:Bool{
        return myUndoManager?.canUndo ?? false
    }
    
    var canRedo:Bool{
        return myUndoManager?.canRedo ?? false
    }
    
    func undo(){
        myUndoManager?.undo()
    }
    
    func redo(){
        myUndoManager?.redo()
    }
    
//    override func becomeFirstResponder() -> Bool {
//        let become = super.becomeFirstResponder()
//        if become{
//            // 确保启用了撤销和重做功能
//            self.undoManager?.levelsOfUndo = 10 // 可设置撤销的层级数
//        }
//    }
    
    public override func insertText(_ text: String) {
        print("insertText")
        if let textRange = selectedTextRange{
            if myUndoManager?.isUndoRegistrationEnabled ?? false{
                myUndoManager?.addInsertUndo(textRange: textRange, text: text, textView: self)
            }
            super.insertText(text)
//            let oldText = self.text(in: textRange) ?? ""
//            print("insert",textRange,text,oldText)
//            if let newRange = self.textRange(from: textRange.start, to: self.position(from: textRange.start, offset: text.count)!){
//                if myUndoManager?.isUndoRegistrationEnabled ?? false{
//                    if let undoManager = myUndoManager{
//                        undoManager.registerUndo(withTarget: self, handler: { target in
//                            if let target = undoManager.target{
//                                undoManager.registerUndo(withTarget: target, handler: { _ in
//                                    target.selectedTextRange = textRange
//                                    target.insertText(text)
//                                })
//                                undoManager.disableUndoRegistration()
//                                target.replace(newRange, withText: oldText)
//                                undoManager.enableUndoRegistration()
//                            }
//                        })
//                    }
//                }
//                super.insertText(text)
//            }
        }
    }
    
    public override func deleteBackward() {
        if let textRange = self.selectedTextRange{
            if myUndoManager?.isUndoRegistrationEnabled ?? false{
                myUndoManager?.addDeleteUndo(textRange: textRange, textView: self)
            }
        }
//        var deletedTextRange = self.selectedTextRange
//        if deletedTextRange == nil {return}
//        if deletedTextRange!.start == self.beginningOfDocument{return}
//        if deletedTextRange!.isEmpty{
//            deletedTextRange = self.textRange(from: self.position(from: deletedTextRange!.start, offset: -1)!, to: deletedTextRange!.start)
//        }
//        let deletedText = self.text(in: deletedTextRange!)
//        print("delete",deletedTextRange,deletedText)
//        if myUndoManager?.isUndoRegistrationEnabled ?? false{
//            if let undoManager = myUndoManager{
//                undoManager.registerUndo(withTarget: self, handler: { _ in
//                    if let target = undoManager.target{
//                        undoManager.registerUndo(withTarget: self, handler: { _ in
//                            target.selectedTextRange = textRange
//                            target.deleteBackward()
//                        })
//                        undoManager.disableUndoRegistration()
//                        target.selectedTextRange = target.textRange(from: deletedTextRange!.start, to: deletedTextRange!.start)
//                        target.insertText(deletedText!)
//                        undoManager.enableUndoRegistration()
//                    }
//                })
//                
//            }
//        }
        super.deleteBackward()
    }
    
    public override func replace(_ range: UITextRange, withText text: String) {
        print("replace")
        if myUndoManager?.isUndoRegistrationEnabled ?? false{
            myUndoManager?.addInsertUndo(textRange: range, text: text, textView: self)
        }
        super.replace(range, withText: text)
//        let oldText = self.text(in: range) ?? "\"\""
//        print("replace",range,text,oldText)
//        super.replace(range, withText: text)
//        print(self.text)
//        invalidateCachedParagraphs()
//        setNeedsDisplay()
    }
    
    var onPasteCompletion:(()->Void)?
    
    public override func paste(_ sender: Any?) {
        if myUndoManager?.isUndoRegistrationEnabled ?? false{
            if let textRange = self.selectedTextRange{
                let oldText = self.text(in: textRange) ?? ""
                let oldLength = self.text.count
                onPasteCompletion = {
                    let newLength = self.text.count
                    if let newRange = self.textRange(from: textRange.start, to: self.position(from: textRange.start, offset: oldText.count+(newLength-oldLength))!){
                        let newText = self.text(in: newRange) ?? ""
                        if let newRange = self.textRange(from: textRange.start, to: self.position(from: textRange.start, offset: newText.count)!){
                            self.myUndoManager?.addPasteUndo(oldRange: textRange, oldText: oldText, newRange: newRange, newText: newText)
                        }
                        print("parse",newText)
                    }
                    
                    self.onPasteCompletion = nil
                }
                super.paste(sender)
                // 注册监听粘贴后文本变化的通知
                NotificationCenter.default.addObserver(
                    self,
                    selector: #selector(handleTextChangeAfterPaste),
                    name: UITextView.textDidChangeNotification,
                    object: self
                )
            }
        }
        else{
            super.paste(sender)
        }
    }
    
    @objc private func handleTextChangeAfterPaste() {
        // 移除监听器，防止重复调用
        NotificationCenter.default.removeObserver(
            self,
            name: UITextView.textDidChangeNotification,
            object: self
        )
        onPasteCompletion?()
    }
    
    public override func cut(_ sender: Any?) {
        if let textRange = self.selectedTextRange{
            if myUndoManager?.isUndoRegistrationEnabled ?? false{
                myUndoManager?.addDeleteUndo(textRange: textRange, textView: self)
            }
            super.cut(sender)
        }
    }
    
    func replaceAll(key:String, to replaceText:String, options: ContentSearchOptions,callback:@escaping () -> Void){
        parent?.replaceAll(key: key, to: replaceText, options: options, callback: callback)
    }
    
//    override func replaceAllOccurrences(ofQueryString queryString: String, using options: UITextSearchOptions, withText replacementText: String) {
//        print("replaceAll",queryString,options,replacementText)
//        if #available(iOS 16.0, *) {
//            super.replaceAllOccurrences(ofQueryString: queryString, using: options, withText: replacementText)
//        } else {
//            // Fallback on earlier versions
//        }
//    }
    
//    override func insertText(_ text: String) {
//        // 保存当前的状态以便撤销
//        let text = text
//        if text.isEmpty{return}
//        let insertTextRange = self.selectedTextRange
//        if insertTextRange == nil {return}
//        let oldText = self.text(in: insertTextRange!) ?? ""
//        let newTextRange = self.textRange(from: self.position(from: insertTextRange!.start, offset: 0)!, to: self.position(from: insertTextRange!.start, offset: text.count-1)!)
//        if let newTextRange{
//            self.undoManager?.registerUndo(withTarget: self) { target in
//                // 执行撤销操作
//                self.undoManager?.disableUndoRegistration()
//                target.replace(newTextRange, withText: oldText)
//                self.undoManager?.enableUndoRegistration()
//            }
//        }
//        super.insertText(text)
//    }
//    
//    
//    override func deleteBackward() {
//        var deletedTextRange = self.selectedTextRange
//        if deletedTextRange == nil {return}
//        if deletedTextRange!.start == self.beginningOfDocument{return}
//        if deletedTextRange!.isEmpty{
//            deletedTextRange = self.textRange(from: self.position(from: deletedTextRange!.start, offset: -1)!, to: self.position(from: deletedTextRange!.start, offset: 0)!)
//        }
//        let deletedText = self.text(in: deletedTextRange!)
//        
//        if let deletedText = deletedText {
//            self.undoManager?.registerUndo(withTarget: self) { target in
//                self.undoManager?.disableUndoRegistration()
//                target.insertText(deletedText)
//                self.undoManager?.enableUndoRegistration()
//            }
//        }
//        
//        super.deleteBackward()
//    }
    
//    override func paste(_ sender: Any?) {
//        let previousText = self.text
//        let selectedRange = self.selectedRange
//        
//        self.undoManager?.registerUndo(withTarget: self) { target in
//            target.text = previousText
//            target.selectedRange = selectedRange
//        }
//        
//        super.paste(sender)
//    }
//    
//    override func cut(_ sender: Any?) {
//        let cutText = self.text(in: self.selectedTextRange!)
//        
//        if let cutText = cutText {
//            self.undoManager?.registerUndo(withTarget: self) { target in
//                target.insertText(cutText)
//            }
//        }
//        
//        super.cut(sender)
//    }
    
//    override func replace(_ range: UITextRange, withText text: String) {
//        let previousText = self.text(in: range)
//        
//        if let previousText = previousText {
//            self.undoManager?.registerUndo(withTarget: self) { target in
//                target.replace(range, withText: previousText)
//            }
//        }
//        
//        super.replace(range, withText: text)
//    }
	
}
enum ActionType{
    case insert
    case delete
    case replace
    case cut
    case paste
}
struct UndoHistory{
    let action:ActionType
    let oldRange:UITextRange
    let newRange:UITextRange
    let oldText:String
    let newText:String
    let opTime:Date = Date()
}
public class MyUndoManager:UndoManager{
    public unowned var target:InnerTextView?
//    private var lastAction:UndoHistory?
//    private var taskQueue = DispatchQueue (label: "undoHistoryOps", qos: .userInitiated)
//    private var timer:Timer
//    private var isGrouping:Bool = false
//    private var disabled:Bool = false
    
    public init(target: InnerTextView? = nil) {
        self.target = target
//        timer = .scheduledTimer(withTimeInterval: 0.1, repeats: false, block: {_ in})
        super.init()
    }
    
    private func regUndo(history:UndoHistory){
        if let target{
            switch history.action {
            case .insert,.replace,.paste:
                self.registerUndo(withTarget: self) { this in
                    if let target = this.target{
                        self.registerUndo(withTarget: this) { this in
                            if let target = this.target{
                                target.selectedTextRange = history.oldRange
                                target.insertText(history.newText)
                            }
                        }
                        self.disableUndoRegistration()
                        //                    self.disabled = true
                        target.replace(history.newRange, withText: history.oldText)
                        //                    self.disabled = false
                        self.enableUndoRegistration()
                    }
                }
            case .delete,.cut:
                self.registerUndo(withTarget: self) { this in
                    if let target = this.target{
                        self.registerUndo(withTarget: this) { this in
                            if let target = this.target{
                                target.selectedTextRange = history.oldRange
                                target.deleteBackward()
                            }
                        }
                        self.disableUndoRegistration()
                        //                    self.disabled = true
                        target.selectedTextRange = history.newRange
                        target.insertText(history.oldText)
                        //                    self.disabled = false
                        self.enableUndoRegistration()
                    }
                }
//            case .replace,.paste:
//                self.registerUndo(withTarget: target) { _ in
//                    self.registerUndo(withTarget: target) { _ in
//                        target.replace(history.oldRange, withText: history.newText)
//                    }
//                    self.disableUndoRegistration()
//                    target.replace(history.newRange, withText: history.oldText)
//                    self.enableUndoRegistration()
//                }
            }
        }
    }
    
//    private func delayEndGroup(){
//        timer.invalidate()
//        timer = .scheduledTimer(withTimeInterval: 0.5, repeats: false, block: {[weak self] _ in
//            guard let self else{return}
//            lastAction = nil
//            self.endUndoGrouping()
//        })
//    }
    
//    override public func beginUndoGrouping() {
//        guard !isGrouping else{return}
//        isGrouping = true
//        super.beginUndoGrouping()
//    }
//    
//    override public func endUndoGrouping() {
//        guard isGrouping else{return}
//        isGrouping = false
//        super.endUndoGrouping()
//    }
//    
    override public func undo() {
        if #available(iOS 17.4, *){
            print(self.undoCount)
            if self.undoCount == 0{
                self.removeAllActions()
            }
        }
        
        super.undo()
        if #available(iOS 17.4, *){
            print(self.undoCount)
        }
    }
//    
    override public func redo() {
        if #available(iOS 17.4, *){
            print(self.undoCount)
        }
        super.redo()
        if #available(iOS 17.4, *){
            print(self.undoCount)
        }
    }
    
    public func addPasteUndo(oldRange:UITextRange,oldText:String, newRange:UITextRange, newText:String){
        let history = UndoHistory(action: .insert, oldRange: oldRange, newRange: newRange, oldText: oldText, newText: newText)
        regUndo(history: history)
    }
    
    public func addInsertUndo(textRange:UITextRange,text:String,textView:InnerTextView){
//        guard !disabled else{return}
        if let pos = textView.position(from: textRange.start, offset: text.count){
            if let newRange=textView.textRange(from: textRange.start, to: pos){
                if let oldText = textView.text(in: textRange){
                    let history = UndoHistory(action: .insert, oldRange: textRange, newRange: newRange, oldText: oldText, newText: text)
                    regUndo(history: history)
//                    if lastAction == nil{
//                        self.beginUndoGrouping()
//                        regUndo(history: history)
//                    }
//                    else if lastAction!.action == .insert && history.oldText.isEmpty && lastAction!.newRange.end == textRange.start{
//                        regUndo(history: history)
//                    }
//                    else{
//                        self.endUndoGrouping()
//                        regUndo(history: history)
//                        self.beginUndoGrouping()
//                    }
//                    lastAction = history
//                    delayEndGroup()
                }
            }
        }
    }
    
    public func addDeleteUndo(textRange:UITextRange,textView:InnerTextView){
        var newRange:UITextRange
        if textRange.isEmpty{
            if textRange.start == textView.beginningOfDocument{return}
            newRange = textView.textRange(from: textView.position(from: textRange.start, offset: -1)!, to: textRange.start)!
        }
        else{
            newRange = textView.textRange(from: textRange.start, to: textRange.start)!
        }
        if let oldText = textView.text(in: textRange){
            let history = UndoHistory(action: .delete, oldRange: textRange, newRange: newRange, oldText: oldText, newText: "")
            regUndo(history: history)
//            if lastAction == nil{
//                self.beginUndoGrouping()
//                regUndo(history: history)
//            }
//            else if lastAction!.action == .delete && lastAction!.newRange == textRange{
//                regUndo(history: history)
//            }
//            else{
//                self.endUndoGrouping()
//                regUndo(history: history)
//                self.beginUndoGrouping()
//            }
//            lastAction = history
//            delayEndGroup()
        }
    }
    
    public func registerUndo(withTarget target: MyUndoManager, handler: @escaping (MyUndoManager) -> Void) {
        print("ttt")
        super.registerUndo(withTarget: target, handler: handler)
    }
}
