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
        
        // Process intro file first
        let introFile = "1_chrintro.xhtml"
        let fileURL = URL(fileURLWithPath: inputPath).appendingPathComponent("OEBPS").appendingPathComponent(introFile)
        
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            throw ConversionError.fileNotFound
        }
        
        let encoding = try detectEncoding(from: fileURL)
        let content = try String(contentsOf: fileURL, encoding: encoding)
        
        let markdown = try convertIntroToMarkdown(content)
        
        // Save to output directory with appropriate name
        let outputURL = URL(fileURLWithPath: outputPath)
            .appendingPathComponent("1chronicles_introduction")
            .appendingPathExtension("md")
        
        try markdown.write(to: outputURL, atomically: true, encoding: .utf8)
        
        print("\nConversion complete!")
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
