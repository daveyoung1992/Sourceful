//
//  SyntaxTextView+TextViewDelegate.swift
//  SavannaKit
//
//  Created by Louis D'hauwe on 17/02/2018.
//  Copyright © 2018 Silver Fox. All rights reserved.
//

import Foundation

#if os(macOS)
	import AppKit
#else
	import UIKit
#endif

extension SyntaxTextView: InnerTextViewDelegate {
	
	func didUpdateCursorFloatingState() {
		
		selectionDidChange()
		
	}
	
}

extension SyntaxTextView {

	func isEditorPlaceholderSelected(selectedRange: NSRange, tokenRange: NSRange) -> Bool {
		
		var intersectionRange = tokenRange
		intersectionRange.location += 1
		intersectionRange.length -= 1
		
		return selectedRange.intersection(intersectionRange) != nil
	}
	
	func updateSelectedRange(_ range: NSRange) {
		textView.selectedRange = range
		
		#if os(macOS)		
		self.textView.scrollRangeToVisible(range)
		#endif
        Task{
            self.delegate?.didChangeSelectedRange(self, selectedRange: range, textPosition: self.getTextPostion(for: range))
        }
	}
	
	func selectionDidChange() {
		
		guard let delegate = delegate else {
			return
		}
		
		if let cachedTokens = cachedTokens {
			
			#if os(iOS)
				if !textView.isCursorFloating {
					updateEditorPlaceholders(cachedTokens: cachedTokens)
				}
			#else
				updateEditorPlaceholders(cachedTokens: cachedTokens)
			#endif
			
		}
        updateColor(allowDelay: false)
		
		previousSelectedRange = textView.selectedRange
		
	}
    
    func updateColor(allowDelay:Bool = true){
        updateColorTimer?.invalidate()
        updateID = UUID()
        let updateID = updateID
        if allowDelay{
            updateColorTimer = .scheduledTimer(withTimeInterval: 0.5, repeats: false, block: {[weak self] _ in
                guard let self else{return}
                guard updateID == self.updateID else{
                    print("已更改")
                    return
                }
                self.colorTextView(updateID: updateID)
            })
        }
        else{
            self.colorTextView(updateID: updateID)
        }
    }
	
	func updateEditorPlaceholders(cachedTokens: [CachedToken]) {
		
		for cachedToken in cachedTokens {
			
			let range = cachedToken.nsRange
			
			if cachedToken.token.isEditorPlaceholder {
				
				var forceInsideEditorPlaceholder = true
				
				let currentSelectedRange = textView.selectedRange
				
				if let previousSelectedRange = previousSelectedRange {
					
					if isEditorPlaceholderSelected(selectedRange: currentSelectedRange, tokenRange: range) {
						
						// Going right.
						if previousSelectedRange.location + 1 == currentSelectedRange.location {
							
							if isEditorPlaceholderSelected(selectedRange: previousSelectedRange, tokenRange: range) {
								updateSelectedRange(NSRange(location: range.location+range.length, length: 0))
							} else {
								updateSelectedRange(NSRange(location: range.location + 1, length: 0))
							}
							
							forceInsideEditorPlaceholder = false
							break
						}
						
						// Going left.
						if previousSelectedRange.location - 1 == currentSelectedRange.location {
							
							if isEditorPlaceholderSelected(selectedRange: previousSelectedRange, tokenRange: range) {
								updateSelectedRange(NSRange(location: range.location, length: 0))
							} else {
								updateSelectedRange(NSRange(location: range.location + 1, length: 0))
							}
							
							forceInsideEditorPlaceholder = false
							break
						}
						
					}
					
				}
				
				if forceInsideEditorPlaceholder {
					if isEditorPlaceholderSelected(selectedRange: currentSelectedRange, tokenRange: range) {
						
						if currentSelectedRange.location <= range.location || currentSelectedRange.upperBound >= range.upperBound {
							// Editor placeholder is part of larger selected text,
							// so don't change selection.
							break
						}
						
						updateSelectedRange(NSRange(location: range.location+1, length: 0))
						break
					}
				}
				
			}
			
		}
		
	}
    
