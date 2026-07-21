import Foundation

@main
struct CareerCommandCenterEntry {
    @MainActor
    static func main() {
        let arguments = Array(CommandLine.arguments.dropFirst())
        if arguments.first == "--scheduled-run" {
            CareerCommandCenterScheduledRunner.run(arguments: Array(arguments.dropFirst()))
            return
        }
        CareerCommandCenterApp.main()
    }
}
