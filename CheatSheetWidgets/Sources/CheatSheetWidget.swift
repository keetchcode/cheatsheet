import SwiftUI
import WidgetKit

struct CheatSheetWidget: Widget {
    let kind = "CheatSheetWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: CheatSheetProvider()) { entry in
            CheatSheetWidgetView(entry: entry)
        }
        .configurationDisplayName("CheatSheet")
        .description("100% free and open source. Keep a pinned coding note on your desktop.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}