    func didUpdateText() {
        if !ignoreTextChange{
            if self.enableSearch && !self.searchKey.isEmpty{
                self.search()
            }
            else{
                refreshColors()
            }
        }
        delegate?.didChangeText(self)
        
    }
}

#if os(macOS)
	
	extension SyntaxTextView: NSTextViewDelegate {
		
		open func textView(_ textView: NSTextView, shouldChangeTextIn affectedCharRange: NSRange, replacementString: String?) -> Bool {
			
			let text = replacementString ?? ""
			
			return self.shouldChangeText(insertingText: text)
		}
		
		open func textDidChange(_ notification: Notification) {
			guard let textView = notification.object as? NSTextView, textView == self.textView else {
				return
			}
			
			didUpdateText()
		}
        
        func refreshColors() {
            if let delegate{
                refreshTimer?.invalidate()
                refreshTimer = .scheduledTimer(withTimeInterval: 0.5, repeats: false, block: { _ in
                    self.invalidateCachedTokens()
                    DispatchQueue.main.async {
                        self.textView.invalidateCachedParagraphs()
                        self.updateColor(allowDelay: false)
                        wrapperView.setNeedsDisplay(wrapperView.bounds)
                    }
                })
            }
        }
		
		open func textViewDidChangeSelection(_ notification: Notification) {
			
			contentDidChangeSelection()

		}
		
	}
	
#endif

#if os(iOS)
	
	extension SyntaxTextView: UITextViewDelegate {
		
		open func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
			
			return self.shouldChangeText(insertingText: text)
		}
		
		public func textViewDidBeginEditing(_ textView: UITextView) {
			// pass the message up to our own delegate
			delegate?.textViewDidBeginEditing(self)
		}
		
		open func textViewDidChange(_ textView: UITextView) {
            if !ignoreTextChange{
                didUpdateText()
                Task{
                    delegate?.didChangeSelectedRange(self, selectedRange: textView.selectedRange, textPosition: self.getTextPostion(for: textView.selectedRange))
                }
                
                contentDidChangeSelection()
            }
		}
		
        func refreshColors(allowDelay:Bool=true) {
            refreshTimer?.invalidate()
            if let delegate{
                if allowDelay{
                    refreshTimer = .scheduledTimer(withTimeInterval: 0.5, repeats: false, block: {[weak self] _ in
                        guard let self else{return}
                        self.invalidateCachedTokens()
                        DispatchQueue.main.async {[weak self] in
                            guard let self else{return}
                            self.textView.invalidateCachedParagraphs()
                            self.textView.setNeedsDisplay()
                            self.updateColor(allowDelay: false)
                        }
                    })
                }
                else{
                    self.invalidateCachedTokens()
                    DispatchQueue.main.async {[weak self] in
                        guard let self else{return}
                        self.textView.invalidateCachedParagraphs()
                        self.textView.setNeedsDisplay()
                        self.updateColor(allowDelay: false)
                    }
                }
            }
		}
	
		open func textViewDidChangeSelection(_ textView: UITextView) {
			
			contentDidChangeSelection()
		}
		
	}
	
#endif

extension SyntaxTextView {

