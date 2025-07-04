# PDColorKit

PDColorKit is a Swift package for analyzing colors in images. It includes utilities for computing an image's average color, finding dominant colors, and generating corrected colors suitable for use in SwiftUI.

## Features
- Cross platform support for iOS, macOS, tvOS, and watchOS
- Average color calculation
- Dominant color detection with configurable grid size
- SwiftUI helper to obtain a color corrected for minimum saturation

## Usage
Add `PDColorKit` as a dependency in your Swift Package Manager manifest:

```swift
.package(url: "https://github.com/your-org/PDColorKit.git", from: "0.1.x")
```

Import the library and call the image extensions:

```swift
import PDColorKit

let image: CrossPlatformImage = ...
let avgColor = image.averageColor()
let uiColor = image.generateCorrectedColor()
```

## Apps Using

<p float="left">
    <a href="https://apps.apple.com/jp/app/tweetpd/id1671411031"><img src="https://i.imgur.com/AC6eGdx.png" width="65" height="65"></a>
</p>

## License

This project is released under the MIT License. See [LICENSE](LICENSE) for details.
