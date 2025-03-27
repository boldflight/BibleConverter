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
        if filename.contains("intro") {
            return .introduction
        }
        if filename.contains("outline") {
            return .outline
        }
        if filename.hasSuffix("text.xhtml") || filename.contains("text1") {
            return .mainText
        }
        if filename.contains("text_0001") {
            return .studyNotes
        }
        if filename.contains("text_0002") {
            return .footnotes
        }
        if filename.contains("text_0003") {
            return .crossReferences
        }
        
        if let suppType = SupplementaryType.detect(from: filename) {
            return .supplementary(suppType)
        }
        
        return nil
    }
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
