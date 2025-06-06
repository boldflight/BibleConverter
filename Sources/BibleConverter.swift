import Foundation
import ArgumentParser
import SwiftSoup

struct BibleConverter: ParsableCommand {
    static let configuration = CommandConfiguration(
            commandName: "bibleconverter",
            abstract: "Convert Bible EPUB to Markdown files",
            discussion: """
            This tool has four modes:

            1. Convert EPUB to Markdown:
               bibleconverter convert <epub-path> <output-path>

            2. Rename existing Markdown files:
               bibleconverter rename <directory> <translation>
               
            3. Convert simple HTML to Markdown:
               bibleconverter convert-sample <html-path> <output-path>
               
            4. Convert ESV Study Bible content:
               bibleconverter convert-study <input-path> <output-path>
            """,
            subcommands: [
                ConvertCommand.self,
                RenameCommand.self,
                ConvertSampleCommand.self,
                ConvertStudyBibleCommand.self
            ]
        )
    
    mutating func run() throws {
        print(Self.helpMessage())
    }
}
