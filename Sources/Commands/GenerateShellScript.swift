/*
 This source file is part of the Swift.org open source project

 Copyright 2015 - 2016 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See http://swift.org/LICENSE.txt for license information
 See http://swift.org/CONTRIBUTORS.txt for Swift project authors
 */

import Foundation
import Basic
import Utility

// todo: support positional arguments; eg generate-shell-script [shell-name]

func generateShellScript(forShell shell: Shell, print: (String) -> ()) {
    let root = ArgumentParser(usage: "", overview: "Swift compiler")
    root.add(subparser: "build", parser: SwiftBuildTool(args: []).parser)
    root.add(subparser: "package", parser: SwiftPackageTool(args: []).parser)
    root.add(subparser: "test", parser: SwiftTestTool(args: []).parser)

    // Swift compiler flags
    _ = root.add(option: "-assert-config", kind: String.self, usage: "Specify the assert_configuration replacement. Possible values are Debug, Release, Unchecked, DisableReplacement.")
    _ = root.add(option: "-continue-building-after-errors", kind: Bool.self, usage: "Continue building, even after errors are encountered")
    _ = root.add(option: "-D", kind: String.self, usage: "Marks a conditional compilation flag as true")
    _ = root.add(option: "-framework", kind: String.self, usage: "Specifies a framework which should be linked against")
    _ = root.add(option: "-F", kind: String.self, usage: "Add directory to framework search path")
    _ = root.add(option: "-gdwarf-types", kind: Bool.self, usage: "Emit full DWARF type info.")
    _ = root.add(option: "-gline-tables-only", kind: Bool.self, usage: "Emit minimal debug info for backtraces only")
    _ = root.add(option: "-gnone", kind: Bool.self, usage: "Don't emit debug info")
    _ = root.add(option: "-g", kind: Bool.self, usage: "Emit debug info. This is the preferred setting for debugging with LLDB.")
    _ = root.add(option: "-help", kind: Bool.self, usage: "Display available options")
    _ = root.add(option: "-I", kind: String.self, usage: "Add directory to the import search path")
    _ = root.add(option: "-j", kind: Int.self, usage: "Number of commands to execute in parallel")
    _ = root.add(option: "-L", kind: String.self, usage: "Add directory to library link search path")
//    -l<value>              Specifies a library which should be linked against
    _ = root.add(option: "-module-cache-path", kind: String.self, usage: "Specifies the Clang module cache path")
    _ = root.add(option: "-module-link-name", kind: String.self, usage: "Library to link against when using this module")
    _ = root.add(option: "-module-name", kind: String.self, usage: "Name of the module to build")
    _ = root.add(option: "-nostdimport", kind: Bool.self, usage: "Don't search the standard library import path for modules")
    _ = root.add(option: "-num-threads", kind: Int.self, usage: "Enable multi-threading and specify number of threads")
    _ = root.add(option: "-Onone", kind: Bool.self, usage: "Compile without any optimization")
    _ = root.add(option: "-Ounchecked", kind: Bool.self, usage: "Compile with optimizations and remove runtime safety checks")
    _ = root.add(option: "-O", kind: Bool.self, usage: "Compile with optimizations")
    _ = root.add(option: "-sdk", kind: String.self, usage: "Compile against <sdk>")
    _ = root.add(option: "-static-executable", kind: Bool.self, usage: "Statically link the executable")
    _ = root.add(option: "-static-stdlib", kind: Bool.self, usage: "Statically link the Swift standard library")
    _ = root.add(option: "-suppress-warnings", kind: Bool.self, usage: "Suppress all warnings")
    _ = root.add(option: "-swift-version", kind: String.self, usage: "Interpret input according to a specific Swift language version number")
    _ = root.add(option: "-target-cpu", kind: String.self, usage: "Generate code for a particular CPU variant")
    _ = root.add(option: "-target", kind: String.self, usage: "Generate code for the given target")
//    -use-ld=<value>        Specifies the linker to be used
    _ = root.add(option: "-version", kind: Bool.self, usage: "Print version information and exit")
    _ = root.add(option: "-v", kind: Bool.self, usage: "Show commands to run and use verbose output")
    _ = root.add(option: "-warnings-as-errors", kind: Bool.self, usage: "Treat warnings as errors")
    _ = root.add(option: "-Xcc", kind: String.self, usage: "Pass <arg> to the C/C++/Objective-C compiler")
    _ = root.add(option: "-Xlinker", kind: String.self, usage: "Specifies an option which should be passed to the linker")

    switch shell {
    case .bash: bash(root: root, print: print)
    case .zsh: zsh(root: root, print: print)
    }
}


