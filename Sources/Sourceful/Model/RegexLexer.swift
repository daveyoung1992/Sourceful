//
//  RegexLexer.swift
//  SavannaKit
//
//  Created by Louis D'hauwe on 05/07/2018.
//  Copyright © 2018 Silver Fox. All rights reserved.
//

import Foundation

public typealias TokenTransformer = (_ range: Range<String.Index>) -> Token

public struct RegexTokenGenerator {
	
	public let regularExpression: NSRegularExpression
    
    public let matchGroup:Int
	
	public let tokenTransformer: TokenTransformer
	
    public init(regularExpression: NSRegularExpression,matchGroup:Int=0, tokenTransformer: @escaping TokenTransformer) {
		self.regularExpression = regularExpression
		self.tokenTransformer = tokenTransformer
        self.matchGroup = matchGroup
	}
}

public struct KeywordTokenGenerator {
	
	public let keywords: [String]
	
	public let tokenTransformer: TokenTransformer
	
	public init(keywords: [String], tokenTransformer: @escaping TokenTransformer) {
		self.keywords = keywords
		self.tokenTransformer = tokenTransformer
	}
	
}

public enum TokenGenerator {
	case keywords(KeywordTokenGenerator)
	case regex(RegexTokenGenerator)
}

public protocol RegexLexer: Lexer {
	
	func generators(source: String) -> [TokenGenerator]
	
}

extension RegexLexer {
	
	public func getSavannaTokens(input: String) -> [Token] {
		
		let generators = self.generators(source: input)
		
		var tokens = [Token]()
        var keywordGenerators:[KeywordTokenGenerator]=[]
        var regexGenerators:[RegexTokenGenerator]=[]
        var stringGenerators:[RegexTokenGenerator]=[]
        var commentGenerators:[RegexTokenGenerator]=[]
		
		for generator in generators {
			
			switch generator {
			case .regex(let regexGenerator):
                regexGenerators.append(regexGenerator)
//				tokens.append(contentsOf: generateRegexTokens(regexGenerator, source: input))

			case .keywords(let keywordGenerator):
                keywordGenerators.append(keywordGenerator)
//				tokens.append(contentsOf: generateKeywordTokens(keywordGenerator, source: input))
				
			}
		
		}
        
//        var keywords:[String] = []
//        // 添加已知的 Type 为keywordToken
//        for token in tokens.filter({$0.isType}){
//            keywords.append(String(input[token.range]).trimmingCharacters(in: .whitespacesAndNewlines))
//        }
//        keywords = Set(keywords).sorted()
//        
//        let typeGenerator = KeywordTokenGenerator(keywords: keywords, tokenTransformer: { (range) -> Token in
//            return SimpleSourceCodeToken(type: .type, range: range)
//        })
//        keywordGenerators.append(typeGenerator)
        tokens.append(contentsOf: generateKeywordTokens(keywordGenerators, source: input))
        tokens.append(contentsOf: generateRegexTokens(regexGenerators, source: input))
        print(tokens.count)
        print("1.\(Date().timeIntervalSince1970)")
        // 将评论token和其它token分开
        var commentTokens: [Token] = []
        var otherTokens: [Token] = []

        for token in tokens {
            if token.isComment {
                commentTokens.append(token)
            } else {
                otherTokens.append(token)
            }
        }
        print("2.\(Date().timeIntervalSince1970)")

//        // 从其它token中排除所有位于评论内的token
//        tokens = commentTokens
//        for token in otherTokens {
//            var isContained = false
//            for commentToken in commentTokens {
//                if commentToken.range.contains(token.range.upperBound) || commentToken.range.contains(token.range.lowerBound) {
//                    isContained = true
//                    break
//                }
//            }
//            if !isContained {
//                tokens.append(token)
//            }
//        }
//        print("3.\(Date().timeIntervalSince1970)")
        // 对 commentTokens 进行排序，方便后续使用二分查找
        commentTokens.sort { $0.range.lowerBound < $1.range.lowerBound }
        tokens = commentTokens
        // 使用二分查找和双向扩展来排除被评论包裹的 token
        for token in otherTokens {
            var low = 0
            var high = commentTokens.count - 1
            var shouldExclude = false

            // 初步二分查找，以 upperBound 为条件判断前后
            while low <= high {
                let mid = (low + high) / 2
                let commentToken = commentTokens[mid]

                if commentToken.range.contains(token.range.lowerBound) || commentToken.range.contains(token.range.upperBound) {
                    shouldExclude = true
                    break
                } else if token.range.upperBound < commentToken.range.lowerBound {
                    high = mid - 1
                } else {
                    low = mid + 1
                }
            }

            // 以 lowerBound 为条件判断前后
            if !shouldExclude {
                low = 0
                high = commentTokens.count - 1
                // 初步二分查找，找到潜在的包含范围
                while low <= high {
                    let mid = (low + high) / 2
                    let commentToken = commentTokens[mid]

                    if commentToken.range.contains(token.range.lowerBound) || commentToken.range.contains(token.range.upperBound) {
                        shouldExclude = true
                        break
                    } else if token.range.lowerBound < commentToken.range.lowerBound {
                        high = mid - 1
                    } else {
                        low = mid + 1
                    }
                }
            }

            // 如果不被任何 commentToken 包含，保留 token
            if !shouldExclude {
                tokens.append(token)
            }
        }
        print("4.\(Date().timeIntervalSince1970)")
		return tokens
	}

}

extension RegexLexer {

	func generateKeywordTokens(_ generator: KeywordTokenGenerator, source: String) -> [Token] {

		var tokens = [Token]()

		source.enumerateSubstrings(in: source.startIndex..<source.endIndex, options: [.byWords]) { (word, range, _, _) in

			if let word = word, generator.keywords.contains(word) {

				let token = generator.tokenTransformer(range)
				tokens.append(token)

			}

		}

		return tokens
	}
    
    func generateKeywordTokens(_ generators: [KeywordTokenGenerator], source: String) -> [Token] {

        var tokens = [Token]()

        source.enumerateSubstrings(in: source.startIndex..<source.endIndex, options: [.byWords]) { (word, range, _, _) in
            if let word{
                for generator in generators {
                    if generator.keywords.contains(word){
                        let token = generator.tokenTransformer(range)
                        tokens.append(token)
                    }
                }
            }
        }

        return tokens
    }
	
	public func generateRegexTokens(_ generator: RegexTokenGenerator, source: String) -> [Token] {

		var tokens = [Token]()

		let fullNSRange = NSRange(location: 0, length: source.utf16.count)
		for numberMatch in generator.regularExpression.matches(in: source, options: [], range: fullNSRange) {
			
			guard let swiftRange = Range(numberMatch.range(at: generator.matchGroup), in: source) else {
				continue
			}
			
			let token = generator.tokenTransformer(swiftRange)
			tokens.append(token)
			
		}
		
		return tokens
	}
    
    public func generateRegexTokens(_ generators: [RegexTokenGenerator], source: String) -> [Token] {

        var tokens = [Token]()

        let fullNSRange = NSRange(location: 0, length: source.utf16.count)
        for generator in generators {
            for numberMatch in generator.regularExpression.matches(in: source, options: [], range: fullNSRange) {
                guard let swiftRange = Range(numberMatch.range(at: generator.matchGroup), in: source) else {
                    continue
                }
                
                let token = generator.tokenTransformer(swiftRange)
                tokens.append(token)
                
            }
        }
        
        return tokens
    }

}
