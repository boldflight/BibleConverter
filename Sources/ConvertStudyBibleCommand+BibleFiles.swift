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
        
        if debug {
            print("\nProcessing file: \(fileName)")
        }
        
        let markdown: String
        if fileName.contains("outline") {
            if debug { print("Converting outline") }
            markdown = try convertOutlineToMarkdown(content)
        } else if fileName.contains("text_0002") {
            if debug { print("Converting footnotes") }
            markdown = try convertFootnotesToMarkdown(content)
        } else if fileName.contains("text_0003") {
            if debug { print("Converting cross references") }
            markdown = try convertCrossReferencesToMarkdown(content)
        } else if fileName.contains("text_0001") {
            if debug { print("Converting study notes") }
            markdown = try convertStudyNotesToMarkdown(content)
        } else if isTextFile(fileName) {
            if debug { print("Converting Bible text") }
            markdown = try convertBibleTextToMarkdown(content)
        } else {
            if debug { print("Converting introduction") }
            markdown = try convertIntroToMarkdown(content)
        }
        
        guard !markdown.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            if debug {
                print("Error: Empty markdown content for \(fileName)")
                print("Content preview:")
                print(content.prefix(500))
            }
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

    // ADD: Helper to check text file patterns
    private func isTextFile(_ fileName: String) -> Bool {
        let patterns = [
            "text[0-9]+[a-z]?\\.",     // matches text1.xhtml, text3a.xhtml
            "text_[0-9]+\\.",          // matches text_0001.xhtml
            "text[a-z]\\.",            // matches texta.xhtml
            "text\\.xhtml$"            // matches text.xhtml
        ]
        
        return patterns.contains { pattern in
            fileName.range(of: pattern, options: .regularExpression) != nil
        }
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
            let sections = try document.select("p.notesubhead")
            
            for section in sections {
                let chapterTitle = try section.text()
                markdown += "# \(chapterTitle)\n\n"
                
                var currentElement = try section.nextElementSibling()
                
                while let element = currentElement {
                    if element.tagName() == "p" {
                        let className = try element.className()
                        
                        if className == "notesubhead" {
                            break // Next chapter section starts
                        }
                        
                        if className == "note" {
                            let noteText = try processFootnote(element)
                            if !noteText.isEmpty {
                                markdown += noteText
                            }
                        }
                    }
                    
                    currentElement = try currentElement?.nextElementSibling()
                }
                
                markdown += "\n---\n\n" // Add separator between chapters
            }
            
        } catch {
            if debug { print("Error parsing footnotes: \(error)") }
            throw error
        }
        
        return markdown
    }
    
    private func processFootnote(_ element: Element) throws -> String {
        var footnoteText = ""
        
        // Get reference number from note-in-note span
        if let noteRef = try element.select("span.note-in-note a").first() {
            let refNumber = try noteRef.text()
            footnoteText += "[^\(refNumber)]"
        }
        
        // Process the remaining content
        var content = ""
        for node in element.getChildNodes() {
            if let textNode = node as? TextNode {
                content += textNode.text()
            } else if let elementNode = node as? Element {
                let className = try elementNode.className()
                let tagName = elementNode.tagName()
                
                if className != "note-in-note" {
                    if tagName == "span" && className == "i" {
                        content += "_\(try elementNode.text())_"
                    } else {
                        content += try elementNode.text()
                    }
                }
            }
        }
        
        content = content.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if !content.isEmpty {
            footnoteText += " \(content)\n\n"
        }
        
        return footnoteText
    }

    private func convertCrossReferencesToMarkdown(_ content: String) throws -> String {
        var markdown = ""
        
        do {
            let document = try SwiftSoup.parse(content)
            
            // Try both section and div.newpage selectors since some files use different structures
            var sections = try document.select("section, div.newpage")
            
            if sections.isEmpty() {
                sections = try document.select("body")
            }
            
            if debug {
                print("\nProcessing cross references...")
                print("Found \(sections.size()) sections")
                if let firstSection = sections.first() {
                    print("First section preview:")
                    print(try firstSection.html().prefix(200))
                }
            }
            
            for section in sections {
                let verses = try section.select("p.crossref")
                
                if debug {
                    print("\nFound \(verses.size()) verse markers")
                }
                
                for verse in verses {
                    // Check for both span.b and direct b elements
                    let verseNum: String
                    if let spanB = try verse.select("span.b").first() {
                        verseNum = try spanB.text()
                    } else if let directB = try verse.select("b").first() {
                        verseNum = try directB.text()
                    } else {
                        continue
                    }
                    
                    markdown += "## \(verseNum)\n\n"
                    
                    // Get siblings after current verse
                    var currentElement = try verse.nextElementSibling()
                    let notes = Elements()
                    
                    // Handle both direct note classes and nested note spans
                    while let element = currentElement {
                        if element.hasClass("crossref") {
                            break
                        }
                        
                        do {
                            // Check for note classes and nested note spans
                            let hasNoteClass = element.hasClass("note") || element.hasClass("note1")
                            let hasNestedNote = !(try element.select("span.note")).isEmpty()
                            
                            if hasNoteClass || hasNestedNote {
                                notes.add(element)
                            }
                        } catch {
                            if debug { print("Error checking note elements: \(error)") }
                        }
                        
                        currentElement = try element.nextElementSibling()
                    }
                    
                    if debug && notes.isEmpty() {
                        print("Warning: No notes found for verse \(verseNum)")
                    }
                    
                    for note in notes {
                        let reference = try processCrossReference(note)
                        if !reference.isEmpty {
                            markdown += "- \(reference)\n"
                        }
                    }
                    
                    markdown += "\n"
                }
            }
            
            if debug {
                print("\nGenerated markdown preview:")
                print(markdown.prefix(500))
            }
            
        } catch {
            if debug { print("Error parsing cross references: \(error)") }
            throw error
        }
        
        let trimmedMarkdown = markdown.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedMarkdown.isEmpty {
            if debug {
                print("Warning: Generated empty cross references markdown.")
                print("Please check if the file contains the expected structure:")
                print("- p.crossref elements with b or span.b tags for verse numbers")
                print("- p.note or p.note1 elements for references")
                print("- Elements with span.note for nested references")
            }
            throw ConversionError.emptyContent
        }
        
        return markdown
    }

    private func processCrossReference(_ element: Element) throws -> String {
        var reference = ""
        
        // Get the note marker (a, b, c, etc.)
        if let markerElement = try element.select("i").first() {
            let marker = try markerElement.text()
            reference += "[\(marker)] "
        } else if let link = try element.select("a").first(),
                  let marker = try? link.select("i").first()?.text() {
            reference += "[\(marker)] "
        }
        
        // Get all text content, excluding the marker
        var text = element.textNodes()
            .map { $0.text() }
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Clean up any remaining brackets and whitespace
        if text.contains("] ") {
            text = text.components(separatedBy: "] ").last?.trimmingCharacters(in: .whitespacesAndNewlines) ?? text
        }
        
        // Add any references from nested elements
        let nestedRefs = try element.select("a")
            .filter { try !$0.select("i").hasText() }
            .map { try $0.text() }
            .joined(separator: "; ")
        
        if !nestedRefs.isEmpty {
            text += (!text.isEmpty ? "; " : "") + nestedRefs
        }
        
        reference += text
        
        return reference.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func convertBibleTextToMarkdown(_ content: String) throws -> String {
        var markdown = ""
        
        do {
            let document = try SwiftSoup.parse(content)
            
            if debug {
                print("\nParsing Bible text content...")
                if let body = try document.select("body").first() {
                    print("Document structure preview:")
                    print(try body.html().prefix(200))
                }
            }
            
            // Try both section and div.newpage selectors since some files use different structures
            var sections = try document.select("section, div.newpage")
            
            if sections.isEmpty() {
                if debug { print("No sections found, falling back to body") }
                sections = try document.select("body")
            }
            
            for section in sections {
                // Process all content elements in order they appear
                let elements = section.children()
                var currentVerseBlock = ""
                var inPoetryBlock = false
                
                // Define valid paragraph classes
                let regularParagraphClasses = ["p-first", "p", "p-same"]
                let poetryClasses = ["poetrybreak", "poetry", "poetry-first", "poetry-indent", "poetry-indent-last", "poetry-last", "otpoetry"]
                let excludedClasses = ["heading", "notesubhead", "note", "crossref", "image"]
                
                for element in elements {
                    let elementClass = try element.className()
                    
                    // Handle headings inline
                    if element.hasClass("heading") {
                        if !currentVerseBlock.isEmpty {
                            markdown += currentVerseBlock + "\n\n"
                            currentVerseBlock = ""
                        }
                        let headingText = try element.text()
                        markdown += "### \(headingText)\n\n"
                        continue
                    }
                    
                    // Handle chapter numbers
                    if let chapterNum = try element.select("span.chapter-num").first() {
                        let num = try chapterNum.text()
                        if !currentVerseBlock.isEmpty {
                            markdown += currentVerseBlock + "\n\n"
                            currentVerseBlock = ""
                        }
                        markdown += "## Chapter \(num)\n\n"
                        continue
                    }
                    
                    // Check if this is a valid paragraph element
                    let isValidParagraph = element.tagName() == "p" && (
                        regularParagraphClasses.contains(elementClass) ||
                        elementClass.starts(with: "p-") ||
                        poetryClasses.contains(elementClass) ||
                        elementClass.starts(with: "poetry") ||
                        (!excludedClasses.contains { elementClass.contains($0) } && !elementClass.isEmpty)
                    )
                    
                    // Handle poetry blocks
                    if poetryClasses.contains(elementClass) || elementClass.starts(with: "poetry") {
                        if !currentVerseBlock.isEmpty {
                            markdown += currentVerseBlock + "\n\n"
                            currentVerseBlock = ""
                        }
                        
                        let poetryContent = try processPoetryVerse(element)
                        let indentLevel = if elementClass.contains("indent") { "  " } else { "" }
                        markdown += "\(indentLevel)\(poetryContent)\n\n"
                        inPoetryBlock = true
                        continue
                    }
                    
                    if inPoetryBlock && !poetryClasses.contains(elementClass) && !elementClass.starts(with: "poetry") {
                        inPoetryBlock = false
                        markdown += "\n"
                    }
                    
                    // Process regular verse content for valid paragraph elements
                    if isValidParagraph {
                        for node in element.getChildNodes() {
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
                                    currentVerseBlock += try element.text().uppercased()
                                } else {
                                    currentVerseBlock += try element.text()
                                }
                            }
                        }
                    }
                }
                
                if !currentVerseBlock.isEmpty {
                    markdown += currentVerseBlock + "\n\n"
                }
                
                // Handle images and captions
                let figures = try section.select("figure")
                for figure in figures {
                    if let img = try figure.select("img").first() {
                        let src = try img.attr("src")
                        let alt = try img.attr("alt")
                        markdown += "![Image: \(alt)](\(src))\n\n"
                    }
                    
                    if let caption = try figure.select("p.image").first() {
                        let captionText = try caption.text().trimmingCharacters(in: .whitespacesAndNewlines)
                        if !captionText.isEmpty {
                            markdown += "_\(captionText)_\n\n"
                        }
                    }
                }
                
                markdown += "---\n\n"
            }
            
        } catch {
            if debug {
                print("Error parsing Bible text XHTML: \(error)")
                print("Content preview:")
                print(content.prefix(500))
            }
            throw error
        }
        
        let trimmedMarkdown = markdown.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedMarkdown.isEmpty {
            if debug {
                print("Error: Generated empty markdown from content")
                print("Content preview:")
                print(content.prefix(200))
            }
            throw ConversionError.emptyContent
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
}