// MARK:- BASH

fileprivate func bash(root: ArgumentParser, print: (String) -> ()) {
    print("#!/bin/bash")

    print("_swift() ")
    print("{")
    print("    declare -a cur prev")
    print("    cur=\"${COMP_WORDS[COMP_CWORD]}\"")
    print("    prev=\"${COMP_WORDS[COMP_CWORD-1]}\"")

    print("    COMPREPLY=()")

    // completions for tools, and compiler flags (non-tool)
    print("    if [[ $COMP_CWORD == 1 ]]; then")
    print("        COMPREPLY=( $(compgen -W \"build package test\" -- $cur) )")
    print("        _swift_compiler")
    print("        return")
    print("    fi")

    print("    # specify for each tool")
    print("    case ${COMP_WORDS[1]} in")
    for (name, _) in root.subparsers {
        print("        (\(name))")
        print("            _swift_\(name)")
        print("            ;;")
    }
    print("        (*)")
    print("            _swift_compiler")
    print("            ;;")
    print("    esac")
    print("}")

    for (name, parser) in root.subparsers {
        bash_tool(parser, name: "_swift_\(name)", position: 2, print: print)
    }
    bash_compiler(root, print: print)

    print("complete -F _swift swift")
}

fileprivate func bash_tool(_ parser: ArgumentParser, name: String, position: Int, print: (String) -> ()) -> () {
    print("\(name)()")
    print("{")

    // suggest subparsers in addition to other arguments
    print("    if [[ $COMP_CWORD == \(position) ]]; then")
    var completions = [String]()
    for (subName, _) in parser.subparsers {
        completions.append(subName)
    }
    for option in parser.options {
        completions.append(option.name)
        if let shortName = option.shortName {
            completions.append(shortName)
        }
    }
    print("        COMPREPLY=( $(compgen -W \"\(completions.joined(separator: " "))\" -- $cur) )")
    print("        return")
    print("    fi")

    // completions based on last word
    bash_prev_next(parser, print: print)

    // forward to subparser
    print("    case ${COMP_WORDS[\(position)]} in")
    for (subName, _) in parser.subparsers {
        print("        (\(subName))")
        print("            \(name)_\(subName)")
        print("            return")
        print("        ;;")
    }
    print("    esac")

    // other arguments
    print("    COMPREPLY=( $(compgen -W \"\(completions.joined(separator: " "))\" -- $cur) )")
    print("}")
    print("")

    for (subName, subParser) in parser.subparsers {
        bash_tool(subParser, name: "\(name)_\(subName)", position: position + 1, print: print)
    }
}

fileprivate func bash_compiler(_ parser: ArgumentParser, print: (String) -> ()) {
    print("_swift_compiler()")
    print("{")

    // completions based on last word
    bash_prev_next(parser, print: print)

    // other arguments
    var completions = [String]()
    for option in parser.options {
        completions.append(option.name)
        if let shortName = option.shortName {
            completions.append(shortName)
        }
    }
    print("    COMPREPLY+=( $(compgen -W \"\(completions.joined(separator: " "))\" -- $cur) )")

    // compiler accepts filenames
    print("    _filedir")

    print("}")
    print("")
}

fileprivate func bash_prev_next(_ parser: ArgumentParser, print: (String) -> ()) {
    print("    case $prev in")
    for option in parser.options {
        let flags = [option.name] + (option.shortName.map({[$0]}) ?? [])
        print("        (\(flags.joined(separator: "|")))")
        switch option.kind.completion {
        case .none:
            // return; no value to complete
            print("            return")
        case .unspecified:
            break
        case .values(let values):
            print("            COMPREPLY=( $(compgen -W \"\(values.map({$0.value}).joined(separator: " "))\" -- $cur) )")
            print("            return")
        case .filename:
            print("            _filedir")
            print("            return")
        }
        print("        ;;")
    }
    print("    esac")
}


