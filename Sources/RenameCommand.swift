import Foundation
import ArgumentParser

struct RenameCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "rename",
        abstract: "Rename markdown files by adding a translation suffix",
        discussion: """
        Example: bibleconverter rename ./output net
        This will rename all markdown files in ./output directory by adding '_net' suffix.
        """
    )
    
    @Argument(help: "Directory containing markdown files")
    var directory: String
    
    @Argument(help: "Translation suffix (Example: net, drc)")
    var translation: String
    
    mutating func run() throws {
        let fileManager = FileManager.default
        let dirURL = URL(fileURLWithPath: directory)
        
        let files = try fileManager.contentsOfDirectory(at: dirURL,
                                                       includingPropertiesForKeys: nil,
                                                       options: .skipsHiddenFiles)
        
        for fileURL in files where fileURL.pathExtension == "md" {
            let newName = fileURL.deletingPathExtension().lastPathComponent + "_" + translation + ".md"
            let newURL = dirURL.appendingPathComponent(newName)
            
            try fileManager.moveItem(at: fileURL, to: newURL)
            print("Renamed: \(fileURL.lastPathComponent) -> \(newName)")
        }
    }
}
