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
    
    @Flag(name: .long, help: "Enable verbose debugging output")
    var debug = false
    
    private static let ignoredFiles: Set<String> = [
        "nav.xhtml",
        "toc.xhtml",
        "toc.ncx",
        "content.opf",
        "cover.xhtml",
        "styles"
    ]
    
    private static let outputDirectories: [String] = [
        "books",
        "supplementary/maps",
        "supplementary/concordance",
        "supplementary/articles",
        "supplementary/topical",
        "supplementary/historical",
        "supplementary/theological",
        "supplementary/other",
        "supplementary/introductions"
    ]
    
    mutating func run() throws {
        print("\nConverting ESV Study Bible content to Markdown...")
        
        try createOutputDirectories()
        
        let fileManager = FileManager.default
        let inputURL = URL(fileURLWithPath: inputPath)
            .appendingPathComponent("OEBPS")
        
        guard let files = try? fileManager.contentsOfDirectory(at: inputURL,
                                                             includingPropertiesForKeys: nil,
                                                             options: [.skipsHiddenFiles]) else {
            throw ConversionError.unableToReadFile
        }
        
        if debug {
            print("\nFound files:")
            files.forEach { print($0.lastPathComponent) }
        }
        
        var progressBar = ProgressBar(total: files.count)
        var processedCount = 0
        var errorCount = 0
        var warningCount = 0
        
        var bookGroups: [BibleBook: BookFiles] = [:]
        var supplementaryFiles: [SupplementaryType: [String]] = [:]
        var generalIntros: [String] = []
        
        for file in files where file.pathExtension == "xhtml" {
            let filename = file.lastPathComponent
            
            if Self.ignoredFiles.contains(filename) {
                if debug { print("Skipping ignored file: \(filename)") }
                continue
            }
            
            if filename.hasSuffix("intro.xhtml") && !filename.contains("/") {
                generalIntros.append(filename)
                continue
            }
            
            if let suppType = SupplementaryType.detect(from: filename) {
                supplementaryFiles[suppType, default: []].append(filename)
                continue
            }
            
            let fileCode = filename.prefix { $0 != "t" && $0 != "i" && $0 != "o" }
                .replacingOccurrences(of: "text", with: "")
                .replacingOccurrences(of: "intro", with: "")
                .replacingOccurrences(of: "outline", with: "")
                .trimmingCharacters(in: .whitespaces)
            
            if debug { print("Processing file: \(filename) with code: \(fileCode)") }
            
            guard let book = BibleBook.allCases.first(where: { $0.fileName == fileCode }),
                  let fileType = BibleFileType.detect(from: filename) else {
                if debug { print("Warning: Could not determine book or file type for \(filename)") }
                warningCount += 1
                continue
            }
            
            var bookFiles = bookGroups[book] ?? BookFiles(book: book)
            
            switch fileType {
            case .introduction:
                bookFiles.introFile = filename
            case .outline:
                bookFiles.outlineFile = filename
            case .mainText:
                bookFiles.mainTextFiles.append(filename)
            case .studyNotes:
                bookFiles.studyNotesFile = filename
            case .footnotes:
                bookFiles.footnotesFile = filename
            case .crossReferences:
                bookFiles.crossRefsFile = filename
            case .supplementary(let type):
                bookFiles.supplementaryFiles[type, default: []].append(filename)
            }
            
            bookGroups[book] = bookFiles
        }
        
        for (_, files) in bookGroups.sorted(by: { $0.key.canonicalOrder < $1.key.canonicalOrder }) {
            print("\nConverting \(files.book.displayName)...")
            
            let bookOutputDir = "\(outputPath)/books/\(files.book.fileName)"
            try? fileManager.createDirectory(at: URL(fileURLWithPath: bookOutputDir),
                                          withIntermediateDirectories: true)
            
            if let file = files.introFile {
                do {
                    try convertFile(named: file,
                                  outputName: "books/\(files.book.fileName)/\(files.book.fileName)_introduction")
                    processedCount += 1
                } catch {
                    errorCount += 1
                    print("Error converting introduction for \(files.book.displayName): \(error)")
                }
            }
            
            if let file = files.outlineFile {
                do {
                    try convertFile(named: file,
                                  outputName: "books/\(files.book.fileName)/\(files.book.fileName)_outline")
                    processedCount += 1
                } catch {
                    errorCount += 1
                    print("Error converting outline for \(files.book.displayName): \(error)")
                }
            }
            
            for (index, file) in files.mainTextFiles.enumerated() {
                do {
                    let suffix = index == 0 ? "" : "_\(index + 1)"
                    try convertFile(named: file,
                                  outputName: "books/\(files.book.fileName)/\(files.book.fileName)_text\(suffix)")
                    processedCount += 1
                } catch {
                    errorCount += 1
                    print("Error converting text file \(index + 1) for \(files.book.displayName): \(error)")
                }
            }
            
            if let file = files.studyNotesFile {
                do {
                    try convertFile(named: file,
                                  outputName: "books/\(files.book.fileName)/\(files.book.fileName)_study_notes")
                    processedCount += 1
                } catch {
                    errorCount += 1
                    print("Error converting study notes for \(files.book.displayName): \(error)")
                }
            }
            
            if let file = files.footnotesFile {
                do {
                    try convertFile(named: file,
                                  outputName: "books/\(files.book.fileName)/\(files.book.fileName)_footnotes")
                    processedCount += 1
                } catch {
                    errorCount += 1
                    print("Error converting footnotes for \(files.book.displayName): \(error)")
                }
            }
            
            if let file = files.crossRefsFile {
                do {
                    try convertFile(named: file,
                                  outputName: "books/\(files.book.fileName)/\(files.book.fileName)_cross_references")
                    processedCount += 1
                } catch {
                    errorCount += 1
                    print("Error converting cross references for \(files.book.displayName): \(error)")
                }
            }
            
            progressBar.current = processedCount
            progressBar.draw()
        }
        
        print("\nConverting general introductions...")
        for file in generalIntros {
            do {
                try convertGeneralIntro(named: file)
                processedCount += 1
                progressBar.current = processedCount
                progressBar.draw()
            } catch {
                errorCount += 1
                print("Error converting general intro \(file): \(error)")
            }
        }
        
        print("\nConverting supplementary materials...")
        for (type, files) in supplementaryFiles {
            for file in files {
                do {
                    try convertSupplementaryFile(named: file, type: type)
                    processedCount += 1
                    progressBar.current = processedCount
                    progressBar.draw()
                } catch {
                    errorCount += 1
                    print("Error converting supplementary file \(file): \(error)")
                }
            }
        }
        
        print("\nConversion complete!")
        print("Processed: \(processedCount) files")
        print("Warnings: \(warningCount)")
        print("Errors: \(errorCount)")
        
        if errorCount > 0 || warningCount > 0 {
            print("\nPlease check the console output above for specific error messages.")
        }
    }
    
    private func createOutputDirectories() throws {
        let fileManager = FileManager.default
        let baseURL = URL(fileURLWithPath: outputPath)
        
        for directory in Self.outputDirectories {
            let directoryURL = baseURL.appendingPathComponent(directory)
            try? fileManager.createDirectory(at: directoryURL,
                                          withIntermediateDirectories: true)
        }
    }
    
    private func convertGeneralIntro(named filename: String) throws {
        let outputName = filename.replacingOccurrences(of: ".xhtml", with: "")
        let outputPath = "supplementary/introductions/\(outputName)"
        try convertFile(named: filename, outputName: outputPath)
    }
    
    private func convertSupplementaryFile(named filename: String, type: SupplementaryType) throws {
        let outputName = filename.replacingOccurrences(of: ".xhtml", with: "")
        let directory = switch type {
        case .map: "maps"
        case .concordance: "concordance"
        case .articles: "articles"
        case .topical: "topical"
        case .historical: "historical"
        case .theological: "theological"
        case .other: "other"
        }
        
        let fileURL = URL(fileURLWithPath: inputPath)
            .appendingPathComponent("OEBPS")
            .appendingPathComponent(filename)
        
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            throw ConversionError.fileNotFound
        }
        
        let encoding = try detectEncoding(from: fileURL)
        let content = try String(contentsOf: fileURL, encoding: encoding)
        
        let markdown: String
        switch type {
        case .concordance:
            markdown = try convertConcordanceToMarkdown(content)
        case .map:
            markdown = try convertMapToMarkdown(content)
        case .topical:
            markdown = try convertTopicalToMarkdown(content)
        case .articles:
            markdown = try convertArticleToMarkdown(content)
        default:
            markdown = try convertGenericSupplementaryToMarkdown(content)
        }
        
        guard !markdown.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            if debug {
                print("Warning: Empty markdown content for \(filename)")
                print("Content type: \(type)")
                print("Raw content sample: \(String(content.prefix(200)))")
            }
            throw ConversionError.emptyContent
        }
        
        let outputPath = "supplementary/\(directory)/\(outputName)"
        let outputURL = URL(fileURLWithPath: self.outputPath)
            .appendingPathComponent(outputPath)
            .appendingPathExtension("md")
        
        try FileManager.default.createDirectory(at: outputURL.deletingLastPathComponent(),
                                             withIntermediateDirectories: true)
        
        try markdown.write(to: outputURL, atomically: true, encoding: .utf8)
    }
    
    private func convertConcordanceToMarkdown(_ content: String) throws -> String {
        var markdown = ""
        
        do {
            let document = try SwiftSoup.parse(content)
            
            if debug {
                print("\nParsing concordance content...")
                print("Document structure:")
                print(try document.select("body").first()?.html() ?? "No body found")
            }
            
            let entries = try document.select("div.concordance-entry, div.entry, p.concordance, p.concordanceentry, p.entry, .concordance-item")
            
            if entries.isEmpty() && debug {
                print("No entries found with standard concordance classes")
            }
            
            for entry in entries {
                let entryText = try processElementRecursively(entry)
                if !entryText.isEmpty {
                    markdown += "- \(entryText)\n\n"
                }
            }
            
            if markdown.isEmpty {
                let contentElements = try document.select("body > *")
                
                for element in contentElements {
                    let tag = element.tagName()
                    let className = try element.className()
                    
                    if debug {
                        print("Processing element: \(tag) with class: \(className)")
                    }
                    
                    if ["nav", "header", "footer"].contains(tag) {
                        continue
                    }
                    
                    let text = try processElementRecursively(element)
                    if !text.isEmpty {
                        if tag == "h1" || tag == "h2" || tag == "h3" {
                            markdown += "# \(text)\n\n"
                        } else if className.contains("title") || className.contains("header") {
                            markdown += "## \(text)\n\n"
                        } else {
                            markdown += "\(text)\n\n"
                        }
                    }
                }
            }
            
            if markdown.isEmpty && debug {
                print("Warning: No content found in document")
                print("Document structure:")
                print(try document.select("body").first()?.html() ?? "No body found")
            }
            
        } catch {
            if debug { print("Error parsing concordance: \(error)") }
            throw error
        }
        
        return markdown
    }
    
    private func convertMapToMarkdown(_ content: String) throws -> String {
        var markdown = ""
        
        do {
            let document = try SwiftSoup.parse(content)
            
            if debug {
                print("\nParsing map content...")
                print("Document structure:")
                print(try document.select("body").first()?.html() ?? "No body found")
            }
            
            let elements = try document.select("body *")
            var hasContent = false
            
            for element in elements {
                let tag = element.tagName()
                let className = try element.className()
                let text = try element.text().trimmingCharacters(in: .whitespacesAndNewlines)
                
                if debug {
                    print("Processing element: \(tag) with class: \(className)")
                }
                
                if text.isEmpty {
                    continue
                }
                
                hasContent = true
                
                if tag == "h1" || tag == "h2" || className.contains("title") {
                    markdown += "# \(text)\n\n"
                } else if tag == "h3" || tag == "h4" || className.contains("subtitle") {
                    markdown += "## \(text)\n\n"
                } else if className.contains("description") || className.contains("caption") {
                    markdown += "\(text)\n\n"
                } else if className.contains("note") || className.contains("reference") {
                    markdown += "_\(text)_\n\n"
                } else if tag == "img" {
                    let src = try element.attr("src")
                    let alt = try element.attr("alt")
                    markdown += "![Map: \(alt)](\(src))\n\n"
                } else {
                    markdown += "\(text)\n\n"
                }
            }
            
            if !hasContent && debug {
                print("Warning: No content found in map document")
                print("Full HTML:")
                print(try document.html())
            }
            
        } catch {
            if debug { print("Error parsing map: \(error)") }
            throw error
        }
        
        return markdown
    }
    
    private func convertTopicalToMarkdown(_ content: String) throws -> String {
        var markdown = ""
        
        do {
            let document = try SwiftSoup.parse(content)
            
            if let title = try document.select("h1, h2, .title, p.topictitle").first() {
                markdown += "# \(try title.text())\n\n"
            }
            
            let sections = try document.select("div.topic, div.section")
            if !sections.isEmpty() {
                for section in sections {
                    if let sectionTitle = try section.select("h3, h4, p.sectiontitle").first() {
                        markdown += "## \(try sectionTitle.text())\n\n"
                    }
                    
                    let paragraphs = try section.select("p:not(.sectiontitle)")
                    for p in paragraphs {
                        let text = try processElementRecursively(p)
                        if !text.isEmpty {
                            markdown += "\(text)\n\n"
                        }
                    }
                }
            } else {
                let paragraphs = try document.select("p:not(.topictitle)")
                for p in paragraphs {
                    let text = try processElementRecursively(p)
                    if !text.isEmpty {
                        markdown += "\(text)\n\n"
                    }
                }
            }
        } catch {
            if debug { print("Error parsing topical: \(error)") }
            throw error
        }
        
        return markdown
    }
    
    private func convertArticleToMarkdown(_ content: String) throws -> String {
        var markdown = ""
        
        do {
            let document = try SwiftSoup.parse(content)
            
            if let title = try document.select("h1, h2, .title, p.articletitle").first() {
                markdown += "# \(try title.text())\n\n"
            }
            
            let sections = try document.select("div.section, div.article")
            if !sections.isEmpty() {
                for section in sections {
                    if let sectionTitle = try section.select("h3, h4, p.sectiontitle").first() {
                        markdown += "## \(try sectionTitle.text())\n\n"
                    }
                    
                    let paragraphs = try section.select("p:not(.sectiontitle)")
                    for p in paragraphs {
                        let text = try processElementRecursively(p)
                        if !text.isEmpty {
                            markdown += "\(text)\n\n"
                        }
                    }
                }
            } else {
                let paragraphs = try document.select("p:not(.articletitle)")
                for p in paragraphs {
                    let text = try processElementRecursively(p)
                    if !text.isEmpty {
                        markdown += "\(text)\n\n"
                    }
                }
            }
        } catch {
            if debug { print("Error parsing article: \(error)") }
            throw error
        }
        
        return markdown
    }
    
    private func convertGenericSupplementaryToMarkdown(_ content: String) throws -> String {
        var markdown = ""
        
        do {
            let document = try SwiftSoup.parse(content)
            
            if debug {
                print("\nParsing generic supplementary content...")
                print("Document structure:")
                print(try document.select("body").first()?.html() ?? "No body found")
            }
            
            if let title = try document.select("h1, h2, .title, .header, div[class*=title], div[class*=header]").first() {
                markdown += "# \(try title.text())\n\n"
            }
            
            let elements = try document.select("body *")
            var hasContent = false
            
            for element in elements {
                let tag = element.tagName()
                let className = try element.className()
                let text = try processElementRecursively(element)
                
                if debug {
                    print("Processing element: \(tag) with class: \(className)")
                }
                
                if !text.isEmpty {
                    hasContent = true
                    
                    if tag.starts(with: "h") || className.contains("title") || className.contains("header") {
                        let level = tag.dropFirst().first.flatMap { Int(String($0)) } ?? 2
                        markdown += "\(String(repeating: "#", count: level)) \(text)\n\n"
                    } else if ["p", "div", "section", "article"].contains(tag) {
                        markdown += "\(text)\n\n"
                    } else if tag == "li" {
                        markdown += "- \(text)\n"
                    }
                }
            }
            
            if !hasContent && debug {
                print("Warning: No content found in document")
                print("Full HTML:")
                print(try document.html())
            }
            
        } catch {
            if debug { print("Error parsing generic supplementary: \(error)") }
            throw error
        }
        
        return markdown
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
        } else if fileName.contains("text_0002") {
            markdown = try convertFootnotesToMarkdown(content)
        } else if fileName.contains("text_0003") {
            markdown = try convertCrossReferencesToMarkdown(content)
        } else if fileName.contains("text_0001") {
            markdown = try convertStudyNotesToMarkdown(content)
        } else if fileName.hasSuffix("text.xhtml") || fileName.contains("text1") {
            markdown = try convertBibleTextToMarkdown(content)
        } else {
            markdown = try convertIntroToMarkdown(content)
        }
        
        guard !markdown.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            if debug { print("Warning: Empty markdown content for \(fileName)") }
            throw ConversionError.emptyContent
        }
        
        let outputURL = URL(fileURLWithPath: outputPath)
            .appendingPathComponent(outputName)
            .appendingPathExtension("md")
        
        try FileManager.default.createDirectory(at: outputURL.deletingLastPathComponent(),
                                             withIntermediateDirectories: true)
        
        try markdown.write(to: outputURL, atomically: true, encoding: .utf8)
        
        if debug { print("Successfully converted \(fileName) to \(outputURL.path)") }
    }
    
    private func convertIntroToMarkdown(_ content: String) throws -> String {
        var markdown = ""
        
        do {
            let document = try SwiftSoup.parse(content)
            
            if let bookSubtitle = try document.select("p.book-subtitle").first(),
               let bookTitle = try document.select("p.book").first() {
                let subtitle = try processElementRecursively(bookSubtitle)
                let title = try processElementRecursively(bookTitle)
                markdown += "# \(subtitle) \(title)\n\n"
            }
            
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
            
            if let titleSection = try document.select("p.ArticleSec").first() {
                let title = try titleSection.text()
                markdown += "# \(title)\n\n"
            }
            
            let outlineElements = try document.select("p[class^=INTRO---Outline]")
            
            for element in outlineElements {
                let className = try element.className()
                let text = try element.text()
                
                let parts = text.components(separatedBy: " ")
                let content = parts.dropFirst().joined(separator: " ")
                
                if className.contains("Teir1") {
                    markdown += "## \(content)\n\n"
                } else if className.contains("tier-2") {
                    markdown += "* \(content)\n"
                } else {
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
            
            let sections = try document.select("p.notesubhead")
            
            for section in sections {
                let chapterTitle = try section.text()
                markdown += "# \(chapterTitle)\n\n"
                
                var currentElement = try section.nextElementSibling()
                
                while let element = currentElement {
                    if element.tagName() == "p" {
                        let className = try element.className()
                        
                        if className == "notesubhead" {
                            break
                        }
                        
                        if className.contains("rsb-studynote") {
                            let noteText = try processStudyNote(element)
                            markdown += noteText
                        }
                    }
                    
                    currentElement = try currentElement?.nextElementSibling()
                }
                
                markdown += "\n---\n\n"
            }
            
        } catch {
            print("Error parsing XHTML: \(error)")
            throw error
        }
        
        return markdown
    }
    
    private func convertFootnotesToMarkdown(_ content: String) throws -> String {
        var markdown = ""
        
        do {
            let document = try SwiftSoup.parse(content)
            let sections = try document.select("p.notesubhead")
            
            for section in sections {
                let chapterTitle = try section.text()
                markdown += "# \(chapterTitle)\n\n"
                
                var currentElement = try section.nextElementSibling()
                
                while let element = currentElement {
                    if element.tagName() == "p" {
                        let className = try element.className()
                        
                        if className == "notesubhead" {
                            break
                        }
                        
                        if className == "note" {
                            let footnoteText = try processFootnote(element)
                            markdown += footnoteText
                        } else if element.hasClass("crossref") {
                            let crossrefText = try processCrossReference(element)
                            markdown += crossrefText
                        }
                    } else if element.tagName() == "aside" {
                        let epubType = try element.attr("epub:type")
                        let id = element.id()
                        
                        if epubType == "footnote" {
                            markdown += "[^\(id)]:"
                            let footnoteContent = try processElementRecursively(element)
                            markdown += " \(footnoteContent)\n\n"
                        }
                    }
                    
                    currentElement = try currentElement?.nextElementSibling()
                }
                
                markdown += "\n---\n\n"
            }
            
        } catch {
            print("Error parsing XHTML: \(error)")
            throw error
        }
        
        return markdown
    }
    
    private func convertCrossReferencesToMarkdown(_ content: String) throws -> String {
        var markdown = ""
        
        do {
            let document = try SwiftSoup.parse(content)
            let sections = try document.select("p.notesubhead")
            
            for section in sections {
                let chapterTitle = try section.text()
                markdown += "# \(chapterTitle)\n\n"
                
                var currentElement = try section.nextElementSibling()
                
                while let element = currentElement {
                    if element.tagName() == "p" {
                        let className = try element.className()
                        
                        if className == "notesubhead" {
                            break
                        }
                        
                        if className == "crossref" {
                            if let verseText = try? element.select("b").first()?.text() {
                                markdown += "## \(verseText)\n\n"
                            }
                        } else if className == "note1" {
                            let reference = try processCrossReference(element)
                            markdown += "- \(reference)\n"
                        }
                    }
                    
                    currentElement = try currentElement?.nextElementSibling()
                }
                
                markdown += "\n---\n\n"
            }
            
        } catch {
            print("Error parsing XHTML: \(error)")
            throw error
        }
        
        return markdown
    }
    
    private func convertBibleTextToMarkdown(_ content: String) throws -> String {
        var markdown = ""
        
        do {
            let document = try SwiftSoup.parse(content)
            let sections = try document.select("section")
            
            for section in sections {
                let theoBoxes = try section.select("div.gbox")
                for box in theoBoxes {
                    if let header = try box.select("p.theohead").first() {
                        let title = try header.text()
                        markdown += "\n## \(title)\n\n"
                    }
                    
                    let theoContent = try box.select("p.theofirst, p.theobody")
                    for para in theoContent {
                        let text = try processElementRecursively(para)
                        markdown += "\(text)\n\n"
                    }
                    markdown += "---\n\n"
                }
                
                if let headingElements = try section.select("p.heading").first() {
                    let heading = try headingElements.text()
                    markdown += "### \(heading)\n\n"
                }
                
                let paragraphs = try section.select("p.p-first, p.p, p.poetrybreak, p.poetry, p.poetry-first, p.poetry-indent, p.poetry-indent-last, p.otpoetry")
                var currentVerseBlock = ""
                
                for paragraph in paragraphs {
                    let paragraphClass = try paragraph.className()
                    
                    if ["poetry", "otpoetry", "poetrybreak", "poetry-first", "poetry-indent", "poetry-indent-last"].contains(paragraphClass) {
                        if !currentVerseBlock.isEmpty {
                            markdown += currentVerseBlock + "\n\n"
                            currentVerseBlock = ""
                        }
                        
                        let poetryContent = try processPoetryVerse(paragraph)
                        let indentLevel = if paragraphClass.contains("indent") { "  " } else { "" }
                        markdown += "\(indentLevel)\(poetryContent)\n\n"
                        continue
                    }
                    
                    for node in paragraph.getChildNodes() {
                        if let textNode = node as? TextNode {
                            currentVerseBlock += textNode.text()
                        } else if let element = node as? Element {
                            if element.hasClass("verse-num") {
                                if !currentVerseBlock.isEmpty {
                                    markdown += currentVerseBlock.trimmingCharacters(in: .whitespacesAndNewlines) + "\n\n"
                                    currentVerseBlock = ""
                                }
                                let verseNum = try element.text()
                                currentVerseBlock = "**\(verseNum)** "
                            } else if element.hasClass("crossref") {
                                let refId = try element.select("a").attr("href")
                                currentVerseBlock += "[†](\(refId))"
                            } else if element.hasClass("note") {
                                let noteId = try element.select("a").attr("href")
                                currentVerseBlock += "[*](\(noteId))"
                            } else if element.tagName() == "small" {
                                currentVerseBlock += "**\(try element.text())**"
                            } else {
                                currentVerseBlock += try element.text()
                            }
                        }
                    }
                }
                
                if !currentVerseBlock.isEmpty {
                    markdown += currentVerseBlock + "\n\n"
                }
                
                if let navLink = try section.select("p.centerr").first() {
                    let link = try navLink.text()
                    markdown += "\n---\n\n➜ \(link)\n\n"
                }
                
                markdown += "---\n\n"
            }
            
        } catch {
            print("Error parsing Bible text XHTML: \(error)")
            throw error
        }
        
        return markdown
    }
    
    private func processPoetryVerse(_ element: Element) throws -> String {
        var verseContent = ""
        
        for node in element.getChildNodes() {
            if let textNode = node as? TextNode {
                verseContent += textNode.text()
            } else if let elementNode = node as? Element {
                if elementNode.hasClass("verse-num") {
                    let verseNum = try elementNode.text()
                    if !verseContent.isEmpty {
                        verseContent += "\n"
                    }
                    verseContent += "**\(verseNum)** "
                } else if elementNode.hasClass("crossref") {
                    let refId = try elementNode.select("a").attr("href")
                    verseContent += "[†](\(refId))"
                } else if elementNode.hasClass("note") {
                    let noteId = try elementNode.select("a").attr("href")
                    verseContent += "[*](\(noteId))"
                } else if elementNode.tagName() == "small" {
                    verseContent += "**\(try elementNode.text())**"
                } else if !["crossref", "note"].contains(try elementNode.className()) {
                    verseContent += try elementNode.text()
                }
            }
        }
        
        return verseContent.split(separator: "\n").map { line in
            "> \(line)"
        }.joined(separator: "\n")
    }
    
    private func processStudyNote(_ element: Element) throws -> String {
        var noteText = ""
        
        if try element.className().contains("studynote-1") {
            noteText += "\n"
        }
        
        let verseRefs = try element.select("span.rsb-studynote-bold")
        if !verseRefs.isEmpty() {
            let reference = try verseRefs.first()?.text() ?? ""
            noteText += "## \(reference)\n\n"
        }
        
        var content = try element.text()
        
        if let firstRef = try element.select("span.rsb-studynote-bold").first() {
            content = content.replacingOccurrences(of: try firstRef.text(), with: "")
        }
        
        content = content.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if !content.isEmpty {
            noteText += "\(content)\n\n"
        }
        
        return noteText
    }
    
    private func processFootnote(_ element: Element) throws -> String {
        var footnoteText = ""
        
        if let noteRef = try element.select("span.note-in-note").first(),
           let link = try noteRef.select("a").first() {
            let refNumber = try link.text()
            footnoteText += "[^\(refNumber)]"
        }
        
        var content = try element.text()
        
        if let firstRef = try element.select("span.note-in-note").first() {
            content = content.replacingOccurrences(of: try firstRef.text(), with: "")
        }
        
        content = content.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if !content.isEmpty {
            footnoteText += " \(content)\n\n"
        }
        
        return footnoteText
    }
    
    private func processCrossReference(_ element: Element) throws -> String {
        var referenceText = ""
        
        if let noteSpan = try element.select("span.note").first(),
           let link = try noteSpan.select("a").first() {
            let refNumber = try link.text()
            referenceText += "(\(refNumber)) "
        }
        
        var content = try element.text()
        
        if let firstRef = try element.select("span.note").first() {
            content = content.replacingOccurrences(of: try firstRef.text(), with: "")
        }
        
        content = content.trimmingCharacters(in: .whitespacesAndNewlines)
        referenceText += content
        
        return referenceText
    }
    
    private func processElementRecursively(_ element: Element) throws -> String {
        var result = ""
        
        for node in element.getChildNodes() {
            if let textNode = node as? TextNode {
                let text = textNode.text().trimmingCharacters(in: .whitespacesAndNewlines)
                if !text.isEmpty {
                    result += text + " "
                }
            } else if let elementNode = node as? Element {
                if ["script", "style", "nav", "header", "footer"].contains(elementNode.tagName()) {
                    continue
                }
                
                let processed = try processInlineFormatting(element: elementNode)
                if !processed.isEmpty {
                    result += processed + " "
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
    
    enum ConversionError: Error {
        case fileNotFound
        case unableToReadFile
        case emptyContent
    }
}
