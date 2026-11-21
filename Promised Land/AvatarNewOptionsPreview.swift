import SwiftUI

#Preview("New avatar options") {
    HStack(spacing: 18) {
        AvatarView(config: {
            var config = AvatarSexRules.defaults(for: .female)
            config.hair = .braid
            return config
        }())
        .frame(width: 80, height: 128)

        AvatarView(config: {
            var config = AvatarSexRules.defaults(for: .female)
            config.hair = .bun
            return config
        }())
        .frame(width: 80, height: 128)

        AvatarView(config: {
            var config = AvatarSexRules.defaults(for: .female)
            config.head = .queenCrown
            return config
        }())
        .frame(width: 80, height: 128)
    }
    .padding()
    .background(Color.cream)
}
