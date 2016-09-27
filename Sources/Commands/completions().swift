import func POSIX.getenv

public func completions(command: String, currentWord: String, previousWord: String) -> [String]? {
    guard let line = getenv("COMP_LINE"),
          let point = Int(getenv("COMP_POINT") ?? "") else {
        return nil
    }
    
    let tools = ["build", "package", "test"]
    let buildConfigurations = ["debug", "release"]
    let sharedOptions = ["-C", "--chdir", "--color", "-v", "--verbose", "--version", "-Xcc", "-Xlinker", "-Xswiftc"]
    let buildOptions = ["-c", "--configuration", "--clean", "--build-path"] + sharedOptions
    let packageOptions = ["--enable-code-coverage"] + sharedOptions
    let testOptions = ["-s", "--specifier", "-l", "--list-tests", "--build-path", "--skip-build"] + sharedOptions
    
    let previousWordCompletions: [String: [String]] = [
        "swift": tools,
        
        "-C": [],
        "--chdir": ["<path>"],
        "--build-path": ["<path>"],
        "--color": ["auto", "always", "never"],
        "-Xcc": [],
        "-Xlinker": [],
        "-Xswiftc": [],
        
        "build": buildOptions,
        "-c": buildConfigurations,
        "--configuration": buildConfigurations,
        "--clean": ["build", "dist"],

        "package": PackageMode.arguments,
        "init": ["--type"] + packageOptions,
        "--type": ["empty", "library", "executable", "system-module"],
        "fetch": packageOptions,
        "update": packageOptions,
        "generate-xcodeproj": Array(["--output"] + packageOptions),
        "--output": ["<path>"],
        "show-dependencies": ["--format"] + packageOptions,
        "--format": ["text", "dot", "json"],
        "dump-package": ["--input"] + packageOptions,
        "--input": ["<path>"],
        "--help": [],
        "-h": [],
        "--version": [],

        "test": testOptions,
        "-s": [],
        "--specifier": [],
        "-l": [],
        "--list-tests": [],
    ]
    
    let filter: (String) -> Bool = {
        currentWord == "" || $0.contains(currentWord) || $0 == "<path>"
    }
    
    if let possibleCompletions = previousWordCompletions[previousWord] {
        return possibleCompletions.filter(filter)
    }

    let arguments = line.components(separatedBy: " ")
    if arguments.count >= 2 && tools.contains(arguments[1]) {
        if arguments[1] == "package" && arguments.count >= 3 {
            if let possibleCompletions = previousWordCompletions[arguments[2]] {
                return possibleCompletions.filter(filter)
            }
        }
        if let possibleCompletions = previousWordCompletions[arguments[1]] {
            return possibleCompletions.filter(filter)
        }
    }

    return nil
}
