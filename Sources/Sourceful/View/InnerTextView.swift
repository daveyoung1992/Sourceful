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

class InnerTextView: TextView {
	
	weak var innerDelegate: InnerTextViewDelegate?
    
    var lineRanges:[LineRange] = []
	
    var theme: (any SyntaxColorTheme)?
	
	var cachedParagraphs: [Paragraph]?
	
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
	
	override func beginFloatingCursor(at point: CGPoint) {
		super.beginFloatingCursor(at: point)
		
		isCursorFloating = true
		innerDelegate?.didUpdateCursorFloatingState()

	}
	
	override func endFloatingCursor() {
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
	
	override func caretRect(for position: UITextPosition) -> CGRect {
		
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
        return undoManager?.canUndo ?? false
    }
    
    var canRedo:Bool{
        return undoManager?.canRedo ?? false
    }
    
    func undo(){
        undoManager?.undo()
    }
    
    func redo(){
        undoManager?.redo()
    }
    
//    override func becomeFirstResponder() -> Bool {
//        let become = super.becomeFirstResponder()
//        if become{
//            // 确保启用了撤销和重做功能
//            self.undoManager?.levelsOfUndo = 10 // 可设置撤销的层级数
//        }
//    }
    
//    override func insertText(_ text: String) {
//        let oldText = self.text(in: selectedTextRange!) ?? ""
//        print("insert",selectedTextRange,text,oldText)
//        super.insertText(text)
//    }
//    
//    override func deleteBackward() {
//        var deletedTextRange = self.selectedTextRange
//        if deletedTextRange == nil {return}
//        if deletedTextRange!.start == self.beginningOfDocument{return}
//        if deletedTextRange!.isEmpty{
//            deletedTextRange = self.textRange(from: self.position(from: deletedTextRange!.start, offset: -1)!, to: self.position(from: deletedTextRange!.start, offset: 0)!)
//        }
//        let deletedText = self.text(in: deletedTextRange!)
//        print("delete",deletedTextRange,deletedText)
//        super.deleteBackward()
//    }
//    
//    override func replace(_ range: UITextRange, withText text: String) {
//        let oldText = self.text(in: range) ?? ""
//        print("replace",range,text,oldText)
//        super.replace(range, withText: text)
//    }
//    
//    override func paste(_ sender: Any?) {
//        print("paste",sender)
//        super.paste(sender)
//    }
//    
//    override func cut(_ sender: Any?) {
//        print("cut",sender)
//        super.cut(sender)
//    }
    
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
