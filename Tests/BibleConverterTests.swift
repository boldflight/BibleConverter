import Testing
import Foundation
@testable import BibleConverter

@Suite("Bible Converter Tests")
struct BibleConverterTests {
    let converter = ConvertCommand()
    
    // Test conversion of a single verse
    @Test("Convert single verse")
    func testConvertSingleVerse() async throws {
        let input = """
        <?xml version="1.0" encoding="utf-8"?>
        <html>
        <body>
            <h1>Genesis Chapter 1</h1>
            <p class="bodytext">1:1 In the beginning God created the heaven and the earth.</p>
        </body>
        </html>
        """
            
        let (bookName, markdown) = try converter.convertToMarkdown(input)
        
        #expect(bookName == "Genesis")
        #expect(markdown.contains("# Genesis"))
        #expect(markdown.contains("## Chapter 1"))
        #expect(markdown.contains("[1] In the beginning God created the heaven and the earth."))
    }
    
    // Test poetry formatting
    @Test("Convert poetry formatting")
    func testConvertPoetry() async throws {
        let input = """
        <?xml version="1.0" encoding="utf-8"?>
        <html>
        <body>
            <h1>Psalms Chapter 1</h1>
            <p class="poetry">
                <span class="verse">1:1</span> Blessed is the man
                that walketh not in the counsel of the ungodly,
            </p>
        </body>
        </html>
        """
        
        let (bookName, markdown) = try converter.convertToMarkdown(input)
        
        #expect(bookName == "Psalms")
        #expect(markdown.contains("[1] Blessed is the man"))
        #expect(markdown.contains("that walketh not in the counsel of the ungodly"))
    }
    
    // Test chapter headers
    @Test("Handle chapter headers")
    func testChapterHeaders() async throws {
        let input = """
        <?xml version="1.0" encoding="utf-8"?>
        <html>
        <body>
            <h1>Exodus Chapter 20</h1>
            <p class="paragraphtitle">The Ten Commandments</p>
            <p class="bodytext">20:1 And God spake all these words, saying,</p>
        </body>
        </html>
        """
        
        let (bookName, markdown) = try converter.convertToMarkdown(input)
        
        #expect(bookName == "Exodus")
        #expect(markdown.contains("## Chapter 20"))
        #expect(markdown.contains("### The Ten Commandments"))
    }
    
    // Test multiple verses
    @Test("Handle multiple verses")
    func testMultipleVerses() async throws {
        let input = """
        <?xml version="1.0" encoding="utf-8"?>
        <html>
        <body>
            <h1>John Chapter 3</h1>
            <p class="bodytext">3:16 For God so loved the world, 3:17 For God sent not his Son into the world to condemn the world.</p>
        </body>
        </html>
        """
        
        let (bookName, markdown) = try converter.convertToMarkdown(input)
        
        #expect(bookName == "John")
        #expect(markdown.contains("[16] For God so loved the world"))
        #expect(markdown.contains("[17] For God sent not his Son into the world to condemn the world"))
    }
    
    // Test file operations
    @Test("File operations")
    func testFileOperations() async throws {
        // Create a temporary directory for testing
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true, attributes: nil)
        defer { try? FileManager.default.removeItem(at: tempDir) }
        
        // Create test EPUB structure
        let oebpsDir = tempDir.appendingPathComponent("OEBPS")
        try FileManager.default.createDirectory(at: oebpsDir, withIntermediateDirectories: true, attributes: nil)
        
        // Create minimal test content
        let content = """
        <?xml version="1.0" encoding="utf-8"?>
        <html>
        <body>
            <h1>Genesis Chapter 1</h1>
            <p class="bodytext">1:1 Test verse.</p>
        </body>
        </html>
        """
        
        try content.write(to: oebpsDir.appendingPathComponent("content.xhtml"), atomically: true, encoding: .utf8)
        
