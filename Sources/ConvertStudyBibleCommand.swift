import Foundation
import ArgumentParser
import SwiftSoup

struct ConvertStudyBibleCommand: ParsableCommand {
    enum ConversionError: Error {
        case fileNotFound
        case unableToReadFile
        case emptyContent
    }
    
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
    
    static let ignoredFiles: Set<String> = [
        "nav.xhtml",
        "toc.xhtml",
        "toc.ncx",
        "content.opf",
        "cover.xhtml",
        "styles"
    ]
    
    static let outputDirectories: [String] = [
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
    
    static let debugLimit = 100
    
    nonisolated(unsafe) static var seenElements: Set<String> = []
    
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
            
            let baseFilename = filename.replacingOccurrences(of: ".xhtml", with: "")
            let fileCode = baseFilename
                .replacingOccurrences(of: "(text|intro|outline).*$", with: "", options: [.regularExpression, .caseInsensitive])
                .replacingOccurrences(of: "_", with: "")
                .lowercased()
                .trimmingCharacters(in: .whitespaces)
            
            if debug { print("Processing file: \(filename) with code: \(fileCode)") }
            
            guard let book = BibleBook.from(fileCode),
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
}