	func shouldChangeText(insertingText: String) -> Bool {

		let selectedRange = textView.selectedRange

		let origInsertingText = insertingText

		var insertingText = insertingText
		
		if insertingText == "\n" {
			
			let nsText = textView.text as NSString
			
			var currentLine = nsText.substring(with: nsText.lineRange(for: textView.selectedRange))
			
			if currentLine.hasSuffix("\n") {
				currentLine.removeLast()
			}
			
			var newLinePrefix = ""
			
			for char in currentLine {
				
				let tempSet = CharacterSet(charactersIn: "\(char)")
				
				if tempSet.isSubset(of: .whitespacesAndNewlines) {
					newLinePrefix += "\(char)"
				} else {
					break
				}

			}
			
			insertingText += newLinePrefix
		}
		
		let textStorage: NSTextStorage
		
		#if os(macOS)
		
		guard let _textStorage = textView.textStorage else {
			return true
		}
		
		textStorage = _textStorage
		
		#else
		
		textStorage = textView.textStorage
		#endif
		
		guard let cachedTokens = cachedTokens else {
			return true
		}
			
		for token in cachedTokens {
			
			let range = token.nsRange
			
			if token.token.isEditorPlaceholder {
				
				// Allow editorPlaceholder to be completely deleted.
				if insertingText == "", selectedRange.lowerBound == range.upperBound {
					textStorage.replaceCharacters(in: range, with: insertingText)
					
					didUpdateText()
					
					updateSelectedRange(NSRange(location: range.lowerBound, length: 0))

					return false
				}

				if isEditorPlaceholderSelected(selectedRange: selectedRange, tokenRange: range) {
					
					if insertingText == "\t" {
						
						let placeholderTokens = cachedTokens.filter({
							$0.token.isEditorPlaceholder
						})
						
						guard placeholderTokens.count > 1 else {
							return false
						}
						
						let nextPlaceholderToken = placeholderTokens.first(where: {
							
							let nsRange = $0.nsRange
							
							return nsRange.lowerBound > range.lowerBound
							
						})
						
						if let tokenToSelect = nextPlaceholderToken ?? placeholderTokens.first {
							
							updateSelectedRange(NSRange(location: tokenToSelect.nsRange.lowerBound + 1, length: 0))
							
							return false
							
						}
						
						return false
					}
					
					if selectedRange.location <= range.location || selectedRange.upperBound >= range.upperBound {
						// Editor placeholder is part of larger selected text,
						// so allow system inserting.
						return true
					}
					
//					(textView.undoManager?.prepare(withInvocationTarget: self) as? TextView).replace
					
					textStorage.replaceCharacters(in: range, with: insertingText)
					
					didUpdateText()
					
					updateSelectedRange(NSRange(location: range.lowerBound + insertingText.count, length: 0))

					return false
				}
				
			}
			
		}
		
		if origInsertingText == "\n" {
            let undoManager = textView.undoManager
            let oldText = self.getText(in: selectedRange)
            let newRange = NSRange(location: selectedRange.location, length: insertingText.count)
            undoManager?.registerUndo(withTarget: self, handler: {[weak self] target in
                guard let self else { return }
                let undoManager = textView.undoManager
                
                // 执行撤销操作，同时将替换操作保存为 redo 操作
                undoManager?.registerUndo(withTarget: self, handler: { [weak self] target in
                    guard let self else { return }
                    self.selectedRange = selectedRange
                    self.insertText(insertingText)
                })
                
                // 替换为旧文本
                textStorage.replaceCharacters(in: newRange, with: oldText ?? "")
                self.selectedRange = selectedRange
                
                didUpdateText()
                
                updateSelectedRange(selectedRange)
            })
			textStorage.replaceCharacters(in: selectedRange, with: insertingText)
			
			didUpdateText()
			
			updateSelectedRange(NSRange(location: selectedRange.lowerBound + insertingText.count, length: 0))

			return false
		}
		
		return true
	}
    
    func getText(in nsRange:NSRange)->String?{
        if let textRange = textView.textRange(from: textView.position(from: textView.beginningOfDocument, offset: nsRange.lowerBound)!, to: textView.position(from: textView.beginningOfDocument, offset: nsRange.upperBound)!){
            return textView.text(in: textRange)
        }
        return nil
    }
	
	func contentDidChangeSelection() {
		
		if ignoreSelectionChange {
			return
		}
		
		ignoreSelectionChange = true
		
		selectionDidChange()
		
		ignoreSelectionChange = false
		
	}
	
}
