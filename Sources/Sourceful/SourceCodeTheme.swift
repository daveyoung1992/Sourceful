//
//  SourceCodeTheme.swift
//  SourceEditor
//
//  Created by Louis D'hauwe on 24/07/2018.
//  Copyright © 2018 Silver Fox. All rights reserved.
//

import Foundation

public protocol SourceCodeTheme: SyntaxColorTheme {
	func color(for syntaxColorType: SourceCodeTokenType) -> Color
	
}

extension SourceCodeTheme {
	
	public func globalAttributes() -> [NSAttributedString.Key: Any] {
		
		var attributes = [NSAttributedString.Key: Any]()
		
		attributes[.font] = font
        attributes[.foregroundColor] = color(for: .plain)
		
		return attributes
	}
	
	public func attributes(for token: Token) -> [NSAttributedString.Key: Any] {
		var attributes = [NSAttributedString.Key: Any]()
		
		if let token = token as? SimpleSourceCodeToken {
			attributes[.foregroundColor] = color(for: token.type)
		}
		
		return attributes
	}
    public static func loadWithThemeFile(_ path:String) throws -> SourceCodeTheme{
        if let path = Bundle.main.path(forResource: path, ofType: "json"){
            let fileURL = URL(fileURLWithPath: path)
            let data = try Data(contentsOf: fileURL)
            let decoder = JSONDecoder()
            let themeData = try decoder.decode(CustomSourceCodeTheme.self, from: data)
            return themeData
        }
        return DefaultSourceCodeTheme()
    }
}

public struct CustomSourceCodeTheme:SourceCodeTheme,Decodable{
    public func color(for syntaxColorType: SourceCodeTokenType) -> Color {
        switch syntaxColorType {
        case .plain:
            return tokenColors?["plain"]?.color ?? foregroundColor
        case .number:
            return tokenColors?["number"]?.color ?? foregroundColor
        case .string:
            return tokenColors?["string"]?.color ?? foregroundColor
        case .identifier:
            return tokenColors?["id"]?.color ?? foregroundColor
        case .keyword:
            return tokenColors?["keyword"]?.color ?? foregroundColor
        case .comment:
            return tokenColors?["comment"]?.color ?? foregroundColor
        case .editorPlaceholder:
            return tokenColors?["placeholder"]?.color ?? foregroundColor.withAlphaComponent(0.5)
        }
    }
    
    public var lineNumbersStyle: LineNumbersStyle?
    
    public var gutterStyle: GutterStyle
    
    public var font: Font
    
    public var backgroundColor: Color
    
    private var tokenColors:[String:CodableColor]?
    
    private var foregroundColor: Color
    
    enum CodingKeys: String, CodingKey {
        case lineNumberStyle
        case gutterStyle
        case fontStyle
        case backgroundColor
        case tokenColors
    }
    
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let lnStyle = try container.decode(ThemeLineNumberStyle.self, forKey: .lineNumberStyle)
        let fontStyle = try container.decode(ThemeFontStyle.self, forKey: .fontStyle)
        let background = try container.decode(CodableColor.self, forKey: .backgroundColor)
        tokenColors = try container.decode([String:CodableColor].self, forKey: .tokenColors)
        
        self.lineNumbersStyle = LineNumbersStyle(font: Font(name: lnStyle.font, size: lnStyle.size) ?? .systemFont(ofSize: lnStyle.size), textColor: lnStyle.color.color)
        
        self.gutterStyle = GutterStyle(backgroundColor: lnStyle.bgColor.color, minimumWidth: lnStyle.minWidth)
        
        self.font = Font(name: fontStyle.font, size: fontStyle.size) ?? .systemFont(ofSize: fontStyle.size)
        
        self.foregroundColor = fontStyle.color.color
        
        self.backgroundColor = background.color
    }
}

struct ThemeFontStyle:Decodable{
    let color:CodableColor
    let font:String
    let size:CGFloat
}

struct ThemeLineNumberStyle:Decodable{
    let color:CodableColor
    let font:String
    let size:CGFloat
    let bgColor:CodableColor
    let minWidth:CGFloat
}

struct ThemeColorConfig:Decodable{
    let lineNumberStyle:ThemeLineNumberStyle
    let fontStyle:ThemeFontStyle
    let backgroundColor:CodableColor
    let tokenColors:[String:CodableColor]
}


struct CodableColor: Decodable {
    let color: Color

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let colorString = try container.decode(String.self).trimmingCharacters(in: .whitespacesAndNewlines)

        if colorString.hasPrefix("#") {
            // Handle hex colors: #rgb, #rgba, #rrggbb, #rrggbbaa
            self.color = Color(hex: colorString)
        } else if colorString.hasPrefix("rgb") {
            // Handle rgb() or rgba() formats
            self.color = Color(rgbString: colorString)
        } else if let namedColor = Color(named: colorString) {
            // Handle named colors like "red", "blue", etc.
            self.color = namedColor
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid color string: \(colorString)")
        }
    }
}

extension Color {
    // Initialize UIColor from hex string like #fff, #ffffff, #ffffffff
    convenience init(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.hasPrefix("#") ? String(hexSanitized.dropFirst()) : hexSanitized
        
        var hexValue: UInt64 = 0
        Scanner(string: hexSanitized).scanHexInt64(&hexValue)

        switch hexSanitized.count {
        case 3: // #RGB
            self.init(red: CGFloat((hexValue & 0xF00) >> 8) / 15.0,
                      green: CGFloat((hexValue & 0x0F0) >> 4) / 15.0,
                      blue: CGFloat(hexValue & 0x00F) / 15.0,
                      alpha: 1.0)
        case 4: // #RGBA
            self.init(red: CGFloat((hexValue & 0xF000) >> 12) / 15.0,
                      green: CGFloat((hexValue & 0x0F00) >> 8) / 15.0,
                      blue: CGFloat((hexValue & 0x00F0) >> 4) / 15.0,
                      alpha: CGFloat(hexValue & 0x000F) / 15.0)
        case 6: // #RRGGBB
            self.init(red: CGFloat((hexValue & 0xFF0000) >> 16) / 255.0,
                      green: CGFloat((hexValue & 0x00FF00) >> 8) / 255.0,
                      blue: CGFloat(hexValue & 0x0000FF) / 255.0,
                      alpha: 1.0)
        case 8: // #RRGGBBAA
            self.init(red: CGFloat((hexValue & 0xFF000000) >> 24) / 255.0,
                      green: CGFloat((hexValue & 0x00FF0000) >> 16) / 255.0,
                      blue: CGFloat((hexValue & 0x0000FF00) >> 8) / 255.0,
                      alpha: CGFloat(hexValue & 0x000000FF) / 255.0)
        default:
            self.init(white: 0.0, alpha: 0.0)
        }
    }

    // Initialize UIColor from rgb() or rgba() string
    convenience init(rgbString: String) {
        let rgba = rgbString
            .replacingOccurrences(of: "rgba(", with: "")
            .replacingOccurrences(of: "rgb(", with: "")
            .replacingOccurrences(of: ")", with: "")
            .split(separator: ",")
            .map { CGFloat(Double($0.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0) }
        
        let red = rgba[0] / 255.0
        let green = rgba[1] / 255.0
        let blue = rgba[2] / 255.0
        let alpha = rgba.count == 4 ? rgba[3] : 1.0

        self.init(red: red, green: green, blue: blue, alpha: alpha)
    }
}
