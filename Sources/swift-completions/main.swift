// import class Foundation.Process
import func POSIX.getenv
import func POSIX.exit
import enum Commands.PackageMode

guard CommandLine.arguments.count >= 4,
      CommandLine.arguments[1] == "swift",
      let line = getenv("COMP_LINE"),
      let point = getenv("COMP_POINT") else {
    exit(1)
}

let currentWord = CommandLine.arguments[2]
let previousWord = CommandLine.arguments[3]

let previousWordCompletions = [
    "swift": ["build", "package", "test"],
    
    "package": PackageMode.arguments,
    "init": ["--type"],
    "--type": ["empty", "library", "executable", "system-module"],
    "generate-xcodeproj": ["--output"],
    "show-dependencies": ["--format"],
    "--format": ["text", "dot", "json"],
    "dump-package": ["--input"],

    "test": ["-s", "--specifier", "-l", "--list-tests"],
]

guard let completions = previousWordCompletions[previousWord] else {
    exit(1)
}

print(completions.filter { $0.hasPrefix(currentWord) }.joined(separator: "\n"))
