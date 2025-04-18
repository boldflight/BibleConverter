import Foundation
import SwiftSoup

extension ConvertStudyBibleCommand {

    // MARK: ‑ Dispatcher
    func convertFile(named fileName: String, outputName: String) throws {
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
        
        guard !markdown.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            if debug { print("Warning: Empty markdown content for \(fileName)") }
            throw ConversionError.emptyContent
        }
        
        let outputURL = URL(fileURLWithPath: outputPath)
            .appendingPathComponent(outputName)
            .appendingPathExtension("md")
        
        try FileManager.default.createDirectory(at: outputURL.deletingLastPathComponent(),
                                                withIntermediateDirectories: true)
        
        try markdown.write(to: outputURL, atomically: true, encoding: .utf8)
        
        if debug { print("Successfully converted \(fileName) to \(outputURL.path)") }
    }

    // MARK: ‑ Book‑specific converters
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
            
            if debug {
                print("\nConverting outline content...")
                print("Document structure:")
                print(try document.select("body").first()?.html().prefix(ConvertStudyBibleCommand.debugLimit) ?? "No body found")
            }
            
            if let titleElement = try document.select("p.ArticleSec").first() {
                let title = try titleElement.text()
                markdown += "# \(title)\n\n"
            }
            
            let outlineElements = try document.select("p[class^=INTRO---Outline]")
            
            for element in outlineElements {
                let className = try element.className()
                let text = try element.text().trimmingCharacters(in: .whitespacesAndNewlines)
                
                if text.isEmpty { continue }
                
                if className.contains("Teir1") || className.contains("Tier1") {
                    markdown += "## \(text)\n\n"
                } else if className.contains("tier-2") {
                    markdown += "* \(text)\n"
                } else {
                    markdown += "  * \(text)\n"
                }
            }
            
            if debug {
                print("\nProcessed outline elements:")
                print(markdown)
            }
            
        } catch {
            if debug { print("Error parsing outline: \(error)") }
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
                    
                    currentElement = try currentElement?.nextElementSibling()
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
            
            let footnotes = try document.select("aside[epub\\:type=footnote]")
            
            for footnote in footnotes {
                let noteId = footnote.id()
                markdown += "[^\(noteId)] "
                
                let paragraphs = try footnote.select("p")
                for paragraph in paragraphs {
                    try paragraph.select("b").unwrap()
                    try paragraph.select("small").wrap("<strong>")
                    
                    let text = try paragraph.text()
                        .replacingOccurrences(of: "LORD", with: "Lord")
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                    
                    if !text.isEmpty {
                        markdown += text + " "
                    }
                }
                
                markdown += "\n\n"
            }
            
        } catch {
            if debug { print("Error parsing footnotes: \(error)") }
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
                    
                    currentElement = try currentElement?.nextElementSibling()
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
                
                if let headingElements = try section.select("p.heading").first() {
                    let heading = try headingElements.text()
                    markdown += "### \(heading)\n\n"
                }
                
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

    // Helpers used only by book converters
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
}
