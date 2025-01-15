import Foundation
import ArgumentParser
import SwiftSoup

struct BibleConverter: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "bibleconvert",
        abstract: "Convert Bible EPUB to Markdown files"
    )
    
    @Argument(help: "Path to the EPUB file/package (Example: input/bible.epub)")
    var epubPath: String
    
    @Argument(help: "Output directory for markdown files")
    var outputPath: String
    
    mutating func run() throws {
        try validateEPUB(at: epubPath)
        
        let epubURL = URL(fileURLWithPath: epubPath)
        
        let opfURL = try findOPFFile(in: epubURL)
        let opfData = try Data(contentsOf: opfURL)
        let opfDoc = try XMLDocument(data: opfData)
        
        let spineItems = try parseSpineItems(from: opfDoc)
        let manifestItems = try parseManifestItems(from: opfDoc)
        
        var currentBook: String?
        var currentMarkdown = ""
        
        for itemref in spineItems {
            guard let id = itemref.attribute(forName: "idref")?.stringValue,
                  let item = manifestItems[id],
                  let href = item.attribute(forName: "href")?.stringValue,
                  href.hasSuffix(".xhtml") else { continue }
            
            let fileURL = epubURL.appendingPathComponent("OEBPS").appendingPathComponent(href)
            
            guard FileManager.default.fileExists(atPath: fileURL.path) else {
                print("Warning: Skipping missing file: \(href)")
                continue
            }
            
            let encoding = try detectEncoding(from: fileURL)
            let content = try String(contentsOf: fileURL, encoding: encoding)
            
            let (bookName, markdown) = try convertToMarkdown(content)
            
            if let book = bookName {
                if book != currentBook {
                    if let current = currentBook {
                        try saveBook(current, markdown: currentMarkdown, to: outputPath)
                    }
                    currentBook = book
                    currentMarkdown = markdown
                } else {
                    currentMarkdown += markdown
                }
            }
        }
        
        if let current = currentBook {
            try saveBook(current, markdown: currentMarkdown, to: outputPath)
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
            case "windows-1252": return .windowsCP1252
            case "iso-8859-1": return .isoLatin1
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
        
        var fileName = name.lowercased()
        
        // Map the bookName to BibleBook's fileName
        if let bibleBook = BibleBook.allCases.first(where: { $0.displayName.lowercased() == fileName }) {
            fileName = bibleBook.fileName
        }
        
        let outputURL = URL(fileURLWithPath: path)
            .appendingPathComponent(fileName.replacingOccurrences(of: " ", with: "_"))
            .appendingPathExtension("md")
        try markdown.write(to: outputURL, atomically: true, encoding: .utf8)
    }
    
    func convertToMarkdown(_ xmlString: String) throws -> (String?, String) {
        var markdown = ""
        var bookName = ""
        
        do {
            let document = try SwiftSoup.parse(xmlString)
            
            if let h1 = try document.select("h1").first() {
                bookName = try h1.text().components(separatedBy: "Chapter")[0].trimmingCharacters(in: .whitespacesAndNewlines)
                let chapterNumber = try h1.text().components(separatedBy: "Chapter")[1].trimmingCharacters(in: .whitespacesAndNewlines)
                if chapterNumber == "1" {
                    markdown += "# \(bookName)\n"
                }
                markdown += "\n## Chapter \(chapterNumber)\n\n"
            }
            
            let elements = try document.select("p.paragraphtitle, p.bodytext, p.poetry, p.sosspeaker")
            
            for element in elements {
                let className = try element.className()
                
                if className == "paragraphtitle" {
                    markdown += "\n### \(try element.text())\n\n"
                    continue
                }
                
                if className == "sosspeaker" {
                    markdown += "_\(try element.text())_\n"
                    continue
                }
                
                for smcaps in try element.select("span.smcaps") {
                    let text = try smcaps.text()
                    try smcaps.text(text)
                }
                
                if className == "poetry" {
                    if let verse = try element.select("span.verse").first() {
                        let verseNumber = try verse.text().split(separator: ":")[1]
                        try verse.remove()
                        let verseText = try element.text().trimmingCharacters(in: .whitespaces)
                        markdown += "[\(verseNumber)] \(verseText)\n"
                    } else {
                        let line = try element.text().trimmingCharacters(in: .whitespaces)
                        if !line.isEmpty {
                            markdown += line + "\n"
                        }
                    }
                } else if className == "bodytext" {
                    let verseContent = try element.text()
                    let regex = /(\d+:\d+)\s(.+?)(?=\d+:\d+|\n|$)/
                    let matches = verseContent.matches(of: regex)
                    for match in matches {
                        let verseNumber = match.1.split(separator: ":")[1]
                        let verseText = match.2.trimmingCharacters(in: .whitespaces)
                        markdown += "[\(verseNumber)] \(verseText)\n"
                    }
                }
            }
            
        } catch {
            print("Error parsing XML: \(error)")
            throw error
        }
        
        return (bookName, markdown)
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
}
