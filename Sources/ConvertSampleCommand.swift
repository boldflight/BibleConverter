import Foundation
import ArgumentParser
import SwiftSoup

struct ConvertSampleCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "convert-sample",
        abstract: "Convert a simple HTML snippet to Markdown"
    )
    
    @Argument(help: "Path to the HTML file (Example: input/sample.html)")
    var htmlPath: String
    
    @Argument(help: "Output file path for the markdown")
    var outputPath: String
    
    mutating func run() throws {
        print("Converting HTML sample to Markdown...")
        
        // Validate input file exists
        let currentDirectory = FileManager.default.currentDirectoryPath
        let absolutePath: String
        if htmlPath.hasPrefix("/") {
            absolutePath = htmlPath
        } else {
            absolutePath = (currentDirectory as NSString).appendingPathComponent(htmlPath)
        }
        
        guard FileManager.default.fileExists(atPath: absolutePath) else {
            print("File not found at path: \(absolutePath)")
            throw ConversionError.fileNotFound
        }
        
        // Read the file content
        let encoding = try detectEncoding(from: URL(fileURLWithPath: absolutePath))
        let htmlContent = try String(contentsOfFile: absolutePath, encoding: encoding)
        
        // Convert the content to markdown
        let markdown = try convertSampleToMarkdown(htmlContent)
        
        // Save the output
        let outputURL = URL(fileURLWithPath: outputPath)
        try markdown.write(to: outputURL, atomically: true, encoding: .utf8)
        
        print("Conversion complete! Markdown saved to: \(outputPath)")
    }
    
    private func detectEncoding(from url: URL) throws -> String.Encoding {
        // Reuse encoding detection from ConvertCommand
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
    
    private func convertSampleToMarkdown(_ htmlString: String) throws -> String {
        var markdown = ""
        
        do {
            let document = try SwiftSoup.parse(htmlString)
            
            // Process paragraphs
            let paragraphs = try document.select("p")
            
            for paragraph in paragraphs {
                // Convert the paragraph to markdown
                let paragraphText = try processElementRecursively(paragraph)
                markdown += paragraphText + "\n\n"
            }
            
        } catch {
            print("Error parsing HTML: \(error)")
            throw error
        }
        
        return markdown
    }
    
    private func processElementRecursively(_ element: Element) throws -> String {
        // Similar to ConvertCommand's implementation but simplified
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
        // Reuse formatting logic from ConvertCommand
        let tagName = element.tagName().lowercased()
        let innerContent = try processElementRecursively(element)
        
        switch tagName {
        case "b", "strong":
            return "**\(innerContent)**"
        case "i", "em":
            return "_\(innerContent)_"
        case "span":
            if try element.className() == "smcaps" {
                return processSmcapsText(innerContent)
            }
            return innerContent
        default:
            return innerContent
        }
    }
    
    private func processSmcapsText(_ text: String) -> String {
        // Reuse smcaps processing from ConvertCommand
        let hasApostrophe = text.hasSuffix("'") || text.hasSuffix("'")

        if hasApostrophe {
            let cleanText = text.dropLast()
            return "**\(cleanText)**'"

        } else {
            return "**\(text)**"
        }
    }
    
    enum ConversionError: Error {
        case fileNotFound
        case unableToReadFile
    }
}
