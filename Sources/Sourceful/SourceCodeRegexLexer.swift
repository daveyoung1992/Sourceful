//
//  SavannaKit+Swift.swift
//  SourceEditor
//
//  Created by Louis D'hauwe on 24/07/2018.
//  Copyright © 2018 Silver Fox. All rights reserved.
//

import Foundation

public protocol SourceCodeRegexLexer: RegexLexer {
}

extension RegexLexer {
    public func regexGenerator(_ pattern: String, options: NSRegularExpression.Options = [], matchGroup:Int=0, transformer: @escaping TokenTransformer) -> TokenGenerator? {
		
		guard let regex = try? NSRegularExpression(pattern: pattern, options: options) else {
			return nil
		}
		
		return .regex(RegexTokenGenerator(regularExpression: regex,matchGroup: matchGroup, tokenTransformer: transformer))
	}

}

extension SourceCodeRegexLexer {
	
	public func regexGenerator(_ pattern: String, options: NSRegularExpression.Options = [], matchGroup:Int=0, tokenType: SourceCodeTokenType) -> TokenGenerator? {
		
		return regexGenerator(pattern, options: options,matchGroup: matchGroup, transformer: { (range) -> Token in
			return SimpleSourceCodeToken(type: tokenType, range: range)
		})
	}
	
	public func keywordGenerator(_ words: [String], tokenType: SourceCodeTokenType) -> TokenGenerator {
		
		return .keywords(KeywordTokenGenerator(keywords: words, tokenTransformer: { (range) -> Token in
			return SimpleSourceCodeToken(type: tokenType, range: range)
		}))
	}
	
}

enum KeywordType:String,Decodable{
    case regex
    case words
}

enum RegexOptions:String,Decodable{
    case caseInsensitive
    case allowCommentsAndWhitespace
    case ignoreMetacharacters
    case dotMatchesLineSeparators
    case anchorsMatchLines
    case useUnixLineSeparators
    case useUnicodeWordBoundaries
    func toNSRegexOption()->NSRegularExpression.Options{
        switch self {
        case .caseInsensitive:
            return .caseInsensitive
        case .allowCommentsAndWhitespace:
            return .allowCommentsAndWhitespace
        case .ignoreMetacharacters:
            return .ignoreMetacharacters
        case .dotMatchesLineSeparators:
            return .dotMatchesLineSeparators
        case .anchorsMatchLines:
            return .anchorsMatchLines
        case .useUnixLineSeparators:
            return .useUnixLineSeparators
        case .useUnicodeWordBoundaries:
            return .useUnicodeWordBoundaries
        }
    }
}

extension Array where Element == RegexOptions {
    func toNSRegexOptions() -> NSRegularExpression.Options {
        return self.reduce([]) { (result, option) -> NSRegularExpression.Options in
            return result.union(option.toNSRegexOption())
        }
    }
}


struct LanguageLexer:Decodable{
    let type:KeywordType
    let content:String
    let options: [RegexOptions]?
    let matchGroup:Int?
    let tokenType:SourceCodeTokenType
}

public class CustomLexer: SourceCodeRegexLexer,Decodable {
    private var generators:[TokenGenerator]=[]
    
    public func generators(source: String) -> [TokenGenerator] {
        return generators
    }
    
    
    
    required public init(from decoder: any Decoder) throws {
        
        var container = try decoder.unkeyedContainer()
        
        while !container.isAtEnd {
            let lexer = try container.decode(LanguageLexer.self)
            let generator: TokenGenerator?
            
            switch lexer.type {
            case .regex:
                if let options = lexer.options,!options.isEmpty{
                    generator = regexGenerator(lexer.content, options: options.toNSRegexOptions(),matchGroup: lexer.matchGroup ?? 0, tokenType: lexer.tokenType)
                }
                else{
                    generator = regexGenerator(lexer.content,matchGroup: lexer.matchGroup ?? 0, tokenType: lexer.tokenType)
                }
            case .words:
                generator = keywordGenerator(lexer.content.split(separator: " ").map(String.init), tokenType: lexer.tokenType)
            }
            
            if let generator = generator {
                generators.append(generator)
            }
        }
    }
    public static func loadWithFile(_ path:String) throws -> SourceCodeRegexLexer{
        if let path = Bundle.main.path(forResource: path, ofType: "json"){
            let fileURL = URL(fileURLWithPath: path)
            let data = try Data(contentsOf: fileURL)
            let decoder = JSONDecoder()
            let lexer = try decoder.decode(CustomLexer.self, from: data)
            return lexer
        }
        return EmptyLexer()
    }
}
