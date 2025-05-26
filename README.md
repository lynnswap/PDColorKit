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
.package(url: "https://github.com/your-org/PDColorKit.git", from: "1.0.0")
```

Import the library and call the image extensions:

```swift
import PDColorKit

let image: CrossPlatformImage = ...
let avgColor = image.averageColor()
let uiColor = image.generateCorrectedColor()
```

## License
This project is available under the MIT License. See [LICENSE](LICENSE) for details.
