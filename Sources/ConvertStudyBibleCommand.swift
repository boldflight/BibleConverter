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
        
        // Process various file types
        try convertFile(named: "1_chrintro.xhtml", outputName: "1chronicles_introduction")
        try convertFile(named: "1_chroutline.xhtml", outputName: "1chronicles_outline")
        try convertFile(named: "1_Chrtext_0001.xhtml", outputName: "1chronicles_study_notes_1")
        
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
        } else if fileName.contains("text_") {
            markdown = try convertStudyNotesToMarkdown(content)
        } else {
            markdown = try convertIntroToMarkdown(content)
        }
        
        // Save to output directory
        let outputURL = URL(fileURLWithPath: outputPath)
            .appendingPathComponent(outputName)
            .appendingPathExtension("md")
        
        try markdown.write(to: outputURL, atomically: true, encoding: .utf8)
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
    
    private func convertIntroToMarkdown(_ content: String) throws -> String {
        var markdown = ""
        
        do {
            let document = try SwiftSoup.parse(content)
            
            // Process title section
            if let bookSubtitle = try document.select("p.book-subtitle").first(),
               let bookTitle = try document.select("p.book").first() {
                let subtitle = try processElementRecursively(bookSubtitle)
                let title = try processElementRecursively(bookTitle)
                markdown += "# \(subtitle) \(title)\n\n"
            }
            
            // Process main content sections
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
            
            // Get the main title
            if let titleSection = try document.select("p.ArticleSec").first() {
                let title = try titleSection.text()
                markdown += "# \(title)\n\n"
            }
            
            // Process outline tiers
            let outlineElements = try document.select("p[class^=INTRO---Outline]")
            
            for element in outlineElements {
                let className = try element.className()
                let text = try element.text()
                
                // Remove leading Roman numerals and letters (I., A., 1., etc.)
                let parts = text.components(separatedBy: " ")
                let content = parts.dropFirst().joined(separator: " ")
                
                if className.contains("Teir1") {
                    markdown += "## \(content)\n\n"
                } else if className.contains("tier-2") {
                    // Add some indentation for subpoints
                    markdown += "* \(content)\n"
                } else {
                    // For any other tiers, treat as subpoints with more indentation
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
            
            // Process each chapter's study notes
            let sections = try document.select("p.notesubhead")
            
            for section in sections {
                // Get chapter title
                let chapterTitle = try section.text()
                markdown += "# \(chapterTitle)\n\n"
                
                var currentElement = try section.nextElementSibling()
                
                while let element = currentElement {
                    if element.tagName() == "p" {
                        let className = try element.className()
                        
                        if className == "notesubhead" {
                            // We've reached the next chapter's notes
                            break
                        }
                        
                        if className.contains("rsb-studynote") {
                            // Process verse reference and note content
                            let noteText = try processStudyNote(element)
                            markdown += noteText
                        }
                    }
                    
                    currentElement = try element.nextElementSibling()
                }
                
                markdown += "\n---\n\n" // Add separator between chapters
            }
            
        } catch {
            print("Error parsing XHTML: \(error)")
            throw error
        }
        
        return markdown
    }
    
    private func processStudyNote(_ element: Element) throws -> String {
        var noteText = ""
        
        // Check if this is a new section with verse reference
        if try element.className().contains("studynote-1") {
            noteText += "\n"
        }
        
        // Process verse reference spans and links
        let verseRefs = try element.select("span.rsb-studynote-bold")
        if !verseRefs.isEmpty() {
            let reference = try verseRefs.first()?.text() ?? ""
            noteText += "## \(reference)\n\n"
        }
        
        // Process the main content
        var content = try element.text()
        
        // Remove the verse reference from the content if it exists
        if let firstRef = try element.select("span.rsb-studynote-bold").first() {
            content = content.replacingOccurrences(of: try firstRef.text(), with: "")
        }
        
        // Clean up the content
        content = content.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if !content.isEmpty {
            noteText += "\(content)\n\n"
        }
        
        return noteText
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
    
    enum ConversionError: Error {
        case fileNotFound
        case unableToReadFile
    }
}
