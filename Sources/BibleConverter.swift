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
    
    static let chapterFormat = "## Chapter %@ <!-- scripture:%@ -->"
    static let verseFormat = "[%@] %@"
    static let sectionFormat = "### %@"
    
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
        
        do {
            let document = try SwiftSoup.parse(xmlString)
            
            // Titles
            if let title = try document.select("title").first()?.text() {
                markdown += "# \(title)\n\n"
            }
            
            // Headings
            for (i, heading) in ["h1", "h2", "h3"].enumerated() {
                for element in try document.select(heading) {
                    let level = String(repeating: "#", count: i + 1)
                    markdown += "\(level) \(try element.text())\n\n"
                }
            }
            
            // Paragraphs
            for p in try document.select("p") {
                markdown += try p.text() + "\n\n"
            }
            
            // Links
            for a in try document.select("a") {
                let href = try a.attr("href")
                let text = try a.text()
                markdown += "[\(text)](\(href))\n"
            }
            
            // Images
            for img in try document.select("img") {
                let src = try img.attr("src")
                let alt = try img.attr("alt")
                markdown += "![\(alt)](\(src))\n"
            }
            
            // Handle lists, tables, etc., similarly
            
        } catch {
            print("Error parsing XML: \(error)")
            throw error
        }
        
        return markdown
    }
}
