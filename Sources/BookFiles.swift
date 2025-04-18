//
//  File.swift
//  BibleConverter
//
//  Created by Douglas Hewitt on 3/26/25.
//

import Foundation

struct BookFiles {
    let book: BibleBook
    var introFile: String?
    var outlineFile: String?
    var mainTextFiles: [String] = []
    var studyNotesFile: String?
    var footnotesFile: String?
    var crossRefsFile: String?
    var supplementaryFiles: [SupplementaryType: [String]] = [:]
    
    // Add validation
    var isValid: Bool {
        return mainTextFiles.count > 0
    }
    
    // Add helper for output path
    func outputPath(for filename: String) -> String {
        return "books/\(book.fileName)/\(filename)"
    }
}

enum BibleFileType {
    case introduction
    case outline
    case mainText
    case studyNotes
    case footnotes
    case crossReferences
    case supplementary(SupplementaryType)
    
    static func detect(from filename: String) -> BibleFileType? {
        // Previous patterns remain the same
        if filename.range(of: "intro\\.xhtml$", options: .regularExpression) != nil {
            return .introduction
        }
        if filename.range(of: "outline\\.xhtml$", options: .regularExpression) != nil {
            return .outline
        }
        
        if filename.range(of: "_0001\\.xhtml$", options: .regularExpression) != nil {
            return .studyNotes
        }
        if filename.range(of: "_0002\\.xhtml$", options: .regularExpression) != nil {
            return .footnotes
        }
        if filename.range(of: "_0003\\.xhtml$", options: .regularExpression) != nil {
            return .crossReferences
        }
        
        // CHANGE: Updated pattern to handle all text variations:
        // - Standard text files (text.xhtml)
        // - Numbered variations (text1.xhtml, text2.xhtml)
        // - Letter suffixes (texta.xhtml)
        // - Number-letter combinations (text1a.xhtml, text3a.xhtml)
        // - Underscore variations (_0007a.xhtml)
        // - Numbered book variations (2_Kgstext1a.xhtml)
        // CHANGE: Fix regex pattern to properly match all text file variations:
        // Examples that should match:
        // - Actstexta.xhtml
        // - Jntext1a.xhtml
        // - Pstext_0007a.xhtml
        // - 2_Kgstext1a.xhtml
        // - Jertext3a.xhtml
        let textPattern = "(?:(?:\\d_)?[A-Za-z]+text)(?:[0-9]*[a-z]?|_\\d+[a-z]?)?\\.xhtml$"
        if filename.range(of: textPattern, options: .regularExpression) != nil {
            return .mainText
        }
        
        // Check for supplementary content
        if let suppType = SupplementaryType.detect(from: filename) {
            return .supplementary(suppType)
        }
        
        return nil
    }
}

enum ConversionWarning: String {
    case missingMainText = "Book is missing main text file"
    case multipleCrossRefs = "Multiple cross reference files found"
    case multipleFootnotes = "Multiple footnote files found"
    case multipleStudyNotes = "Multiple study note files found"
    case unknownFileType = "Unknown file type"
}

enum SupplementaryType: Hashable {
    case map
    case concordance
    case articles
    case topical
    case historical
    case theological
    case other(String)
    
    static func detect(from filename: String) -> SupplementaryType? {
        switch filename {
        case let f where f.contains("map"): return .map
        case let f where f.contains("conc"): return .concordance
        case let f where f.contains("article"): return .articles
        case let f where f.contains("topical"): return .topical
        case let f where f.contains("hist"): return .historical
        case let f where f.contains("theo"): return .theological
        case let f where !f.contains("text"): return .other(f)
        default: return nil
        }
    }
}
