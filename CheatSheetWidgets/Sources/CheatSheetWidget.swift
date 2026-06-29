import SwiftUI
import WidgetKit

struct CheatSheetWidget: Widget {
    let kind = "CheatSheetWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: CheatSheetProvider()) { entry in
            CheatSheetWidgetView(entry: entry)
        }
        .configurationDisplayName("CheatSheet")
        .description("100% free and open source. Keep a pinned coding note nearby.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}
