import SwiftUI
import WidgetKit

struct CheatSheetWidget: Widget {
    let kind = "CheatSheetWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: CheatSheetProvider()) { entry in
            CheatSheetWidgetView(entry: entry)
        }
        .configurationDisplayName("CheatSheet")
        .description("Keep a pinned coding note on your desktop.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}
