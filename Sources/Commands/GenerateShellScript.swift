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

func bash_template(print: (String) -> ()) {
    print("#!/bin/bash")

    print("_swift() ")
    print("{")
    print("    declare -a cur prev")
    print("    cur=\"${COMP_WORDS[COMP_CWORD]}\"")
    print("    prev=\"${COMP_WORDS[COMP_CWORD-1]}\"")

    print("    COMPREPLY=()")

    print("    # completions for tools, and compiler flags (non-tool)")
    print("    if [[ $COMP_CWORD == 1 ]]; then")
    print("        COMPREPLY=( $(compgen -W \"build package test\" -- $cur) )")
    print("        _swift_compiler")
    print("        return")
    print("    fi")

    print("    # specify for each tool")
    print("    case ${COMP_WORDS[1]} in")
    print("        (build)")
    print("            _swift_build")
    print("            ;;")
    print("        (package)")
    print("            _swift_package")
    print("            ;;")
    print("        (test)")
    print("            _swift_test")
    print("            ;;")
    print("        (*)")
    print("            _swift_compiler")
    print("            ;;")
    print("    esac")
    print("}")

    bash_parser(SwiftBuildTool(args: []).parser, name: "_swift_build", position: 2, print: print)
    bash_parser(SwiftPackageTool(args: []).parser, name: "_swift_package", position: 2, print: print)
    bash_parser(SwiftTestTool(args: []).parser, name: "_swift_test", position: 2, print: print)

    print("_swift_compiler()")
    print("{")
    print("    case $prev in")
    print("        (-assert-config)")
    print("            COMPREPLY=( $(compgen -W \"Debug Release Unchecked DisableReplacement\" -- $cur) )")
    print("            return")
    print("            ;;")
    print("        (-D|-framework|-j|-l|-module-link-name|-module-name|-num-threads|-sdk|-target-cpu|-target|-use-ld)")
    print("            return")
    print("            ;;")
    print("        (-F|-index-store-path|-I|-L|-module-cache-path)")
    print("            _filedir")
    print("            ;;")
    print("    esac")
    print("    local args")
    print("    args=\"-assert-config -D -framework -F -gdwarf-types -gline-tables-only \\")
    print("         -gnone -g -help -index-store-path -I -j -L -l -module-cache-path \\")
    print("         -module-link-name -module-name -nostdimport -num-threads -Onone \\")
    print("         -Ounchecked -O -sdk -static-stdlib -suppress-warnings -target-cpu \\")
    print("         -target -use-ld -version -v -warnings-as-errors -Xcc -Xlinker\"")
    print("    COMPREPLY+=( $(compgen -W \"$args\" -- $cur))")
    print("    _filedir")
    print("}")

    print("complete -F _swift swift")
}

fileprivate func bash_parser(_ parser: ArgumentParser, name: String, position: Int, print: (String) -> ()) -> () {
    print("\(name)()")
    print("{")
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
    print("")
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
    print("")

    // forward to subparser
    print("    case ${COMP_WORDS[\(position)]} in")
    for (subName, _) in parser.subparsers {
        print("        (\(subName))")
        print("            \(name)_\(subName)")
        print("            return")
        print("        ;;")
    }
    print("    esac")
    print("")
    print("    COMPREPLY=( $(compgen -W \"\(completions.joined(separator: " "))\" -- $cur) )")
    print("}")
    print("")

    for (subName, subParser) in parser.subparsers {
        bash_parser(subParser, name: "\(name)_\(subName)", position: position + 1, print: print)
    }
}


