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
        
        try convertFile(named: "1_chrintro.xhtml", outputName: "1chronicles_introduction")
        try convertFile(named: "1_chroutline.xhtml", outputName: "1chronicles_outline")
        try convertFile(named: "1_Chrtext_0001.xhtml", outputName: "1chronicles_study_notes_1")
        try convertFile(named: "1_Chrtext_0002.xhtml", outputName: "1chronicles_footnotes")
        try convertFile(named: "1_Chrtext_0003.xhtml", outputName: "1chronicles_cross_references")
        try convertFile(named: "1_Chrtext.xhtml", outputName: "1chronicles_text")
        
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
        } else if fileName == "1_Chrtext.xhtml" {
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
                if let headingElements = try section.select("p.heading").first() {
                    let heading = try headingElements.text()
                    markdown += "### \(heading)\n\n"
                }
                
                let paragraphs = try section.select("p.p-first, p.p, p.poetrybreak, p.poetry, p.otpoetry")
                var currentVerseBlock = ""
                
                for paragraph in paragraphs {
                    let paragraphClass = try paragraph.className()
                    
                    if ["poetry", "otpoetry", "poetrybreak"].contains(paragraphClass) {
                        if !currentVerseBlock.isEmpty {
                            markdown += currentVerseBlock + "\n\n"
                            currentVerseBlock = ""
                        }
                        
                        let poetryContent = try processPoetryVerse(paragraph)
                        markdown += poetryContent + "\n\n"
                        continue
                    }
                    
                    for node in paragraph.getChildNodes() {
                        if let textNode = node as? TextNode {
                            currentVerseBlock += textNode.text()
                        } else if let element = node as? Element {
                            if try element.hasClass("verse-num") {
                                if !currentVerseBlock.isEmpty {
                                    markdown += currentVerseBlock.trimmingCharacters(in: .whitespacesAndNewlines) + "\n\n"
                                    currentVerseBlock = ""
                                }
                                let verseNum = try element.text()
                                currentVerseBlock = "**\(verseNum)** "
                            } else if try element.hasClass("crossref") {
                                continue
                            } else if try element.hasClass("note") {
                                continue
                            } else {
                                currentVerseBlock += try element.text()
                            }
                        }
                    }
                }
                
                if !currentVerseBlock.isEmpty {
                    markdown += currentVerseBlock + "\n\n"
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
            } else if let element = node as? Element {
                if try element.hasClass("verse-num") {
                    let verseNum = try element.text()
                    if !verseContent.isEmpty {
                        verseContent += "\n"
                    }
                    verseContent += "**\(verseNum)** "
                } else if !["crossref", "note"].contains(try element.className()) {
                    verseContent += try element.text()
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
    
    enum ConversionError: Error {
        case fileNotFound
        case unableToReadFile
    }
}
