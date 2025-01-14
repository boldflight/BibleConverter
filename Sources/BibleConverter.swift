import Foundation
import ArgumentParser
import SwiftSoup

struct BibleConverter: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "bibleconvert",
        abstract: "Convert Bible XHTML files to Markdown"
    )
    
    @Argument(help: "Path to the EPUB directory containing XHTML files")
    var inputPath: String
    
    @Argument(help: "Output directory for markdown files")
    var outputPath: String
        
    mutating func run() throws {
        let fileManager = FileManager.default
        let enumerator = fileManager.enumerator(atPath: inputPath)
        
        while let filePath = enumerator?.nextObject() as? String {
            guard filePath.hasSuffix(".xhtml") else { continue }
            
            let text = try String(contentsOfFile: inputPath + "/" + filePath, encoding: .utf8)
            let converted = try convertToMarkdown(text)
            
            // Create output path
            let outputFile = (filePath as NSString).deletingPathExtension + ".md"
            let outputURL = URL(fileURLWithPath: outputPath).appendingPathComponent(outputFile)
            
            try converted.write(to: outputURL, atomically: true, encoding: .utf8)
        }
    }
    
    func convertToMarkdown(_ xmlString: String) throws -> String {
        var markdown = ""
        var regularVerses = [String]()
        
        do {
            let document = try SwiftSoup.parse(xmlString)
            
            // Extract book name and chapter from h1
            if let h1 = try document.select("h1").first() {
                let bookName = try h1.text().components(separatedBy: "Chapter")[0].trimmingCharacters(in: .whitespacesAndNewlines)
                let chapterNumber = try h1.text().components(separatedBy: "Chapter")[1].trimmingCharacters(in: .whitespacesAndNewlines)
                markdown += "# \(bookName)\n\n"
                markdown += "## Chapter \(chapterNumber) <!-- scripture:\(chapterNumber) -->\n\n"
            }
            
            // Handle section titles once
            if let title = try document.select("p.paragraphtitle").first() {
                markdown += "### \(try title.text())\n\n"
            }
            
            // Parse paragraphs for verses
            for p in try document.select("p.bodytext, p.poetry") {
                let className = try p.className()
                let verseContent = try p.text()
                
                if className == "poetry" {
                    // Get all text nodes after verse span
                    if let verse = try p.select("span.verse").first() {
                        let verseNumber = try verse.text().split(separator: ":")[1]
                        let verseLine = verse.parent()?.textNodes().map { $0.text().trimmingCharacters(in: .whitespaces) }.joined()
                        regularVerses.append("[\(verseNumber)] \(verseLine ?? "")\n")
                    }
                    // Add subsequent poetry lines without verse numbers
                    let additionalLines = p.textNodes().map { $0.text().trimmingCharacters(in: .whitespaces) }
                    for line in additionalLines where !line.isEmpty {
                        regularVerses.append(line + "\n")
                    }
                } else {
                    let regex = /(\d+:\d+)\s(.+?)(?=\d+:\d+|\n|$)/
                    let matches = verseContent.matches(of: regex)
                    for match in matches {
                        let verseNumber = match.1.split(separator: ":")[1]
                        regularVerses.append("[\(verseNumber)] \(match.2)\n")
                    }
                }
            }
            
            markdown += regularVerses.joined()
            
        } catch {
            print("Error parsing XML: \(error)")
            throw error
        }
        
        return markdown
    }
}
