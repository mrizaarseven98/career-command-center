import Foundation

@main
struct CareerCommandCenterScheduledRunnerMain {
    static func main() {
        CareerCommandCenterScheduledRunner.run(arguments: Array(CommandLine.arguments.dropFirst()))
    }
}
