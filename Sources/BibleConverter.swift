import Foundation
import ArgumentParser

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
    
    func convertToMarkdown(_ xhtml: String) throws -> String {
            var markdown = ""
            
            if let match = xhtml.firstMatch(of: /\<title\>.*?\s+(\w+)\s+(\d+)\<\/title\>/) {
                let (_, bookName, chapterNum) = match.output
                markdown += "# \(bookName)\n\n"
                markdown += String(format: Self.chapterFormat, String(chapterNum), String(chapterNum)) + "\n\n"
            }
            
            let sectionPattern = /\<p class=\"paragraphtitle\"\>([^<]+?)\<\/p\>/
            for match in xhtml.matches(of: sectionPattern) {
                let (_, title) = match.output
                markdown += String(format: Self.sectionFormat, String(title)) + "\n\n"
            }
            
            var currentVerse = ""
            let paragraphs = xhtml.matches(of: /\<p class=\"(bodytext|poetry)\"\>(.*?)\<\/p\>/)
            
            for paragraphMatch in paragraphs {
                let (_, style, content) = paragraphMatch.output
                let isPoetry = style == "poetry"
                
                if isPoetry {
                    if let verseMatch = content.firstMatch(of: /\<span class=\"verse\"\>(\d+):(\d+)\<\/span\>\s*([^<]*?)/) {
                        currentVerse = String(verseMatch.output.2)
                        markdown += String(format: Self.verseFormat, currentVerse, verseMatch.output.3.trimmingCharacters(in: .whitespacesAndNewlines)) + "\n"
                    } else {
                        let cleanContent = content.replacingOccurrences(of: "<span class=\"verse\">[0-9]+:[0-9]+</span>", with: "", options: .regularExpression).trimmingCharacters(in: .whitespacesAndNewlines)
                        if !cleanContent.isEmpty {
                            markdown += "- \(cleanContent)\n"
                        }
                    }
                } else {
                    for verseMatch in content.matches(of: /\<span class=\"verse\"\>(\d+):(\d+)\<\/span\>\s*([^<]*?)(?=(?:\<span class=\"verse\"|\<\/p\>))/) {
                        currentVerse = String(verseMatch.output.2)
                        markdown += String(format: Self.verseFormat, currentVerse, verseMatch.output.3.trimmingCharacters(in: .whitespacesAndNewlines)) + "\n"
                    }
                }
            }
            
            return markdown
        }
}
