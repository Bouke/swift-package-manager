//import Foundation // String.hasPrefix
import func POSIX.getenv
import func POSIX.exit
import enum Commands.PackageMode

guard CommandLine.arguments.count >= 4,
      CommandLine.arguments[1] == "swift",
      let line = getenv("COMP_LINE"),
      let point = Int(getenv("COMP_POINT") ?? "") else {
    exit(1)
}

let currentWord = CommandLine.arguments[2]
let previousWord = CommandLine.arguments[3]

let packageOptions = [
    "-C", "--chdir", 
    "--color", 
    "--enable-code-coverage",
    "-v", "--verbose",
    "-Xcc",
    "-Xlinker",
    "-Xswiftc",
]

  // -assert-config <value> Specify the assert_configuration replacement. Possible values are Debug, Release, Unchecked, DisableReplacement.
  // -D <value>             Marks a conditional compilation flag as true
  // -framework <value>     Specifies a framework which should be linked against
  // -F <value>             Add directory to framework search path
  // -gdwarf-types          Emit full DWARF type info.
  // -gline-tables-only     Emit minimal debug info for backtraces only
  // -gnone                 Don't emit debug info
  // -g                     Emit debug info. This is the preferred setting for debugging with LLDB.
  // -help                  Display available options
  // -index-store-path <path>
  //                        Store indexing data to <path>
  // -I <value>             Add directory to the import search path
  // -j <n>                 Number of commands to execute in parallel
  // -L <value>             Add directory to library link search path
  // -l<value>              Specifies a library which should be linked against
  // -module-cache-path <value>
  //                        Specifies the Clang module cache path
  // -module-link-name <value>
  //                        Library to link against when using this module
  // -module-name <value>   Name of the module to build
  // -nostdimport           Don't search the standard library import path for modules
  // -num-threads <n>       Enable multi-threading and specify number of threads
  // -Onone                 Compile without any optimization
  // -Ounchecked            Compile with optimizations and remove runtime safety checks
  // -O                     Compile with optimizations
  // -sdk <sdk>             Compile against <sdk>
  // -static-stdlib         Statically link the Swift standard library
  // -suppress-warnings     Suppress all warnings
  // -target-cpu <value>    Generate code for a particular CPU variant
  // -target <value>        Generate code for the given target
  // -use-ld=<value>        Specifies the linker to be used
  // -version               Print version information and exit
  // -v                     Show commands to run and use verbose output
  // -warnings-as-errors    Treat warnings as errors
  // -Xcc <arg>             Pass <arg> to the C/C++/Objective-C compiler
  // -Xlinker <value>       Specifies an option which should be passed to the linker

let previousWordCompletions = [
    "swift": ["build", "package", "test", "-v", "-version"],

    "build": ["-c", "--configuration", "--clean", "-C", "--chdir",
              "--build-path", "--color", "-v", "--verbose", "-Xcc", "-Xlinker",
              "-Xswiftc"],
    "-c": ["debug", "release"],
    "--configuration": ["debug", "release"],
    "--clean": ["build", "dist"],

    "package": PackageMode.arguments,
    
    "init": ["--type"] + packageOptions,
    "--type": ["empty", "library", "executable", "system-module"],
    "fetch": packageOptions,
    "update": packageOptions,
    "generate-xcodeproj": ["--output"] + packageOptions,
    
    "show-dependencies": ["--format"] + packageOptions,
    "--format": ["text", "dot", "json"],
    
    "dump-package": ["--input"] + packageOptions,
    "--input": ["<path>"],

    "--color": ["auto", "always", "never"],

    "test": [
        "-s", "--specifier", 
        "-l", "--list-tests",
        "-C", "--chdir",
        "--build-path",
        "--color",
        "-v", "--verbose",
        "--skip-build",
        "-Xcc",
        "-Xlinker",
        "-Xswiftc",
    ],
    "-s": ["<path>"],
    "--specifier": ["<path>"],

    "-C": [],
    "--chdir": [],
    "--build-path": [],
    "-Xcc": [],
    "-Xlinker": [],
    "-Xswiftc": [],
]

if let completions = previousWordCompletions[previousWord] {
    print(completions
        .filter { currentWord == "" || $0.contains(currentWord) }
        .joined(separator: "\n"))
    exit(0)
}

let arguments = line.components(separatedBy: " ")
if arguments.count > 2 {
    if let completions = previousWordCompletions[arguments[1]] {
        print(completions
            .filter { currentWord == "" || $0.contains(currentWord) }
            .joined(separator: "\n"))
        exit(0)
    }
}