        // Test file existence check
        #expect(FileManager.default.fileExists(atPath: oebpsDir.appendingPathComponent("content.xhtml").path))
    }
    
    // Add new test for SMCAPS handling
    @Test("Handle SMCAPS formatting")
    func testSmallCapsFormatting() async throws {
        let input = """
        <?xml version="1.0" encoding="utf-8"?>
        <html>
        <body>
            <h1>Zephaniah Chapter 1</h1>
            <p class="bodytext">
                <span class="verse">1:1</span> This is the <span class="smcaps">Lord'</span>s message.
            </p>
            <p class="poetry">
                <span class="verse">1:2</span> "I will destroy everything," says the <span class="smcaps">Lord</span>.
            </p>
        </body>
        </html>
        """
        
        let (bookName, markdown) = try converter.convertToMarkdown(input)
        
        #expect(bookName == "Zephaniah")
        #expect(markdown.contains("[1] This is the Lord's message"))
        #expect(markdown.contains("[2] \"I will destroy everything,\" says the Lord"))
        
        // Ensure no raw HTML tags are present
        #expect(!markdown.contains("<span"))
        #expect(!markdown.contains("class=\"smcaps\""))
        
        // Ensure no duplicate lines
        let lines = markdown.components(separatedBy: .newlines)
        let verseLines = lines.filter { $0.starts(with: "[") }
        #expect(verseLines.count == 2)
    }
    
    @Test("Handle multiple paragraph titles")
    func testMultipleParagraphTitles() async throws {
        let input = """
        <?xml version="1.0" encoding="utf-8"?>
        <html>
        <body>
            <h1>Zephaniah Chapter 1</h1>
            <p class="paragraphtitle">Introduction</p>
            <p class="bodytext"><span class="verse">1:1</span> This is the first verse.</p>
            <p class="paragraphtitle">The Lord's Day of Judgment is Approaching</p>
            <p class="poetry"><span class="verse">1:2</span> This is the second verse.</p>
        </body>
        </html>
        """
        
        let (bookName, markdown) = try converter.convertToMarkdown(input)
        
        #expect(bookName == "Zephaniah")
        #expect(markdown.contains("### Introduction"))
        #expect(markdown.contains("[1] This is the first verse"))
        #expect(markdown.contains("### The Lord's Day of Judgment is Approaching"))
        #expect(markdown.contains("[2] This is the second verse"))
        
        // Verify order
        let lines = markdown.components(separatedBy: .newlines)
        let introIndex = lines.firstIndex(where: { $0.contains("Introduction") }) ?? 0
        let verse1Index = lines.firstIndex(where: { $0.contains("[1]") }) ?? 0
        let judgmentIndex = lines.firstIndex(where: { $0.contains("Judgment") }) ?? 0
        let verse2Index = lines.firstIndex(where: { $0.contains("[2]") }) ?? 0
        
        #expect(introIndex < verse1Index)
        #expect(verse1Index < judgmentIndex)
        #expect(judgmentIndex < verse2Index)
    }
    
    @Test("Handle Song of Solomon speaker annotations")
    func testSongOfSolomonSpeakers() async throws {
        let input = """
        <?xml version="1.0" encoding="utf-8"?>
        <html>
        <body>
            <h1>Song of Solomon Chapter 1</h1>
            <p class="paragraphtitle">The Desire for Love</p>
            <p class="sosspeaker">The Beloved to Her Lover:</p>
            <p class="poetry"><span class="verse">1:2</span> Oh, how I wish you would kiss me passionately!</p>
            <p class="sosspeaker">The Maidens to the Lover:</p>
            <p class="poetry">We will rejoice and delight in you;</p>
        </body>
        </html>
        """
        
        let (bookName, markdown) = try converter.convertToMarkdown(input)
        
        #expect(bookName == "Song of Solomon")
        #expect(markdown.contains("### The Desire for Love"))
        #expect(markdown.contains("_The Beloved to Her Lover:_"))
        #expect(markdown.contains("[2] Oh, how I wish you would kiss me passionately!"))
        #expect(markdown.contains("_The Maidens to the Lover:_"))
        #expect(markdown.contains("We will rejoice and delight in you;"))
        
        // Verify order
        let lines = markdown.components(separatedBy: .newlines)
        let titleIndex = lines.firstIndex(where: { $0.contains("The Desire for Love") }) ?? 0
        let speaker1Index = lines.firstIndex(where: { $0.contains("The Beloved to Her Lover") }) ?? 0
        let verse2Index = lines.firstIndex(where: { $0.contains("[2]") }) ?? 0
        
        #expect(titleIndex < speaker1Index)
        #expect(speaker1Index < verse2Index)
    }
}
