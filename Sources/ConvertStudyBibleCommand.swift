import Foundation
import ArgumentParser
import SwiftSoup

struct ConvertStudyBibleCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "convert-study",
        abstract: "Convert ESV Study Bible content to Markdown files"
    )
    
    @Argument(help: "Path to the ESV Study Bible content directory")
    var inputPath: String
    
    @Argument(help: "Output directory for markdown files")
    var outputPath: String
    
    mutating func run() throws {
        print("\nConverting ESV Study Bible content to Markdown...")
        
        let fileManager = FileManager.default
        let inputURL = URL(fileURLWithPath: inputPath)
            .appendingPathComponent("OEBPS")
        
        guard let files = try? fileManager.contentsOfDirectory(at: inputURL,
                                                             includingPropertiesForKeys: nil,
                                                             options: [.skipsHiddenFiles]) else {
            throw ConversionError.unableToReadFile
        }
        
        // Group files by book
        var bookGroups: [BibleBook: BookFiles] = [:]
        
        for file in files where file.pathExtension == "xhtml" {
            let filename = file.lastPathComponent
            
            if let suppType = SupplementaryType.detect(from: filename) {
                // Handle supplementary files separately
                try convertSupplementaryFile(named: filename, type: suppType)
                continue
            }
            
            // Extract book code (e.g., "1_Chr", "Gen", "Ps")
            let fileCode = filename.prefix { $0 != "t" && $0 != "i" && $0 != "o" }
                .replacingOccurrences(of: "text", with: "")
                .replacingOccurrences(of: "intro", with: "")
                .replacingOccurrences(of: "outline", with: "")
            
            guard let book = BibleBook.allCases.first(where: { $0.fileName == fileCode }),
                  let fileType = BibleFileType.detect(from: filename) else {
                continue
            }
            
            var bookFiles = bookGroups[book] ?? BookFiles(book: book)
            
            switch fileType {
            case .introduction:
                bookFiles.introFile = filename
            case .outline:
                bookFiles.outlineFile = filename
            case .mainText:
                bookFiles.mainTextFiles.append(filename)
            case .studyNotes:
                bookFiles.studyNotesFile = filename
            case .footnotes:
                bookFiles.footnotesFile = filename
            case .crossReferences:
                bookFiles.crossRefsFile = filename
            case .supplementary(let type):
                bookFiles.supplementaryFiles[type, default: []].append(filename)
            }
            
            bookGroups[book] = bookFiles
        }
        
        // Process each book
        for (_, files) in bookGroups.sorted(by: { $0.key.canonicalOrder < $1.key.canonicalOrder }) {
            print("Converting \(files.book.displayName)...")
            
            let baseFileName = files.book.fileName
            
            if let file = files.introFile {
                try convertFile(named: file, outputName: "\(baseFileName)_introduction")
            }
            
            if let file = files.outlineFile {
                try convertFile(named: file, outputName: "\(baseFileName)_outline")
            }
            
            // Convert all main text files
            for (index, file) in files.mainTextFiles.enumerated() {
                let suffix = index == 0 ? "" : "_\(index + 1)"
                try convertFile(named: file, outputName: "\(baseFileName)_text\(suffix)")
            }
            
            if let file = files.studyNotesFile {
                try convertFile(named: file, outputName: "\(baseFileName)_study_notes")
            }
            
            if let file = files.footnotesFile {
                try convertFile(named: file, outputName: "\(baseFileName)_footnotes")
            }
            
            if let file = files.crossRefsFile {
                try convertFile(named: file, outputName: "\(baseFileName)_cross_references")
            }
        }
        
        print("\nConversion complete!")
    }
    
    private func convertFile(named fileName: String, outputName: String) throws {
        let fileURL = URL(fileURLWithPath: inputPath)
            .appendingPathComponent("OEBPS")
            .appendingPathComponent(fileName)
        
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            throw ConversionError.fileNotFound
        }
        
        let encoding = try detectEncoding(from: fileURL)
        let content = try String(contentsOf: fileURL, encoding: encoding)
        
        let markdown: String
        if fileName.contains("outline") {
            markdown = try convertOutlineToMarkdown(content)
        } else if fileName.contains("text_0002") {
            markdown = try convertFootnotesToMarkdown(content)
        } else if fileName.contains("text_0003") {
            markdown = try convertCrossReferencesToMarkdown(content)
        } else if fileName.contains("text_0001") {
            markdown = try convertStudyNotesToMarkdown(content)
        } else if fileName.hasSuffix("text.xhtml") || fileName.contains("text1") {
            markdown = try convertBibleTextToMarkdown(content)
        } else {
            markdown = try convertIntroToMarkdown(content)
        }
        
        let outputURL = URL(fileURLWithPath: outputPath)
            .appendingPathComponent(outputName)
            .appendingPathExtension("md")
        
        try markdown.write(to: outputURL, atomically: true, encoding: .utf8)
    }
    
    private func convertIntroToMarkdown(_ content: String) throws -> String {
        var markdown = ""
        
        do {
            let document = try SwiftSoup.parse(content)
            
            if let bookSubtitle = try document.select("p.book-subtitle").first(),
               let bookTitle = try document.select("p.book").first() {
                let subtitle = try processElementRecursively(bookSubtitle)
                let title = try processElementRecursively(bookTitle)
                markdown += "# \(subtitle) \(title)\n\n"
            }
            
            let sections = try document.select("p.ArticleSec")
            for section in sections {
                let title = try section.text().uppercased()
                markdown += "## \(title)\n\n"
                
                var currentSection = try section.nextElementSibling()
                while let current = currentSection {
                    let isArticleSection = try current.classNames().contains("ArticleSec")
                    if isArticleSection {
                        break
                    }
                    
                    if current.tagName() == "p" {
                        let paragraphText = try processElementRecursively(current)
                        if !paragraphText.isEmpty {
                            markdown += "\(paragraphText)\n\n"
                        }
                    }
                    currentSection = try current.nextElementSibling()
                }
            }
        } catch {
            print("Error parsing XHTML: \(error)")
            throw error
        }
        
        return markdown
    }
    
    private func convertOutlineToMarkdown(_ content: String) throws -> String {
        var markdown = ""
        
        do {
            let document = try SwiftSoup.parse(content)
            
            if let titleSection = try document.select("p.ArticleSec").first() {
                let title = try titleSection.text()
                markdown += "# \(title)\n\n"
            }
            
            let outlineElements = try document.select("p[class^=INTRO---Outline]")
            
            for element in outlineElements {
                let className = try element.className()
                let text = try element.text()
                
                let parts = text.components(separatedBy: " ")
                let content = parts.dropFirst().joined(separator: " ")
                
                if className.contains("Teir1") {
                    markdown += "## \(content)\n\n"
                } else if className.contains("tier-2") {
                    markdown += "* \(content)\n"
                } else {
                    markdown += "  * \(content)\n"
                }
            }
        } catch {
            print("Error parsing XHTML: \(error)")
            throw error
        }
        
        return markdown
    }
    
    private func convertStudyNotesToMarkdown(_ content: String) throws -> String {
        var markdown = ""
        
        do {
            let document = try SwiftSoup.parse(content)
            
            let sections = try document.select("p.notesubhead")
            
            for section in sections {
                let chapterTitle = try section.text()
                markdown += "# \(chapterTitle)\n\n"
                
                var currentElement = try section.nextElementSibling()
                
                while let element = currentElement {
                    if element.tagName() == "p" {
                        let className = try element.className()
                        
                        if className == "notesubhead" {
                            break
                        }
                        
                        if className.contains("rsb-studynote") {
                            let noteText = try processStudyNote(element)
                            markdown += noteText
                        }
                    }
                    
                    currentElement = try element.nextElementSibling()
                }
                
                markdown += "\n---\n\n"
            }
            
        } catch {
            print("Error parsing XHTML: \(error)")
            throw error
        }
        
        return markdown
    }
    
    private func convertFootnotesToMarkdown(_ content: String) throws -> String {
        var markdown = ""
        
        do {
            let document = try SwiftSoup.parse(content)
            let sections = try document.select("p.notesubhead")
            
            for section in sections {
                let chapterTitle = try section.text()
                markdown += "# \(chapterTitle)\n\n"
                
                var currentElement = try section.nextElementSibling()
                
                while let element = currentElement {
                    if element.tagName() == "p" {
                        let className = try element.className()
                        
                        if className == "notesubhead" {
                            break
                        }
                        
                        if className == "note" {
                            let footnoteText = try processFootnote(element)
                            markdown += footnoteText
                        } else if element.hasClass("crossref") {
                            let crossrefText = try processCrossReference(element)
                            markdown += crossrefText
                        }
                    } else if element.tagName() == "aside" {
                        let epubType = try element.attr("epub:type")
                        let id = element.id()
                        
                        if epubType == "footnote" {
                            markdown += "[^\(id)]:"
                            let footnoteContent = try processElementRecursively(element)
                            markdown += " \(footnoteContent)\n\n"
                        }
                    }
                    
                    currentElement = try element.nextElementSibling()
                }
                
                markdown += "\n---\n\n"
            }
            
        } catch {
            print("Error parsing XHTML: \(error)")
            throw error
        }
        
        return markdown
    }
    
    private func convertCrossReferencesToMarkdown(_ content: String) throws -> String {
        var markdown = ""
        
        do {
            let document = try SwiftSoup.parse(content)
            let sections = try document.select("p.notesubhead")
            
            for section in sections {
                let chapterTitle = try section.text()
                markdown += "# \(chapterTitle)\n\n"
                
                var currentElement = try section.nextElementSibling()
                
                while let element = currentElement {
                    if element.tagName() == "p" {
                        let className = try element.className()
                        
                        if className == "notesubhead" {
                            break
                        }
                        
                        if className == "crossref" {
                            if let verseText = try? element.select("b").first()?.text() {
                                markdown += "## \(verseText)\n\n"
                            }
                        } else if className == "note1" {
                            let reference = try processCrossReference(element)
                            markdown += "- \(reference)\n"
                        }
                    }
                    
                    currentElement = try element.nextElementSibling()
                }
                
                markdown += "\n---\n\n"
            }
            
        } catch {
            print("Error parsing XHTML: \(error)")
            throw error
        }
        
        return markdown
    }
    
    private func convertBibleTextToMarkdown(_ content: String) throws -> String {
        var markdown = ""
        
        do {
            let document = try SwiftSoup.parse(content)
            let sections = try document.select("section")
            
            for section in sections {
                // Process theological boxes first
                let theoBoxes = try section.select("div.gbox")
                for box in theoBoxes {
                    if let header = try box.select("p.theohead").first() {
                        let title = try header.text()
                        markdown += "\n## \(title)\n\n"
                    }
                    
                    let theoContent = try box.select("p.theofirst, p.theobody")
                    for para in theoContent {
                        let text = try processElementRecursively(para)
                        markdown += "\(text)\n\n"
                    }
                    markdown += "---\n\n"
                }
                
                // Process regular headings
                if let headingElements = try section.select("p.heading").first() {
                    let heading = try headingElements.text()
                    markdown += "### \(heading)\n\n"
                }
                
                // Process main content
                let paragraphs = try section.select("p.p-first, p.p, p.poetrybreak, p.poetry, p.poetry-first, p.poetry-indent, p.poetry-indent-last, p.otpoetry")
                var currentVerseBlock = ""
                
                for paragraph in paragraphs {
                    let paragraphClass = try paragraph.className()
                    
                    if ["poetry", "otpoetry", "poetrybreak", "poetry-first", "poetry-indent", "poetry-indent-last"].contains(paragraphClass) {
                        if !currentVerseBlock.isEmpty {
                            markdown += currentVerseBlock + "\n\n"
                            currentVerseBlock = ""
                        }
                        
                        let poetryContent = try processPoetryVerse(paragraph)
                        let indentLevel = if paragraphClass.contains("indent") { "  " } else { "" }
                        markdown += "\(indentLevel)\(poetryContent)\n\n"
                        continue
                    }
                    
                    for node in paragraph.getChildNodes() {
                        if let textNode = node as? TextNode {
                            currentVerseBlock += textNode.text()
                        } else if let element = node as? Element {
                            if element.hasClass("verse-num") {
                                if !currentVerseBlock.isEmpty {
                                    markdown += currentVerseBlock.trimmingCharacters(in: .whitespacesAndNewlines) + "\n\n"
                                    currentVerseBlock = ""
                                }
                                let verseNum = try element.text()
                                currentVerseBlock = "**\(verseNum)** "
                            } else if element.hasClass("crossref") {
                                let refId = try element.select("a").attr("href")
                                currentVerseBlock += "[†](\(refId))"
                            } else if element.hasClass("note") {
                                let noteId = try element.select("a").attr("href")
                                currentVerseBlock += "[*](\(noteId))"
                            } else if element.tagName() == "small" {
                                // Handle small caps for LORD
                                currentVerseBlock += "**\(try element.text())**"
                            } else {
                                currentVerseBlock += try element.text()
                            }
                        }
                    }
                }
                
                if !currentVerseBlock.isEmpty {
                    markdown += currentVerseBlock + "\n\n"
                }
                
                // Process navigation links
                if let navLink = try section.select("p.centerr").first() {
                    let link = try navLink.text()
                    markdown += "\n---\n\n➜ \(link)\n\n"
                }
                
                markdown += "---\n\n"
            }
            
        } catch {
            print("Error parsing Bible text XHTML: \(error)")
            throw error
        }
        
        return markdown
    }
    
    private func processPoetryVerse(_ element: Element) throws -> String {
        var verseContent = ""
        
        for node in element.getChildNodes() {
            if let textNode = node as? TextNode {
                verseContent += textNode.text()
            } else if let elementNode = node as? Element {
                if elementNode.hasClass("verse-num") {
                    let verseNum = try elementNode.text()
                    if !verseContent.isEmpty {
                        verseContent += "\n"
                    }
                    verseContent += "**\(verseNum)** "
                } else if elementNode.hasClass("crossref") {
                    let refId = try elementNode.select("a").attr("href")
                    verseContent += "[†](\(refId))"
                } else if elementNode.hasClass("note") {
                    let noteId = try elementNode.select("a").attr("href")
                    verseContent += "[*](\(noteId))"
                } else if elementNode.tagName() == "small" {
                    verseContent += "**\(try elementNode.text())**"
                } else if !["crossref", "note"].contains(try elementNode.className()) {
                    verseContent += try elementNode.text()
                }
            }
        }
        
        return verseContent.split(separator: "\n").map { line in
            "> \(line)"
        }.joined(separator: "\n")
    }
    
    private func processStudyNote(_ element: Element) throws -> String {
        var noteText = ""
        
        if try element.className().contains("studynote-1") {
            noteText += "\n"
        }
        
        let verseRefs = try element.select("span.rsb-studynote-bold")
        if !verseRefs.isEmpty() {
            let reference = try verseRefs.first()?.text() ?? ""
            noteText += "## \(reference)\n\n"
        }
        
        var content = try element.text()
        
        if let firstRef = try element.select("span.rsb-studynote-bold").first() {
            content = content.replacingOccurrences(of: try firstRef.text(), with: "")
        }
        
        content = content.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if !content.isEmpty {
            noteText += "\(content)\n\n"
        }
        
        return noteText
    }
    
    private func processFootnote(_ element: Element) throws -> String {
        var footnoteText = ""
        
        if let noteRef = try element.select("span.note-in-note").first(),
           let link = try noteRef.select("a").first() {
            let refNumber = try link.text()
            footnoteText += "[^\(refNumber)]"
        }
        
        var content = try element.text()
        
        if let firstRef = try element.select("span.note-in-note").first() {
            content = content.replacingOccurrences(of: try firstRef.text(), with: "")
        }
        
        content = content.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if !content.isEmpty {
            footnoteText += " \(content)\n\n"
        }
        
        return footnoteText
    }
    
    private func processCrossReference(_ element: Element) throws -> String {
        var referenceText = ""
        
        if let noteSpan = try element.select("span.note").first(),
           let link = try noteSpan.select("a").first() {
            let refNumber = try link.text()
            referenceText += "(\(refNumber)) "
        }
        
        var content = try element.text()
        
        if let firstRef = try element.select("span.note").first() {
            content = content.replacingOccurrences(of: try firstRef.text(), with: "")
        }
        
        content = content.trimmingCharacters(in: .whitespacesAndNewlines)
        referenceText += content
        
        return referenceText
    }
    
    private func processElementRecursively(_ element: Element) throws -> String {
        var result = ""
        
        for node in element.getChildNodes() {
            if let textNode = node as? TextNode {
                result += textNode.text()
            } else if let elementNode = node as? Element {
                result += try processInlineFormatting(element: elementNode)
            }
        }
        
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    private func processInlineFormatting(element: Element) throws -> String {
        let tagName = element.tagName().lowercased()
        let innerContent = try processElementRecursively(element)
        
        switch tagName {
        case "b", "strong":
            return "**\(innerContent)**"
        case "i", "em":
            return "_\(innerContent)_"
        case "span":
            if try element.className() == "smcaps" {
                return "**\(innerContent)**"
            }
            if try element.className() == "i" {
                return "_\(innerContent)_"
            }
            return innerContent
        default:
            return innerContent
        }
    }
    
    private func detectEncoding(from url: URL) throws -> String.Encoding {
        let data = try Data(contentsOf: url)
        let xmlString = String(data: data, encoding: .utf8) ?? ""
        
        if let encodingMatch = xmlString.firstMatch(of: /encoding="([^"]+)"/) {
            switch encodingMatch.1.lowercased() {
            case "utf-8": return .utf8
            case "windows-1252", "cp1252": return .windowsCP1252
            case "iso-8859-1", "latin1": return .isoLatin1
            case "utf-16": return .utf16
            case "ascii": return .ascii
            default: return .utf8
            }
        }
        return .utf8
    }
    
    private func convertSupplementaryFile(named filename: String, type: SupplementaryType) throws {
        let outputName = filename.replacingOccurrences(of: ".xhtml", with: "")
        try convertFile(named: filename, outputName: outputName)
    }
    
    enum ConversionError: Error {
        case fileNotFound
        case unableToReadFile
    }
}
