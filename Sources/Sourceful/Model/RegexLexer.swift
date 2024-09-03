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
	
	public let tokenTransformer: TokenTransformer
	
	public init(regularExpression: NSRegularExpression, tokenTransformer: @escaping TokenTransformer) {
		self.regularExpression = regularExpression
		self.tokenTransformer = tokenTransformer
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
			
			guard let swiftRange = Range(numberMatch.range, in: source) else {
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
                
                guard let swiftRange = Range(numberMatch.range, in: source) else {
                    continue
                }
                
                let token = generator.tokenTransformer(swiftRange)
                tokens.append(token)
                
            }
        }
        
        return tokens
    }

}
