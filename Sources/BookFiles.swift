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
        // Improved file type detection
        if filename.contains("intro") {
            return .introduction
        }
        if filename.contains("outline") {
            return .outline
        }
        
        // Match text files with suffixes
        if filename.contains("_0001") {
            return .studyNotes
        }
        if filename.contains("_0002") {
            return .footnotes
        }
        if filename.contains("_0003") {
            return .crossReferences
        }
        
        // Match main text files
        // Example patterns: Gntext.xhtml, Gntext1.xhtml, Gntext2.xhtml
        if filename.range(of: "[A-Za-z]+text[0-9]?\\.xhtml", options: .regularExpression) != nil {
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
