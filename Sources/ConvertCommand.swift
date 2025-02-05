import Foundation
import ArgumentParser
import SwiftSoup

struct ConvertCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "convert",
        abstract: "Convert a Bible EPUB file to Markdown files"
    )
    
    @Argument(help: "Path to the EPUB file/package (Example: input/bible.epub)")
    var epubPath: String
    
    @Argument(help: "Output directory for markdown files")
    var outputPath: String
    
    mutating func run() throws {
        var processedFiles = 0
        var uniqueBooks = Set<String>()  // Track unique books
        var skippedXHTMLFiles = 0  // Track number of XHTML files without valid book content
        var progressBar = ProgressBar()
        
        try validateEPUB(at: epubPath)
        
        let epubURL = URL(fileURLWithPath: epubPath)
        
        let opfURL = try findOPFFile(in: epubURL)
        let opfData = try Data(contentsOf: opfURL)
        let opfDoc = try XMLDocument(data: opfData)
        
        let spineItems = try parseSpineItems(from: opfDoc)
        let manifestItems = try parseManifestItems(from: opfDoc)
        
        var currentBook: String?
        var currentMarkdown = ""
        
        print("\nConverting EPUB to Markdown...")
        progressBar.total = spineItems.count
        
        for (index, itemref) in spineItems.enumerated() {
            progressBar.current = index + 1
            progressBar.draw()
            
            guard let id = itemref.attribute(forName: "idref")?.stringValue,
                  let item = manifestItems[id],
                  let href = item.attribute(forName: "href")?.stringValue,
                  href.hasSuffix(".xhtml") else { continue }
            
            let fileURL = epubURL.appendingPathComponent("OEBPS").appendingPathComponent(href)
            
            guard FileManager.default.fileExists(atPath: fileURL.path) else {
                print("\nWarning: Skipping missing file: \(href)")
                continue
            }
            
            processedFiles += 1
            
            let encoding = try detectEncoding(from: fileURL)
            let content = try String(contentsOf: fileURL, encoding: encoding)
            
            let (bookName, markdown) = try convertToMarkdown(content)
            
            if let book = bookName {
                if book != currentBook {
                    if let current = currentBook {
                        do {
                            try saveBook(current, markdown: currentMarkdown, to: outputPath)
                            uniqueBooks.insert(current)
                        } catch ConversionError.emptyContent {
                            skippedXHTMLFiles += 1
                        } catch ConversionError.invalidBookName {
                            skippedXHTMLFiles += 1
                        }
                    }
                    currentBook = book
                    currentMarkdown = markdown
                } else {
                    currentMarkdown += markdown
                }
            }
        }
        
        if let current = currentBook {
            do {
                try saveBook(current, markdown: currentMarkdown, to: outputPath)
                uniqueBooks.insert(current)
            } catch ConversionError.emptyContent {
                skippedXHTMLFiles += 1
            } catch ConversionError.invalidBookName {
                skippedXHTMLFiles += 1
            }
        }
        
        print("\n\nConversion complete!")
        print("Processed \(processedFiles) EPUB chapter files")
        print("Created \(uniqueBooks.count) markdown book files")
        if skippedXHTMLFiles > 0 {
            print("Skipped \(skippedXHTMLFiles) XHTML files without valid book content")
        }
    }
    
    private mutating func validateEPUB(at path: String) throws {
        let currentDirectory = FileManager.default.currentDirectoryPath
        print("Current working directory: \(currentDirectory)")
        
        let absolutePath: String
        if path.hasPrefix("/") {
            absolutePath = path
        } else {
            absolutePath = (currentDirectory as NSString).appendingPathComponent(path)
        }
        print("Absolute path: \(absolutePath)")
        
        guard FileManager.default.fileExists(atPath: absolutePath) else {
            print("File not found at path: \(absolutePath)")
            throw ConversionError.fileNotFound
        }
        
        guard absolutePath.lowercased().hasSuffix(".epub") else {
            print("Error: File must have .epub extension")
            throw ConversionError.invalidFileType
        }
        
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: absolutePath)
            if let fileSize = attributes[.size] as? UInt64 {
                print("File size: \(fileSize) bytes")
                if fileSize < 22 {
                    throw ConversionError.invalidFileSize
                }
            } else {
                print("Could not read file size from attributes")
                throw ConversionError.unableToReadFile
            }
            
            self.epubPath = absolutePath
            
        } catch {
            print("Error reading file attributes: \(error)")
            throw ConversionError.unableToReadFile
        }
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
    
    private func findOPFFile(in epubURL: URL) throws -> URL {
        let containerURL = epubURL.appendingPathComponent("META-INF/container.xml")
        let containerData = try Data(contentsOf: containerURL)
        let containerDoc = try XMLDocument(data: containerData)
        
        guard let opfPath = try containerDoc.nodes(forXPath: "//rootfile/@full-path").first?.stringValue else {
            throw ConversionError.opfNotFound
        }
        
        return epubURL.appendingPathComponent(opfPath)
    }
    
    private func parseSpineItems(from doc: XMLDocument) throws -> [XMLElement] {
        return try doc.nodes(forXPath: "//spine/itemref") as? [XMLElement] ?? []
    }
    
    private func parseManifestItems(from doc: XMLDocument) throws -> [String: XMLElement] {
        let items = try doc.nodes(forXPath: "//manifest/item") as? [XMLElement] ?? []
        return Dictionary(uniqueKeysWithValues: items.compactMap { item in
            guard let id = item.attribute(forName: "id")?.stringValue else { return nil }
            return (id, item)
        })
    }
    
    private func saveBook(_ name: String, markdown: String, to path: String) throws {
        // Skip empty book names
        guard !name.isEmpty else {
            throw ConversionError.invalidBookName("Empty book name")
        }
        
        // Require valid Bible book
        guard let bibleBook = BibleBook.from(name) else {
            throw ConversionError.invalidBookName(name)
        }
        
        let outputURL = URL(fileURLWithPath: path)
            .appendingPathComponent(bibleBook.fileName)
            .appendingPathExtension("md")
        
        // Only write non-empty markdown content
        guard !markdown.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ConversionError.emptyContent
        }
        
        try markdown.write(to: outputURL, atomically: true, encoding: .utf8)
    }
    
    private func convertToMarkdown(_ xmlString: String) throws -> (String?, String) {
        var markdown = ""
        var bookName = ""
        
        do {
            let document = try SwiftSoup.parse(xmlString)
            
            // Book name and chapter handling remains the same
            // First try h1 tag (for most books)
            if let h1 = try document.select("h1").first() {
                bookName = try h1.text().components(separatedBy: "Chapter")[0].trimmingCharacters(in: .whitespacesAndNewlines)
                let chapterNumber = try h1.text().components(separatedBy: "Chapter")[1].trimmingCharacters(in: .whitespacesAndNewlines)
                if chapterNumber == "1" {
                    markdown += "# \(bookName)\n\n"
                }
                markdown += "## Chapter \(chapterNumber)\n\n"
            }
            // Then try h2 tag (for Psalms)
            else if let h2 = try document.select("h2").first() {
                let h2Text = try h2.text()
                if h2Text.starts(with: "Psalm ") {
                    bookName = "Psalms"
                    let psalmNumber = h2Text.components(separatedBy: "Psalm ")[1].trimmingCharacters(in: .whitespacesAndNewlines)
                    if psalmNumber == "1" {
                        markdown += "# \(bookName)\n\n"
                    }
                    markdown += "## Psalm \(psalmNumber)\n\n"
                }
            }
            
            let elements = try document.select("p.paragraphtitle, p.bodytext, p.poetrybreak, p.poetry, p.otpoetry, p.sosspeaker, p.lamhebrew")
            
            for element in elements {
                let className = try element.className()
                
                switch className {
                case "paragraphtitle":
                    markdown += "### \(try element.text())\n\n"
                case "sosspeaker":
                    markdown += "#### \(try element.text())\n\n"
                case "lamhebrew":
                    markdown += "#### \(try element.text())\n\n"
                case "poetry", "otpoetry", "poetrybreak":
                    markdown += try processPoetryElement(element)
                case "bodytext":
                    markdown += try processBodyTextElement(element)
                default:
                    continue
                }
            }
            
        } catch {
            print("Error parsing XML: \(error)")
            throw error
        }
        
        return (bookName, markdown)
    }

    private func processPoetryElement(_ element: Element) throws -> String {
        var poetryMarkdown = ""
        if try element.className() == "poetrybreak" {
            poetryMarkdown += "\n"
        }
        
        let processedText = try processElementRecursively(element)
        poetryMarkdown += processedText.split(separator: "\n").map { $0 + "<br>" }.joined(separator: "\n")
        poetryMarkdown += "\n"
        
        return poetryMarkdown
    }

    private func processBodyTextElement(_ element: Element) throws -> String {
        return try processElementRecursively(element) + "\n\n"
    }

    private func processElementRecursively(_ element: Element) throws -> String {
        var result = ""
        var currentVerseNumber: String?
        
        for node in element.getChildNodes() {
            if let textNode = node as? TextNode {
                if let verseNumber = currentVerseNumber {
                    result = result.trimmingCharacters(in: .whitespaces)
                    result += "\n[\(verseNumber)]"
                    currentVerseNumber = nil
                }
                result += textNode.text()
            } else if let elementNode = node as? Element {
                if try elementNode.className() == "verse" {
                    if let verseText = try elementNode.text().split(separator: ":").last {
                        currentVerseNumber = String(verseText)
                    }
                } else {
                    result += try processInlineFormatting(element: elementNode)
                }
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
                return processSmcapsText(innerContent)
            }
            return innerContent
        default:
            return innerContent
        }
    }

    private func processSmcapsText(_ text: String) -> String {
        let hasApostrophe = text.hasSuffix("'")

        if hasApostrophe {
            let cleanText = text.dropLast()
            return "**\(cleanText)**'"

        } else {
            return "**\(text)**"
        }
    }

    enum ConversionError: Error {
        case opfNotFound
        case fileNotFound
        case unableToReadFile
        case invalidFileSize
        case invalidPath
        case invalidFileType
        case epubExtractionFailed(Error)
        case invalidBookName(String)
        case emptyContent
    }
    
}
