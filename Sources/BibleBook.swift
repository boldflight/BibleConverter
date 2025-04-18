//
//  BibleBook.swift
//  Manuscript
//
//  Created by Douglas Hewitt on 11/22/24.
//

import Foundation

enum Testament: String, CaseIterable {
    case old, new, apocrypha
}

enum BibleBook: String, CaseIterable {
    // MARK: Old Testament
    // Hebrew Bible/Old Testament
    case genesis, exodus, leviticus, numbers, deuteronomy
    case joshua, judges, ruth
    case firstSamuel, secondSamuel
    case firstKings, secondKings
    case firstChronicles, secondChronicles
    case ezra, nehemiah, esther
    case job, psalms, proverbs
    case ecclesiastes, songOfSolomon
    case isaiah, jeremiah, lamentations
    case ezekiel, daniel
    case hosea, joel, amos, obadiah
    case jonah, micah, nahum, habakkuk
    case zephaniah, haggai, zechariah, malachi
    
    // Apocrypha/Deuterocanonical
    case tobit, judith, firstMaccabees, secondMaccabees
    case wisdomOfSolomon, sirach
    case baruch, letterOfJeremiah
    case additionsToEsther, prayerOfAzariah, susanna
    case belAndTheDragon, prayerOfManasseh
    
    // MARK: New Testament
    case matthew, mark, luke, john, acts, romans, firstCorinthians, secondCorinthians, galatians, ephesians, philippians, colossians, firstThessalonians, secondThessalonians, firstTimothy, secondTimothy, titus, philemon, hebrews, james, firstPeter, secondPeter, firstJohn, secondJohn, thirdJohn, jude, revelation
    
    
    var testament: Testament {
        switch self {
        case .matthew, .mark, .luke, .john,
                .acts, .romans,
                .firstCorinthians, .secondCorinthians,
                .galatians, .ephesians, .philippians, .colossians,
                .firstThessalonians, .secondThessalonians,
                .firstTimothy, .secondTimothy,
                .titus, .philemon, .hebrews,
                .james,
                .firstPeter, .secondPeter,
                .firstJohn, .secondJohn, .thirdJohn,
                .jude, .revelation:
            return .new
            
        case .tobit, .judith, .firstMaccabees, .secondMaccabees,
                .wisdomOfSolomon, .sirach,
                .baruch, .letterOfJeremiah,
                .additionsToEsther, .prayerOfAzariah, .susanna,
                .belAndTheDragon, .prayerOfManasseh:
            return .apocrypha
            
        default:
            return .old
        }
    }
    
    var fileName: String {
        switch self {
            // Hebrew Bible/Old Testament
        case .genesis: return "gen"
        case .exodus: return "ex"
        case .leviticus: return "lev"
        case .numbers: return "num"
        case .deuteronomy: return "deut"
        case .joshua: return "josh"
        case .judges: return "judg"
        case .ruth: return "ruth"
        case .firstSamuel: return "1sam"
        case .secondSamuel: return "2sam"
        case .firstKings: return "1kings"
        case .secondKings: return "2kings"
        case .firstChronicles: return "1chron"
        case .secondChronicles: return "2chron"
        case .ezra: return "ezra"
        case .nehemiah: return "neh"
        case .esther: return "est"
        case .job: return "job"
        case .psalms: return "ps"
        case .proverbs: return "prov"
        case .ecclesiastes: return "eccles"
        case .songOfSolomon: return "song"
        case .isaiah: return "isa"
        case .jeremiah: return "jer"
        case .lamentations: return "lam"
        case .ezekiel: return "ezek"
        case .daniel: return "dan"
        case .hosea: return "hos"
        case .joel: return "joel"
        case .amos: return "amos"
        case .obadiah: return "obad"
        case .jonah: return "jonah"
        case .micah: return "mic"
        case .nahum: return "nah"
        case .habakkuk: return "hab"
        case .zephaniah: return "zeph"
        case .haggai: return "hag"
        case .zechariah: return "zech"
        case .malachi: return "mal"
            
            // Apocrypha/Deuterocanonical
        case .tobit: return "tob"
        case .judith: return "jth"
        case .firstMaccabees: return "1macc"
        case .secondMaccabees: return "2macc"
        case .wisdomOfSolomon: return "wisdom"
        case .sirach: return "sir"
        case .baruch: return "bar"
        case .letterOfJeremiah: return "letjer"
        case .additionsToEsther: return "addesth"
        case .prayerOfAzariah: return "praz"
        case .susanna: return "sus"
        case .belAndTheDragon: return "bel"
        case .prayerOfManasseh: return "prman"
            
            // New Testament
        case .matthew: return "matt"
        case .mark: return "mark"
        case .luke: return "luke"
        case .john: return "john"
        case .acts: return "acts"
        case .romans: return "rom"
        case .firstCorinthians: return "1cor"
        case .secondCorinthians: return "2cor"
        case .galatians: return "gal"
        case .ephesians: return "eph"
        case .philippians: return "phil"
        case .colossians: return "col"
        case .firstThessalonians: return "1thess"
        case .secondThessalonians: return "2thess"
        case .firstTimothy: return "1tim"
        case .secondTimothy: return "2tim"
        case .titus: return "titus"
        case .philemon: return "philem"
        case .hebrews: return "heb"
        case .james: return "james"
        case .firstPeter: return "1pet"
        case .secondPeter: return "2pet"
        case .firstJohn: return "1john"
        case .secondJohn: return "2john"
        case .thirdJohn: return "3john"
        case .jude: return "jude"
        case .revelation: return "rev"
        }
    }
    
