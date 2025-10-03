## Product context
CMD is a MacOS app that provides coding assistance to developpers who use Xcode. The app works as a sidebar that can see what is in Xcode, and modify files or take actions in Xcode.

## Tech design
The MacOS app is built mostly with Swift 6 / SwiftUI. It embedes a local typescript server that is used interact with 3rd parties libraries not available in Swift. By far, most of the code is written in the Swift app.

## Contribution guideline
- Make sure to write meaningful tests whenever relevant but don't write tests that are straightforward (ex: testing a default value). Verify that those new tests pass.
- Make sure to verify that the code compiles.
- Respect the existing modularization structure.

## App
When modifying files in `./app` be sure to first read `./app/Claude.md`
