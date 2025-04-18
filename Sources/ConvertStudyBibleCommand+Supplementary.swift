import Foundation
import SwiftSoup

extension ConvertStudyBibleCommand {

    // MARK: ‑ Public entry point
    func convertSupplementaryFile(named filename: String, type: SupplementaryType) throws {
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
        
        let hasImage = try SwiftSoup.parse(content)
            .select("img[src]")
            .first() != nil
        
        let trimmedMarkdown = markdown.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if !hasImage && trimmedMarkdown.isEmpty {
            if debug {
                print("Warning: Empty markdown content for \(filename)")
                print("Content type: \(type)")
                print("Raw content sample:")
                print(content.prefix(ConvertStudyBibleCommand.debugLimit))
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

    // MARK: ‑ Individual supplementary converters
    func convertConcordanceToMarkdown(_ content: String) throws -> String {
        var markdown = ""
        
        do {
            let document = try SwiftSoup.parse(content)
            
            if debug {
                if let body = try document.select("body").first() {
                    let elementKey = "\(body.tagName())-\(try body.className())"
                    if !ConvertStudyBibleCommand.seenElements.contains(elementKey) {
                        print("\nParsing concordance content...")
                        print("Document structure:")
                        print(try body.html().prefix(ConvertStudyBibleCommand.debugLimit))
                        ConvertStudyBibleCommand.seenElements.insert(elementKey)
                    }
                }
            }
            
            let entries = try document.select("div.concordance-entry, div.entry, p.concordance, p.concordanceentry, p.entry, .concordance-item")
            
            if entries.isEmpty() && debug {
                let elementKey = "concordance-entries-empty"
                if !ConvertStudyBibleCommand.seenElements.contains(elementKey) {
                    print("No entries found with standard concordance classes")
                    ConvertStudyBibleCommand.seenElements.insert(elementKey)
                }
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
                        let elementKey = "\(tag)-\(className)"
                        if !ConvertStudyBibleCommand.seenElements.contains(elementKey) {
                            print("Processing element: \(tag) with class: \(className)")
                            ConvertStudyBibleCommand.seenElements.insert(elementKey)
                        }                    }
                    
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
                print(try document.select("body").first()?.html().prefix(ConvertStudyBibleCommand.debugLimit) ?? "No body found")
            }
            
        } catch {
            if debug { print("Error parsing concordance: \(error)") }
            throw error
        }
        
        return markdown
    }

    func convertMapToMarkdown(_ content: String) throws -> String {
        var markdown = ""
        
        do {
            let document = try SwiftSoup.parse(content)
            
            if debug {
                if let body = try document.select("body").first() {
                    let elementKey = "\(body.tagName())-\(try body.className())"
                    if !ConvertStudyBibleCommand.seenElements.contains(elementKey) {
                        print("\nParsing map content...")
                        print("Document structure:")
                        print(try body.html().prefix(ConvertStudyBibleCommand.debugLimit))
                        ConvertStudyBibleCommand.seenElements.insert(elementKey)
                    }
                }
            }
            
            let elements = try document.select("body *")
            var hasContent = false
            
            for element in elements {
                let tag = element.tagName()
                let className = try element.className()
                let text = try element.text().trimmingCharacters(in: .whitespacesAndNewlines)
                
                if debug {
                    let elementKey = "\(tag)-\(className)"
                    if !ConvertStudyBibleCommand.seenElements.contains(elementKey) {
                        print("Processing element: \(tag) with class: \(className)")
                        ConvertStudyBibleCommand.seenElements.insert(elementKey)
                    }
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
                let warningKey = "no-content-warning-map"
                if !ConvertStudyBibleCommand.seenElements.contains(warningKey) {
                    print("Warning: No content found in map document")
                    print("Full HTML:")
                    print(try document.html().prefix(ConvertStudyBibleCommand.debugLimit))
                    ConvertStudyBibleCommand.seenElements.insert(warningKey)
                }
            }
            
        } catch {
            if debug { print("Error parsing map: \(error)") }
            throw error
        }
        
        return markdown
    }

    func convertTopicalToMarkdown(_ content: String) throws -> String {
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

    func convertArticleToMarkdown(_ content: String) throws -> String {
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

    func convertGenericSupplementaryToMarkdown(_ content: String) throws -> String {
        var markdown = ""
        
        do {
            let document = try SwiftSoup.parse(content)
            
            if debug {
                if let body = try document.select("body").first() {
                    let elementKey = "\(body.tagName())-\(try body.className())"
                    if !ConvertStudyBibleCommand.seenElements.contains(elementKey) {
                        print("\nParsing generic supplementary content...")
                        print("Document structure:")
                        print(try body.html().prefix(ConvertStudyBibleCommand.debugLimit))
                        ConvertStudyBibleCommand.seenElements.insert(elementKey)
                    }
                }
            }
            
            if let section = try document.select("section[title]").first() {
                let title = try section.attr("title")
                markdown += "# \(title)\n\n"
            }
            
            let elements = try document.select("body *")
            var hasContent = false
            var hasValidImage = false
            
            for element in elements {
                let tag = element.tagName()
                let className = try element.className()
                
                if debug {
                    let elementKey = "\(tag)-\(className)"
                    if !ConvertStudyBibleCommand.seenElements.contains(elementKey) {
                        print("Processing new element type: \(tag) with class: \(className)")
                        ConvertStudyBibleCommand.seenElements.insert(elementKey)
                    }
                }
                
                if tag == "img" {
                    let src = try element.attr("src")
                    if !src.isEmpty {
                        hasValidImage = true
                        let alt = try element.attr("alt")
                        markdown += "![Image: \(alt)](\(src))\n\n"
                    }
                    continue
                }
                
                if tag == "figcaption" {
                    hasContent = true
                    let caption = try element.text().trimmingCharacters(in: .whitespacesAndNewlines)
                    if !caption.isEmpty {
                        markdown += "_\(caption)_\n\n"
                    }
                    continue
                }
                
                if className.hasPrefix("INTRO---Outline") {
                    hasContent = true
                    let text = try element.text().trimmingCharacters(in: .whitespacesAndNewlines)
                    if !text.isEmpty {
                        if className.contains("Teir1") || className.contains("Tier1") {
                            markdown += "## \(text)\n\n"
                        } else if className.contains("tier-2") {
                            markdown += "* \(text)\n"
                        } else {
                            markdown += "  * \(text)\n"
                        }
                    }
                    continue
                }
                
                let text = try processElementRecursively(element)
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
            
            hasContent = hasContent || hasValidImage
            
            if !hasContent && debug {
                let warningKey = "no-content-warning-supplementary"
                if !ConvertStudyBibleCommand.seenElements.contains(warningKey) {
                    print("Warning: No content found in document")
                    print("Full HTML:")
                    print(try document.html().prefix(ConvertStudyBibleCommand.debugLimit))
                    ConvertStudyBibleCommand.seenElements.insert(warningKey)
                }
            }
            
        } catch {
            if debug { print("Error parsing generic supplementary: \(error)") }
            throw error
        }
        
        return markdown
    }
}
