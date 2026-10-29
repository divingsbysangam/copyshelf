import CopyShelfCore
import Foundation

struct FakeClock: CaptureClock {
    var date = Date(timeIntervalSince1970: 0)
    func now() -> Date { date }
}
