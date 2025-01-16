import Foundation
import ArgumentParser
import SwiftSoup

struct BibleConverter: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "bibleconverter",
        abstract: "Convert Bible EPUB to Markdown files",
        discussion: """
        This tool has two modes:

        1. Convert EPUB to Markdown:
           bibleconverter convert <epub-path> <output-path>

        2. Rename existing Markdown files:
           bibleconverter rename <directory> <translation>
        """,
        subcommands: [ConvertCommand.self, RenameCommand.self]
    )
    
    mutating func run() throws {
        print(Self.helpMessage())
    }
    
}
