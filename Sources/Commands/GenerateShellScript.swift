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
