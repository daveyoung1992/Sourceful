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
        if let textRange = selectedTextRange{
            if myUndoManager?.isUndoRegistrationEnabled ?? false{
                myUndoManager?.addInsertUndo(textRange: textRange, text: text, textView: self)
            }
            super.insertText(text)
        }
    }
    
    public override func deleteBackward() {
        if let textRange = self.selectedTextRange{
            if myUndoManager?.isUndoRegistrationEnabled ?? false{
                myUndoManager?.addDeleteUndo(textRange: textRange, textView: self)
            }
        }
        super.deleteBackward()
    }
    func nsRange(from textRange: UITextRange) -> NSRange {
        let location = offset(from: beginningOfDocument, to: textRange.start)
        let length = offset(from: textRange.start, to: textRange.end)
        return NSRange(location: location, length: length)
    }
    
    public override func replace(_ range: UITextRange, withText text: String) {
        if myUndoManager?.isUndoRegistrationEnabled ?? false{
            myUndoManager?.addInsertUndo(textRange: range, text: text, textView: self)
        }
        super.smartQuotesType = .no
        super.replace(range, withText: text)
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
    
    func replaceAll(newText:String){
        let oldRange = selectedTextRange
        if let undoManager = myUndoManager,undoManager.isUndoRegistrationEnabled{
            let oldText = self.text
            undoManager.registerUndo(withTarget: undoManager, handler: {this in
                guard let target = this.target else { return }
                this.isBusy = true
                // 执行撤销操作，同时将替换操作保存为 redo 操作
                this.registerUndo(withTarget: this, handler: { this in
                    guard let target = this.target else { return }
                    target.replaceAll(newText: newText)
                })
                this.disableUndoRegistration()
                // 替换为旧文本
                target.textStorage.replaceCharacters(in: .init(location: 0, length: target.text.count), with: oldText ?? "")
                this.enableUndoRegistration()
                target.selectedTextRange = oldRange
                DispatchQueue.main.async{
                    if !(target.parent?.ignoreTextChange ?? true){
                        target.parent?.didUpdateText(allowDelay: false)
                    }
                    this.isBusy = false
                }
            })
        }
        parent?.clearSearchResult()
        parent?.ignoreTextChange = true
        textStorage.replaceCharacters(in: .init(location: 0, length: text.count), with: newText)
        parent?.delegate?.didChangeText(parent!)
        parent?.jumpToSearchResult(for: -1)
        parent?.refreshColors(allowDelay: false)
        parent?.ignoreTextChange = false
    }
	
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
    
    public init(target: InnerTextView? = nil) {
        self.target = target
        super.init()
    }
    
    fileprivate var isBusy:Bool = false
    
    private func regUndo(history:UndoHistory){
        if let target{
            switch history.action {
            case .insert,.replace,.paste:
                self.registerUndo(withTarget: self) { this in
                    if let target = this.target{
                        this.isBusy = true
                        self.registerUndo(withTarget: this) { this in
                            if let target = this.target{
                                this.isBusy = true
                                target.selectedTextRange = history.oldRange
                                target.insertText(history.newText)
                                target.parent?.didUpdateText(allowDelay: false)
                                this.isBusy = false
                            }
                        }
                        self.disableUndoRegistration()
                        let attributedText = NSMutableAttributedString(attributedString: target.attributedText)
                        attributedText.replaceCharacters(in: target.nsRange(from: history.newRange), with: history.oldText)
                        target.attributedText = attributedText
                        // 使用replace方法会出现诡异的问题：自动将部分半角单引号换成全角的了。
//                        target.replace(history.newRange, withText: history.oldText)
                        self.enableUndoRegistration()
                        target.selectedTextRange = history.oldRange
                        DispatchQueue.main.async{
                            if !(target.parent?.ignoreTextChange ?? true){
                                target.parent?.didUpdateText(allowDelay: false)
                            }
                            this.isBusy = false
                        }
                    }
                }
            case .delete,.cut:
                self.registerUndo(withTarget: self) { this in
                    if let target = this.target{
                        this.isBusy = true
                        self.registerUndo(withTarget: this) { this in
                            if let target = this.target{
                                this.isBusy = true
                                target.selectedTextRange = history.oldRange
                                target.deleteBackward()
                                target.parent?.didUpdateText(allowDelay: false)
                                this.isBusy = false
                            }
                        }
                        self.disableUndoRegistration()
                        target.selectedTextRange = history.newRange
                        target.insertText(history.oldText)
                        self.enableUndoRegistration()
                        DispatchQueue.main.async{
                            if !(target.parent?.ignoreTextChange ?? true){
                                target.parent?.didUpdateText(allowDelay: false)
                            }
                            this.isBusy = false
                        }
                    }
                }
            }
        }
    }
    
    override public var canRedo: Bool{
        if isBusy || isRedoing || isUndoing {return false}
        return super.canRedo
    }
    
    override public var canUndo: Bool{
        if isBusy || isRedoing || isUndoing {return false}
        return super.canUndo
    }
    
    override public func undo() {
        if isBusy || isRedoing || isUndoing {return}
        super.undo()
    }
    
    override public func redo() {
        if isBusy || isRedoing || isUndoing {return}
        super.redo()
    }
    
    public func addPasteUndo(oldRange:UITextRange,oldText:String, newRange:UITextRange, newText:String){
        let history = UndoHistory(action: .insert, oldRange: oldRange, newRange: newRange, oldText: oldText, newText: newText)
        regUndo(history: history)
    }
    
    public func addInsertUndo(textRange:UITextRange,text:String,textView:InnerTextView){
        if let pos = textView.position(from: textRange.start, offset: text.count){
            if let newRange=textView.textRange(from: textRange.start, to: pos){
                if let oldText = textView.text(in: textRange){
                    let history = UndoHistory(action: .insert, oldRange: textRange, newRange: newRange, oldText: oldText, newText: text)
                    regUndo(history: history)
                }
            }
        }
    }
    
    public func addDeleteUndo(textRange:UITextRange,textView:InnerTextView){
        var newRange:UITextRange
        var oldRange = textRange
        if oldRange.isEmpty{
            if oldRange.start == textView.beginningOfDocument{return}
            oldRange = textView.textRange(from: textView.position(from: oldRange.start, offset: -1)!, to: oldRange.start)!
            newRange = textView.textRange(from: oldRange.start, to: oldRange.start)!
        }
        else{
            newRange = textView.textRange(from: oldRange.start, to: oldRange.start)!
        }
        if let oldText = textView.text(in: oldRange){
            let history = UndoHistory(action: .delete, oldRange: textRange, newRange: newRange, oldText: oldText, newText: "")
            regUndo(history: history)
        }
    }
    
    public func registerUndo(withTarget target: MyUndoManager, handler: @escaping (MyUndoManager) -> Void) {
        super.registerUndo(withTarget: target, handler: handler)
    }
}
