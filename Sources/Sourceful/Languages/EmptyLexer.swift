//
//  SwiftUIView.swift
//  
//
//  Created by user on 2024/8/22.
//

import Foundation

public class EmptyLexer: SourceCodeRegexLexer {
    
    public init() {
        
    }
    
    lazy var generators: [TokenGenerator] = {
        
        var generators = [TokenGenerator?]()

        return generators.compactMap( { $0 })
    }()
    
    public func generators(source: String) -> [TokenGenerator] {
        return generators
    }
    
}
