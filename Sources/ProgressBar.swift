import Foundation

struct ProgressBar {
    var current = 0 {
        didSet {
            if current > total {
                current = total
            }
        }
    }
    var total = 0
    private let width = 40
    
    mutating func draw() {
        let percent = Double(current) / Double(total)
        let filled = Int(Double(width) * percent)
        let empty = width - filled
        
        let bar = String(repeating: "█", count: filled) +
                  String(repeating: "░", count: empty)
        
        print("\r[", terminator: "")
        print(bar, terminator: "")
        print("] \(Int(percent * 100))%", terminator: "")
        fflush(stdout)
    }
}
