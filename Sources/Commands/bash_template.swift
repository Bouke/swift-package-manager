//
//  zsh_template.swift
//  SwiftPM
//
//  Created by Bouke Haarsma on 29/09/2016.
//
//

import Foundation
import Basic

func bash_template(print: (String) -> ()) {
    print("#!/bin/bash")

    print("_swift() ")
    print("{")
    print("    declare -a cur prev shared_options")
    print("    cur=\"${COMP_WORDS[COMP_CWORD]}\"")
    print("    prev=\"${COMP_WORDS[COMP_CWORD-1]}\"")

    print("    COMPREPLY=()")

    print("    # completions for tools, and compiler flags (non-tool)")
    print("    if [[ $COMP_CWORD == 1 ]]; then")
    print("        COMPREPLY=( $(compgen -W \"build package test\" -- $cur) )")
    print("        _swift_compiler")
    print("        return")
    print("    fi")

    print("    # shared options are available in all tools")
    print("    shared_options=\"-C --chdir --color -v --verbose -Xcc -Xlinker -Xswiftc\"")

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

    print("_swift_build()")
    print("{")
    print("    case $prev in")
    print("        (-c|--configuration)")
    print("            COMPREPLY=( $(compgen -W \"debug release\" -- $cur) )")
    print("            return")
    print("            ;;")
    print("        (--clean)")
    print("            COMPREPLY=( $(compgen -W \"build dist\" -- $cur) )")
    print("            ;;")
    print("        (--build-path)")
    print("            _filedir")
    print("            return")
    print("            ;;")
    print("    esac")
    print("    COMPREPLY+=( $(compgen -W \"-c --configuration --clean --build-path $shared_options\" -- $cur) )")
    print("}")

    mode(options: PackageMode.options_, name: "_swift_package", position: 2, print: print)

    print("_swift_test()")
    print("{")
    print("    case $prev in")
    print("        (-s|--specifier)")
    print("            return")
    print("            ;;")
    print("    esac")
    print("    COMPREPLY=( $(compgen -W \"-s --specifier -l --list-tests --skip-build --version $shared_options\" -- $cur) )")
    print("}")

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

func mode(options: [Option], name: String, position: Int, print: (String) -> ()) -> () {
    print("\(name)()")
    print("{")
    print("    if [[ $COMP_CWORD == \(position) ]]; then")
    var completions = [String]()
    for option in options {
        switch option {
        case let option as OptionMode:
            completions.append(option.name)
        case let option as OptionFlag:
            completions += option.flags
        default: break
        }
    }
    print("        COMPREPLY=( $(compgen -W \"\(completions.joined(separator: " "))\" -- $cur) )")
    print("        return")
    print("    fi")
    print("")
    print("    case $prev in")
    for option in options.flatMap({ $0 as? OptionFlag }) {
        print("        (\(option.flags.joined(separator: "|")))")
        switch option.completion {
        case .none:
            // no return; no value to complete
            break
        case .values(let values):
            print("            COMPREPLY=( $(compgen -W \"\(values.joined(separator: " "))\" -- $cur) )")
            print("            return")
        case .filename:
            print("            _filedir")
            print("            return")
        case .other:
            print("            return")
        }
        print("        ;;")
    }
    print("    esac")
    print("")
    print("    case ${COMP_WORDS[\(position)]} in")
    for option in options.flatMap({ $0 as? OptionMode }) {
        print("        (\(option.name))")
        print("            \(name)_\(option.name)")
        print("            return")
        print("        ;;")
    }
    print("    esac")
    print("")
    print("    COMPREPLY=( $(compgen -W \"\(completions.joined(separator: " "))\" -- $cur) )")
    print("}")
    print("")

    for option in options.flatMap({ $0 as? OptionMode }) {
        mode(options: option.options, name: "\(name)_\(option.name)", position: position + 1, print: print)
    }
}