    var displayName: String {
        switch self {
            // Old Testament special cases
        case .firstSamuel: return "1 Samuel"
        case .secondSamuel: return "2 Samuel"
        case .firstKings: return "1 Kings"
        case .secondKings: return "2 Kings"
        case .firstChronicles: return "1 Chronicles"
        case .secondChronicles: return "2 Chronicles"
        case .songOfSolomon: return "Song of Solomon"
            
            // Apocrypha special cases
        case .firstMaccabees: return "1 Maccabees"
        case .secondMaccabees: return "2 Maccabees"
        case .wisdomOfSolomon: return "Wisdom of Solomon"
        case .letterOfJeremiah: return "Letter of Jeremiah"
        case .additionsToEsther: return "Additions to Esther"
        case .prayerOfAzariah: return "Prayer of Azariah"
        case .belAndTheDragon: return "Bel and the Dragon"
        case .prayerOfManasseh: return "Prayer of Manasseh"
            
            // New Testament special cases
        case .firstCorinthians: return "1 Corinthians"
        case .secondCorinthians: return "2 Corinthians"
        case .firstThessalonians: return "1 Thessalonians"
        case .secondThessalonians: return "2 Thessalonians"
        case .firstTimothy: return "1 Timothy"
        case .secondTimothy: return "2 Timothy"
        case .firstPeter: return "1 Peter"
        case .secondPeter: return "2 Peter"
        case .firstJohn: return "1 John"
        case .secondJohn: return "2 John"
        case .thirdJohn: return "3 John"
            
        default: return rawValue.capitalized
        }
    }
    
    var canonicalOrder: Int {
        switch self {
            // Old Testament (1-39)
        case .genesis: return 1
        case .exodus: return 2
        case .leviticus: return 3
        case .numbers: return 4
        case .deuteronomy: return 5
        case .joshua: return 6
        case .judges: return 7
        case .ruth: return 8
        case .firstSamuel: return 9
        case .secondSamuel: return 10
        case .firstKings: return 11
        case .secondKings: return 12
        case .firstChronicles: return 13
        case .secondChronicles: return 14
        case .ezra: return 15
        case .nehemiah: return 16
        case .esther: return 17
        case .job: return 18
        case .psalms: return 19
        case .proverbs: return 20
        case .ecclesiastes: return 21
        case .songOfSolomon: return 22
        case .isaiah: return 23
        case .jeremiah: return 24
        case .lamentations: return 25
        case .ezekiel: return 26
        case .daniel: return 27
        case .hosea: return 28
        case .joel: return 29
        case .amos: return 30
        case .obadiah: return 31
        case .jonah: return 32
        case .micah: return 33
        case .nahum: return 34
        case .habakkuk: return 35
        case .zephaniah: return 36
        case .haggai: return 37
        case .zechariah: return 38
        case .malachi: return 39
            
            // New Testament (40-66)
        case .matthew: return 40
        case .mark: return 41
        case .luke: return 42
        case .john: return 43
        case .acts: return 44
        case .romans: return 45
        case .firstCorinthians: return 46
        case .secondCorinthians: return 47
        case .galatians: return 48
        case .ephesians: return 49
        case .philippians: return 50
        case .colossians: return 51
        case .firstThessalonians: return 52
        case .secondThessalonians: return 53
        case .firstTimothy: return 54
        case .secondTimothy: return 55
        case .titus: return 56
        case .philemon: return 57
        case .hebrews: return 58
        case .james: return 59
        case .firstPeter: return 60
        case .secondPeter: return 61
        case .firstJohn: return 62
        case .secondJohn: return 63
        case .thirdJohn: return 64
        case .jude: return 65
        case .revelation: return 66
            
            // Apocrypha (67+)
        case .tobit: return 67
        case .judith: return 68
        case .firstMaccabees: return 69
        case .secondMaccabees: return 70
        case .wisdomOfSolomon: return 71
        case .sirach: return 72
        case .baruch: return 73
        case .letterOfJeremiah: return 74
        case .additionsToEsther: return 75
        case .prayerOfAzariah: return 76
        case .susanna: return 77
        case .belAndTheDragon: return 78
        case .prayerOfManasseh: return 79
        }
    }
    