// MARK:- ZSH

fileprivate func zsh(root: ArgumentParser, print: (String) -> ()) {
    print("#compdef swift")
    print("local context state state_descr line")
    print("typeset -A opt_args")
    print("")
    print("_swift() {")
    print("    _arguments -C \\")
    print("        '(-): :->command' \\")
    print("        '(-)*:: :->arg' && return")
    print("")
    print("    case $state in")
    print("        (command)")
    print("            local tools")
    print("            tools=(")
    for (name, parser) in root.subparsers {
        print("                '\(name):\(parser.overview)'")
    }
    print("            )")
    print("            _alternative \\")
    print("                'tools:common:{_describe \"tool\" tools }' \\")
    print("                'compiler: :_swift_compiler' && _ret=0")
    print("            ;;")
    print("        (arg)")
    print("            case ${words[1]} in")
    for (name, _) in root.subparsers {
        print("                (\(name))")
        print("                    _swift_\(name)")
        print("                    ;;")
    }
    print("                (*)")
    print("                    _swift_compiler")
    print("                    ;;")
    print("            esac")
    print("            ;;")
    print("    esac")
    print("}")
    for (name, parser) in root.subparsers {
        zsh_tool(parser, name: "_swift_\(name)", position: 0, print: print)
    }
    zsh_compiler(root, print: print)
    print("_swift")
}

let removeDefaultRegex = try! NSRegularExpression(pattern: "\\[default: .+?\\]", options: [])

fileprivate func zsh_tool(_ parser: ArgumentParser, name: String, position: Int, print: (String) -> ()) {
    print("\(name)() {")
    print("    arguments=(")
    for option in parser.options {
        print(zsh_argument(option))
    }
    if parser.subparsers.count > 0 {
        print("        '(-): :->command'")
        print("        '(-)*:: :->arg'")
    }
    print("    )")
    print("    _arguments $arguments && return")

    if parser.subparsers.count > 0 {
        print("    case $state in")
        print("        (command)")
        print("            local modes")
        print("            modes=(")
        for (subName, subParser) in parser.subparsers {
            print("                '\(subName):\(subParser.overview)'")
        }
        print("            )")
        print("            _describe \"mode\" modes")
        print("            ;;")
        print("        (arg)")
        print("            case ${words[1]} in")
        for (subName, _) in parser.subparsers {
            print("                (\(subName))")
            print("                    \(name)_\(subName)")
            print("                    ;;")
        }
        print("            esac")
        print("            ;;")
        print("    esac")
    }
    print("}")
    print("")

    for (subName, subParser) in parser.subparsers {
        zsh_tool(subParser, name: "\(name)_\(subName)", position: position + 1, print: print)
    }
}

fileprivate func zsh_compiler(_ parser: ArgumentParser, print: (String) -> ()) {
    print("_swift_compiler() {")
    print("    arguments=(")
    for option in parser.options {
        print(zsh_argument(option))
    }
    print("        '*:inputs:_files'")
    print("    )")
    print("    _arguments $arguments && return")
    print("}")
    print("")
}

fileprivate func zsh_argument(_ argument: AnyArgument) -> String {
    let flags: String
    switch argument.shortName {
    case .none: flags = "\(argument.name)"
    case let shortName?: flags = "(\(argument.name) \(shortName))\"{\(argument.name),\(shortName)}\""
    }

    let completions: String
    switch argument.kind.completion {
    case .none: completions = ": : "
    case .unspecified: completions = ""
    case .filename: completions = ": :_files"
    case let .values(values): completions = ": :{_values '' \(values.map({ $0.value }).joined(separator: " "))}"
    }

    let description = removeDefaultRegex.replace(in: argument.usage ?? "", with: "").replacingOccurrences(of: "\"", with: "\\\"")

    return "        \"\(flags)[\(description)]\(completions)\""
}

fileprivate extension NSRegularExpression {
    func replace(`in` original: String, with replacement: String) -> String {
        return stringByReplacingMatches(in: original, options: [], range: NSRange(location: 0, length: original.characters.count), withTemplate: replacement)
    }
}