func zsh_template(print: (String) -> ()) {
    print("#compdef swift")
    print("local context state state_descr line")
    print("typeset -A opt_args")
    print("")
    print("_swift() {")
    print("    declare -a shared_options")
    print("    shared_options=(")
    print("        '(-C --chdir)'{-C,--chdir}\"[Change working directory before any other operation]: :_files\"")
    print("        \"--color[Specify color mode (auto|always|never)]: :{_values \"mode\" auto always never}\"")
    print("        '(-v --verbose)'{-v,--verbose}'[Increase verbosity of informational output]'")
    print("        \"-Xcc[Pass flag through to all C compiler invocations]: : \"")
    print("        \"-Xlinker[Pass flag through to all linker invocations]: : \"")
    print("        \"-Xswiftc[Pass flag through to all Swift compiler invocations]: : \"")
    print("    )")
    print("")
    print("    _arguments -C \\")
    print("        '(- :)--help[prints the synopsis and a list of the most commonly used commands]: :->arg' \\")
    print("        '(-): :->command' \\")
    print("        '(-)*:: :->arg' && return")
    print("")
    print("    case $state in")
    print("        (command)")
    print("            local tools")
    print("            tools=(")
    print("                'build:build the package'")
    print("                'package:package management'")
    print("                'test:run tests'")
    print("            )")
    print("            _alternative \\")
    print("                'tools:common:{_describe \"tool\" tools }' \\")
    print("                'compiler: :_swift_compiler' && _ret=0")
    print("            ;;")
    print("        (arg)")
    print("            case ${words[1]} in")
    print("                (build)")
    print("                    _swift_build")
    print("                    ;;")
    print("                (package)")
    print("                    _swift_package")
    print("                    ;;")
    print("                (test)")
    print("                    _swift_test")
    print("                    ;;")
    print("                (*)")
    print("                    _swift_compiler")
    print("                    ;;")
    print("            esac")
    print("            ;;")
    print("    esac")
    print("}")
    print("")
    zsh_parser(SwiftBuildTool(args: []).parser, name: "_swift_build", print: print)
    zsh_parser(SwiftPackageTool(args: []).parser, name: "_swift_package", print: print)
    zsh_parser(SwiftTestTool(args: []).parser, name: "_swift_test", print: print)
    print("_swift_compiler() {")
    print("    declare -a build_options")
    print("    build_options=(")
    print("        '-assert-config[Specify the assert_configuration replacement.]: :{_values \"\" Debug Release Unchecked DisableReplacement}'")
    print("        '-D[Marks a conditional compilation flag as true]: : '")
    print("        '-framework[Specifies a framework which should be linked against]: : '")
    print("        '-F[Add directory to framework search path]: :_files'")
    print("        '-gdwarf-types[Emit full DWARF type info.]'")
    print("        '-gline-tables-only[Emit minimal debug info for backtraces only]'")
    print("        \"-gnone[Don't emit debug info]\"")
    print("        '-g[Emit debug info. This is the preferred setting for debugging with LLDB.]'")
    print("        '-help[Display available options]'")
    print("        '-index-store-path[Store indexing data to <path>]: :_files'")
    print("        '-I[Add directory to the import search path]: :_files'")
    print("        '-j[Number of commands to execute in parallel]: : '")
    print("        '-L[Add directory to library link search path]: :_files'")
    print("        '-l-[Specifies a library which should be linked against]: : '")
    print("        '-module-cache-path[Specifies the Clang module cache path]: :_files'")
    print("        '-module-link-name[Library to link against when using this module]: : '")
    print("        '-module-name[Name of the module to build]: : '")
    print("        \"-nostdimport[Don't search the standard library import path for modules]\"")
    print("        '-num-threads[Enable multi-threading and specify number of threads]: : '")
    print("        '-Onone[Compile without any optimization]'")
    print("        '-Ounchecked[Compile with optimizations and remove runtime safety checks]'")
    print("        '-O[Compile with optimizations]'")
    print("        '-sdk[Compile against <sdk>]: : '")
    print("        '-static-stdlib[Statically link the Swift standard library]'")
    print("        '-suppress-warnings[Suppress all warnings]'")
    print("        '-target-cpu[Generate code for a particular CPU variant]: : '")
    print("        '-target[Generate code for the given target]: : '")
    print("        '-use-ld=-[Specifies the linker to be used]'")
    print("        '-version[Print version information and exit]'")
    print("        '-v[Show commands to run and use verbose output]'")
    print("        '-warnings-as-errors[Treat warnings as errors]'")
    print("        '-Xcc[Pass <arg> to the C/C++/Objective-C compiler]: : '")
    print("        '-Xlinker[Specifies an option which should be passed to the linker]: : '")
    print("        '*:inputs:_files'")
    print("    )")
    print("    _arguments $build_options")
    print("}")
    print("")
    print("_swift")
}

let removeDefaultRegex = try! NSRegularExpression(pattern: "\\[default: .+?\\]", options: [])

fileprivate func zsh_parser(_ parser: ArgumentParser, name: String, print: (String) -> ()) {
    // todo: subparsers
    print("\(name)() {")
    print("    local -a arguments")
    print("    arguments=(")
    for option in parser.options {
        let flags: String
        switch option.shortName {
        case .none: flags = "\(option.name)"
        case let shortName?: flags = "(\(option.name) \(shortName))'{\(option.name),\(shortName)}'"
        }

        let completions: String
        switch option.kind.completion {
        case .none: completions = ": : "
        case .unspecified: completions = ""
        case .filename: completions = ": :_files"
        case let .values(values): completions = ": :{_values \"\" \(values.map({ $0.value }).joined(separator: " "))}"
        }

        let description = removeDefaultRegex.replace(in: option.usage ?? "", with: "")

        print("        '\(flags)[\(description)]\(completions)'")
    }
    print("    )")
    print("    _arguments $arguments")
    print("}")
    print("")
}

fileprivate extension NSRegularExpression {
    func replace(`in` original: String, with replacement: String) -> String {
        return stringByReplacingMatches(in: original, options: [], range: NSRange(location: 0, length: original.characters.count), withTemplate: replacement)
    }
}