    static func from(_ name: String) -> BibleBook? {
        let normalized = name.lowercased().trimmingCharacters(in: .whitespaces)
        
        return BibleBook.allCases.first { book in
            book.displayName.lowercased() == normalized ||
            book.abbreviations.contains(where: { $0.lowercased() == normalized })
        }
    }
    
    var abbreviations: [String] {
        // Start with fileName as first abbreviation
        var abbrevs = [fileName]
        
        switch self {
            // Hebrew Bible/Old Testament
        case .genesis: abbrevs += ["gn", "gen"]
        case .exodus: abbrevs += ["exo", "exod"]
        case .leviticus: abbrevs += ["lv", "lev", "levi"]
        case .numbers: abbrevs += ["nm", "num"]
        case .deuteronomy: abbrevs += ["dt", "deut"]
        case .joshua: abbrevs += ["jos", "josh"]
        case .judges: abbrevs += ["jdg", "jud", "jgs"]
        case .ruth: abbrevs += ["ru", "rth"]
        case .firstSamuel: abbrevs += ["1 sam", "1sam", "1 sa", "1sm"]
        case .secondSamuel: abbrevs += ["2 sam", "2sam", "2 sa", "2sm"]
        case .firstKings: abbrevs += ["1 kgs", "1kgs", "1 ki"]
        case .secondKings: abbrevs += ["2 kgs", "2kgs", "2 ki"]
        case .firstChronicles: abbrevs += ["1 chr", "1chr", "1 ch"]
        case .secondChronicles: abbrevs += ["2 chr", "2chr", "2 ch"]
        case .ezra: abbrevs += ["ez", "ezr"]
        case .nehemiah: abbrevs += ["ne", "neh"]
        case .esther: abbrevs += ["est", "esth"]
        case .job: abbrevs += ["jb"]
        case .psalms: abbrevs += ["psa", "ps", "psalm"]
        case .proverbs: abbrevs += ["prv", "pro"]
        case .ecclesiastes: abbrevs += ["ecc", "qoh", "eccl"]
        case .songOfSolomon: abbrevs += ["song", "sos", "cant", "sg"]
        case .isaiah: abbrevs += ["is", "isa"]
        case .jeremiah: abbrevs += ["jer", "jr"]
        case .lamentations: abbrevs += ["lam", "lm"]
        case .ezekiel: abbrevs += ["ez", "ezk"]
        case .daniel: abbrevs += ["dan", "dn"]
        case .hosea: abbrevs += ["hos", "ho"]
        case .joel: abbrevs += ["jl", "joel"]
        case .amos: abbrevs += ["am"]
        case .obadiah: abbrevs += ["ob", "oba"]
        case .jonah: abbrevs += ["jon", "jnh"]
        case .micah: abbrevs += ["mic", "mc", "mi"]
        case .nahum: abbrevs += ["nah", "na"]
        case .habakkuk: abbrevs += ["hab", "hb"]
        case .zephaniah: abbrevs += ["zep", "zph"]
        case .haggai: abbrevs += ["hag", "hg"]
        case .zechariah: abbrevs += ["zech", "zec", "ze"]
        case .malachi: abbrevs += ["mal", "ml"]
            
            // New Testament
        case .matthew: abbrevs += ["mt", "matt"]
        case .mark: abbrevs += ["mk", "mrk"]
        case .luke: abbrevs += ["lk", "luk"]
        case .john: abbrevs += ["jn", "jhn"]
        case .acts: abbrevs += ["ac", "act", "acts"]
        case .romans: abbrevs += ["rom", "rm"]
        case .firstCorinthians: abbrevs += ["1 cor", "1cor", "1 co"]
        case .secondCorinthians: abbrevs += ["2 cor", "2cor", "2 co"]
        case .galatians: abbrevs += ["gal", "ga"]
        case .ephesians: abbrevs += ["eph", "ep"]
        case .philippians: abbrevs += ["phil", "php"]
        case .colossians: abbrevs += ["col", "co"]
        case .firstThessalonians: abbrevs += ["1 thess", "1thess", "1thes", "1 th"]
        case .secondThessalonians: abbrevs += ["2 thess", "2thess", "2thes", "2 th"]
        case .firstTimothy: abbrevs += ["1 tim", "1tim", "1 ti", "1tm"]
        case .secondTimothy: abbrevs += ["2 tim", "2tim", "2 ti", "2tm"]
        case .titus: abbrevs += ["tit", "ti"]
        case .philemon: abbrevs += ["phm", "phlm"]
        case .hebrews: abbrevs += ["heb", "he"]
        case .james: abbrevs += ["jas", "jm"]
        case .firstPeter: abbrevs += ["1 pet", "1pet", "1 pe", "1pt"]
        case .secondPeter: abbrevs += ["2 pet", "2pet", "2 pe", "2pt"]
        case .firstJohn: abbrevs += ["1 jn", "1jn", "1 jo"]
        case .secondJohn: abbrevs += ["2 jn", "2jn", "2 jo"]
        case .thirdJohn: abbrevs += ["3 jn", "3jn", "3 jo"]
        case .jude: abbrevs += ["jud", "jd"]
        case .revelation: abbrevs += ["rev", "re", "rv"]
            
            // Apocryphal/Deuterocanonical books
        case .tobit: abbrevs += ["tb", "tob"]
        case .judith: abbrevs += ["jdt", "jth"]
        case .firstMaccabees: abbrevs += ["1 macc", "1macc", "1 mac"]
        case .secondMaccabees: abbrevs += ["2 macc", "2macc", "2 mac"]
        case .wisdomOfSolomon: abbrevs += ["wis", "ws", "wisd"]
        case .sirach: abbrevs += ["sir", "sira", "ecclus"] // ecclus is traditional abbreviation for Ecclesiasticus
        case .baruch: abbrevs += ["bar", "ba"]
        case .letterOfJeremiah: abbrevs += ["let jer", "letjer", "lje", "epjer"]
        case .additionsToEsther: abbrevs += ["add esth", "addesth", "ades"]
        case .prayerOfAzariah: abbrevs += ["pr az", "praz", "sof"] // sometimes called Song of the Three
        case .susanna: abbrevs += ["sus", "su"]
        case .belAndTheDragon: abbrevs += ["bel", "beldrag"]
        case .prayerOfManasseh: abbrevs += ["pr man", "prman", "man"]
        }
        
        return abbrevs
    }
    
