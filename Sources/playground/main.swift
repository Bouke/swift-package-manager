//import Basic
//
//enum Mode: Argument {
//    case build
//    case package
//    case test
//
//    init?(argument: String, pop: @escaping () -> String?) throws {
//        switch argument {
//        case "build": self = .build
//        case "package": self = .package
//        case "test": self = .test
//        default: return nil
//        }
//    }
//}
//
//enum CompilerFlag: Argument {
//    case help
//    case version
//
//    init?(argument: String, pop: @escaping () -> String?) throws {
//        switch argument {
//        case "-h", "--help": self = .help
//        case "--version": self = .version
//        default: return nil
//        }
//    }
//}
//
//let (mode, flags): (Mode?, [CompilerFlag]) = try Basic.parseOptions(arguments: Array(CommandLine.arguments.dropFirst()))
//print(mode, flags)


protocol Mode { }
protocol Flag { }

protocol Parser {
    func parse(arguments: [String]) -> (Mode, [Flag])
    var modes: [Mode] { get }
    var flags: [Flag] { get }
}


