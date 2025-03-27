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
    var mainTextFile: String?
    var studyNotesFile: String?
    var footnotesFile: String?
    var crossRefsFile: String?
}

enum BibleFileType {
    case introduction
    case outline
    case mainText
    case studyNotes
    case footnotes
    case crossReferences
    
    static func detect(from filename: String) -> BibleFileType? {
        if filename.contains("intro") {
            return .introduction
        } else if filename.contains("outline") {
            return .outline
        } else if filename.contains("_0001") {
            return .studyNotes
        } else if filename.contains("_0002") {
            return .footnotes
        } else if filename.contains("_0003") {
            return .crossReferences
        } else if filename.hasSuffix("text.xhtml") || filename.contains("text1") {
            return .mainText
        }
        return nil
    }
}
