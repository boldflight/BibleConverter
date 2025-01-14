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
        var poetryText = ""
        var regularVerses = [String]()
        var currentVerseNumber = 0
        
        do {
            let document = try SwiftSoup.parse(xmlString)
            
            // Extract book name from title, assuming "NET Bible" format
            if let title = try document.select("title").first()?.text() {
                let components = title.components(separatedBy: " ")
                if let bookName = components.dropLast(2).last {
                    markdown += "# \(bookName)\n\n"
                }
            }
            
            // Handle chapter headings
            if let h1 = try document.select("h1").first() {
                let chapterTitle = try h1.text()
                let chapterNumber = chapterTitle.components(separatedBy: "Chapter ").last ?? ""
                markdown += "## Chapter \(chapterNumber)\n\n"
            }
            
            // Handle section titles
            for h3 in try document.select("p.paragraphtitle") {
                markdown += "### \(try h3.text())\n\n"
            }
            
            // Parse paragraphs for verses, including poetry
            for p in try document.select("p") {
                let className = try p.className()
                var verseContent = try p.text()
                let regex = /(\d+:\d+)\s(.+)/
                
                if let match = verseContent.firstMatch(of: regex) {
                    let thisVerseNumber = Int(match.1.split(separator: ":")[1]) ?? 0
                    if thisVerseNumber < currentVerseNumber {
                        // This means we've moved to poetry or another block after the main text
                        poetryText += "> [\(match.1)] \(match.2)\n\n"
                    } else {
                        currentVerseNumber = thisVerseNumber
                        verseContent = verseContent.replacingOccurrences(of: "\(match.1) \(match.2)", with: "[\(match.1)] \(match.2)")
                        regularVerses.append(verseContent)
                    }
                }
            }
            
            // Combine verses in order, inserting poetry where it belongs
            var combinedVerses: [String] = []
            var poetryInserted = false
            
            for verse in regularVerses {
                if !poetryInserted && verse.contains("1:27") {
                    combinedVerses.append(poetryText)
                    poetryInserted = true
                }
                combinedVerses.append(verse)
            }
            
            // Append all verses to markdown
            markdown += combinedVerses.joined(separator: "\n\n")
            
        } catch {
            print("Error parsing XML: \(error)")
            throw error
        }
        
        return markdown
    }
}
