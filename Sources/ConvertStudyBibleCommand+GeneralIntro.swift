import Foundation
import SwiftSoup

extension ConvertStudyBibleCommand {

    /// Converts a “general introduction” XHTML file to Markdown and writes it.
    /// Implementation moved out of the main command for clarity.
    ///
    /// - Parameter filename: XHTML filename inside `OEBPS`.
    /// - Throws: `ConversionError` for file I/O or empty output problems.
    func convertGeneralIntro(named filename: String) throws {
        if debug {
            print("\nProcessing general intro file: \(filename)")
            let fileURL = URL(fileURLWithPath: inputPath)
                .appendingPathComponent("OEBPS")
                .appendingPathComponent(filename)
            if let content = try? String(contentsOf: fileURL, encoding: .utf8) {
                print("Raw content sample:")
                print(content.prefix(ConvertStudyBibleCommand.debugLimit))
                print("\nTrying selectors...")
            }
        }
        
        let outputName = filename.replacingOccurrences(of: ".xhtml", with: "")
        let outputPath = "supplementary/introductions/\(outputName)"
        
        let fileURL = URL(fileURLWithPath: inputPath)
            .appendingPathComponent("OEBPS")
            .appendingPathComponent(filename)
        
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            throw ConversionError.fileNotFound
        }
        
        let encoding = try detectEncoding(from: fileURL)
        let content = try String(contentsOf: fileURL, encoding: encoding)
        
        let document = try SwiftSoup.parse(content)
        
        let possibleSelectors = [
            "body > *",
            "section[title]",
            "div.content",
            "div.introduction",
            ".intro-content",
            "article",
            "p",
            ".body",
            ".ArticleSec",
            ".INTRO---BODY-PROFORMA"
        ]
        
        var markdown = ""
        
        for selector in possibleSelectors {
            if debug { print("Trying selector: \(selector)") }
            
            if let elements = try? document.select(selector) {
                if debug { print("Found \(elements.size()) elements with selector \(selector)") }
                
                for element in elements {
                    if debug {
                        let tag = element.tagName()
                        let className = try element.className()
                        let elementKey = "\(tag)-\(className)"
                        
                        if !ConvertStudyBibleCommand.seenElements.contains(elementKey) {
                            print("New element type found:")
                            print("  Tag: \(tag)")
                            print("  Classes: \(className)")
                            print("  Content preview: \(try element.text().prefix(ConvertStudyBibleCommand.debugLimit))")
                            print("")
                            ConvertStudyBibleCommand.seenElements.insert(elementKey)
                        }
                    }
                    
                    let text = try processElementRecursively(element)
                    if !text.isEmpty {
                        let tag = element.tagName()
                        let hasClassTitle = ((try? element.className())?.contains("title")) ?? false
                        
                        if tag == "h1" || tag == "h2" || hasClassTitle {
                            markdown += "# \(text)\n\n"
                        } else {
                            markdown += "\(text)\n\n"
                        }
                    }
                }
            }
        }
        
        if markdown.isEmpty {
            if debug {
                print("\nWarning: No content found using standard selectors")
                print("Full document structure:")
                if let body = try? document.select("body").first() {
                    print(try body.html())
                } else {
                    print("No body element found")
                }
            }
            throw ConversionError.emptyContent
        }
        
        let outputURL = URL(fileURLWithPath: self.outputPath)
            .appendingPathComponent(outputPath)
            .appendingPathExtension("md")
        
        try FileManager.default.createDirectory(at: outputURL.deletingLastPathComponent(),
                                                withIntermediateDirectories: true)
        
        try markdown.write(to: outputURL, atomically: true, encoding: .utf8)
    }
}
