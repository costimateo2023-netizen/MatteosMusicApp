import Foundation
import SwiftUI

extension Color {
    static let msBackground = Color(red: 0.07, green: 0.07, blue: 0.10)
    static let msCard = Color(red: 0.12, green: 0.12, blue: 0.18)
    static let msAccent = Color(red: 0.4, green: 0.6, blue: 1.0)
    static let msSecondary = Color(red: 0.6, green: 0.6, blue: 0.7)
}

extension TimeInterval {
    var formattedMMSS: String {
        let m = Int(self) / 60
        let s = Int(self) % 60
        return String(format: "%d:%02d", m, s)
    }
}