    var chapterCount: Int {
        switch self {
        // Old Testament
        case .genesis: return 50
        case .exodus: return 40
        case .leviticus: return 27
        case .numbers: return 36
        case .deuteronomy: return 34
        case .joshua: return 24
        case .judges: return 21
        case .ruth: return 4
        case .firstSamuel: return 31
        case .secondSamuel: return 24
        case .firstKings: return 22
        case .secondKings: return 25
        case .firstChronicles: return 29
        case .secondChronicles: return 36
        case .ezra: return 10
        case .nehemiah: return 13
        case .esther: return 10
        case .job: return 42
        case .psalms: return 150
        case .proverbs: return 31
        case .ecclesiastes: return 12
        case .songOfSolomon: return 8
        case .isaiah: return 66
        case .jeremiah: return 52
        case .lamentations: return 5
        case .ezekiel: return 48
        case .daniel: return 12
        case .hosea: return 14
        case .joel: return 3
        case .amos: return 9
        case .obadiah: return 1
        case .jonah: return 4
        case .micah: return 7
        case .nahum: return 3
        case .habakkuk: return 3
        case .zephaniah: return 3
        case .haggai: return 2
        case .zechariah: return 14
        case .malachi: return 4
            
        // New Testament
        case .matthew: return 28
        case .mark: return 16
        case .luke: return 24
        case .john: return 21
        case .acts: return 28
        case .romans: return 16
        case .firstCorinthians: return 16
        case .secondCorinthians: return 13
        case .galatians: return 6
        case .ephesians: return 6
        case .philippians: return 4
        case .colossians: return 4
        case .firstThessalonians: return 5
        case .secondThessalonians: return 3
        case .firstTimothy: return 6
        case .secondTimothy: return 4
        case .titus: return 3
        case .philemon: return 1
        case .hebrews: return 13
        case .james: return 5
        case .firstPeter: return 5
        case .secondPeter: return 3
        case .firstJohn: return 5
        case .secondJohn: return 1
        case .thirdJohn: return 1
        case .jude: return 1
        case .revelation: return 22
            
        // Apocrypha
        case .tobit: return 14
        case .judith: return 16
        case .firstMaccabees: return 16
        case .secondMaccabees: return 15
        case .wisdomOfSolomon: return 19
        case .sirach: return 51
        case .baruch: return 6
        case .letterOfJeremiah: return 1
        case .additionsToEsther: return 7
        case .prayerOfAzariah: return 1
        case .susanna: return 1
        case .belAndTheDragon: return 1
        case .prayerOfManasseh: return 1
        }
    }
}
