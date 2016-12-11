/*
 This source file is part of the Swift.org open source project

 Copyright 2015 - 2016 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See http://swift.org/LICENSE.txt for license information
 See http://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Basic
import Build
import Get
import PackageLoading
import PackageModel
import SourceControl
import Utility
import Xcodeproj

import enum Build.Configuration
import protocol Build.Toolchain
import func POSIX.exit
import func POSIX.chdir

/// Errors encountered duing the package tool operations.
enum PackageToolOperationError: Swift.Error {
    /// The provided package name doesn't exist in package graph.
    case packageNotFound

    /// The current mode does not have all the options it requires.
    case insufficientOptions(usage: String)

    /// The package is in editable state.
    case packageInEditableState
}

/// swift-build tool namespace
public class SwiftPackageTool: SwiftTool<PackageToolOptions> {

   public convenience init(args: [String]) {
       self.init(
            toolName: "package",
            usage: "[options] subcommand",
            overview: "Perform operations on Swift packages",
            args: args
        )
    }
    override func runImpl() throws {
        switch options.mode {
        case .version:
            print(Versioning.currentVersion.completeDisplayString)

        case .initPackage:
            let initPackage = try InitPackage(mode: options.initMode)
            try initPackage.writePackageStructure()

        case .clean:
            try clean()

        case .reset:
            if options.enableNewResolver {
                try getActiveWorkspace().reset()
            } else {
                // Remove the checkouts directory.
                if try exists(getCheckoutsDirectory()) {
                    try removeFileTree(getCheckoutsDirectory())
                }
                // Remove the build directory.
                if exists(buildPath) {
                    try removeFileTree(buildPath)
                }
            }

        case .resolve:
            // NOTE: This command is currently undocumented, and is for
            // bringup of the new dependency resolution logic. This is *NOT*
            // the code currently used to resolve dependencies (which runs
            // off of the infrastructure in the `Get` module).
            try executeResolve(options)
            break

        case .update:
            if options.enableNewResolver {
                let workspace = try getActiveWorkspace()
                // We repin either on explicit repin option or if autopin is enabled.
                let repin = options.repin || workspace.pinsStore.autoPin
                try workspace.updateDependencies(repin: repin)
            } else {
                let packagesDirectory = try getCheckoutsDirectory()
                // Attempt to ensure that none of the repositories are modified.
                if localFileSystem.exists(packagesDirectory) {
                    for name in try localFileSystem.getDirectoryContents(packagesDirectory) {
                        let item = packagesDirectory.appending(RelativePath(name))

                        // Only look at repositories.
                        guard exists(item.appending(component: ".git")) else { continue }

                        // If there is a staged or unstaged diff, don't remove the
                        // tree. This won't detect new untracked files, but it is
                        // just a safety measure for now.
                        let diffArgs = ["--no-ext-diff", "--quiet", "--exit-code"]
                        do {
                            _ = try Git.runPopen([Git.tool, "-C", item.asString, "diff"] + diffArgs)
                            _ = try Git.runPopen([Git.tool, "-C", item.asString, "diff", "--cached"] + diffArgs)
                        } catch {
                            throw Error.repositoryHasChanges(item.asString)
                        }
                    }
                    try removeFileTree(packagesDirectory)
                }
                _ = try loadPackage()
            }
        case .fetch:
            _ = try loadPackage()

        case .edit:
            guard options.enableNewResolver else {
                fatalError("This mode requires --enable-new-resolver")
            }
            // Make sure we have all the options required for editing the package.
            guard let packageName = options.editOptions.packageName, (options.editOptions.revision != nil || options.editOptions.checkoutBranch != nil) else {
                throw PackageToolOperationError.insufficientOptions(usage: editUsage)
            }
            // Get the current workspace.
            let workspace = try getActiveWorkspace()
            let manifests = try workspace.loadDependencyManifests()
            // Look for the package's manifest.
            guard let (manifest, dependency) = manifests.lookup(package: packageName) else {
                throw PackageToolOperationError.packageNotFound
            }
            // Create revision object if provided by user.
            let revision = options.editOptions.revision.flatMap { Revision(identifier: $0) }
            // Put the dependency in edit mode.
            try workspace.edit(dependency: dependency, at: revision, packageName: manifest.name, checkoutBranch: options.editOptions.checkoutBranch)

        case .unedit:
            guard options.enableNewResolver else {
                fatalError("This mode requires --enable-new-resolver")
            }
            guard let packageName = options.editOptions.packageName else {
                throw PackageToolOperationError.insufficientOptions(usage: uneditUsage)
            }
            let workspace = try getActiveWorkspace()
            let manifests = try workspace.loadDependencyManifests()
            // Look for the package's manifest.
            guard let editedDependency = manifests.lookup(package: packageName)?.dependency else {
                throw PackageToolOperationError.packageNotFound
            }
            try workspace.unedit(dependency: editedDependency, forceRemove: options.editOptions.forceRemove)

        case .showDependencies:
            let graph = try loadPackage()
            dumpDependenciesOf(rootPackage: graph.rootPackage, mode: options.showDepsMode)
        case .generateXcodeproj:
            let graph = try loadPackage()

            let projectName: String
            let dstdir: AbsolutePath

            switch options.outputPath {
            case let outpath? where outpath.suffix == ".xcodeproj":
                // if user specified path ending with .xcodeproj, use that
                projectName = String(outpath.basename.characters.dropLast(10))
                dstdir = outpath.parentDirectory
            case let outpath?:
                dstdir = outpath
                projectName = graph.rootPackage.name
            case _:
                dstdir = try getPackageRoot()
                projectName = graph.rootPackage.name
            }
            let outpath = try Xcodeproj.generate(outputDir: dstdir, projectName: projectName, graph: graph, options: options.xcodeprojOptions)

            print("generated:", outpath.prettyPath)

        case .describe:
            let graph = try loadPackage()
            describe(graph.rootPackage, in: options.describeMode, on: stdoutStream)

        case .dumpPackage:
            let manifest = try loadRootManifest(options)
            print(try manifest.jsonString())
        case .help:
            parser.printUsage(on: stdoutStream)
        case .pin:
            guard options.enableNewResolver else {
                fatalError("This mode requires --enable-new-resolver")
            }
            // FIXME: It would be nice to have mutual exclusion pinning options.
            // Argument parser needs to provide that functionality.

            // Toggle enable auto pinning if requested.
            if let enableAutoPin = options.pinOptions.enableAutoPin {
                let workspace = try getActiveWorkspace()
                return try workspace.pinsStore.setAutoPin(on: enableAutoPin)
            }
            // Pin all dependencies if requested.
            if options.pinOptions.pinAll {
                let workspace = try getActiveWorkspace()
                return try workspace.pinAll()
            }
            // Ensure we have the package name at this point.
            guard let packageName = options.pinOptions.packageName else {
                throw PackageToolOperationError.insufficientOptions(usage: pinUsage)
            }
            let workspace = try getActiveWorkspace()
            // Load the package graph.
            _ = try workspace.loadPackageGraph()
            // Load the dependencies.
            let manifests = try workspace.loadDependencyManifests()
            // Lookup the dependency to pin.
            guard let (_, dependency) = manifests.lookup(package: packageName) else {
                throw PackageToolOperationError.packageNotFound
            }
            // We can't pin something which is in editable mode.
            guard !dependency.isInEditableState else {
                throw PackageToolOperationError.packageInEditableState
            }
            // Pin the dependency.
            try workspace.pin(
                dependency: dependency,
                packageName: packageName,
                at: try options.pinOptions.version.flatMap(Version.init(string:)) ?? dependency.currentVersion!,
                reason: options.pinOptions.message
            )
        case .unpin:
            guard options.enableNewResolver else {
                fatalError("This mode requires --enable-new-resolver")
            }
            guard let packageName = options.pinOptions.packageName else {
                fatalError("Expected package name from parser")
            }
            let workspace = try getActiveWorkspace()
            try workspace.pinsStore.unpin(package: packageName)

        case .generateShellScript:
            switch options.shell {
            case .bash: bash_template(print: { print($0) })
            case .zsh: zsh_template(print: { print($0) })
            default: break
            }
        }
    }

    /// Load the manifest for the root package
    func loadRootManifest(_ options: PackageToolOptions) throws -> Manifest {
        let root = try options.inputPath ?? getPackageRoot()
        return try manifestLoader.loadFile(path: root, baseURL: root.asString, version: nil)
    }
    
    var editUsage: String {
        let stream = BufferedOutputByteStream()
        stream <<< "Expected package edit format:\n"
        stream <<< "swift package edit <packageName> (--revision <revision> | --branch <newBranch>)\n"
        stream <<< "Note: Either revision or branch name is required."
        return stream.bytes.asString!
    }

    var uneditUsage: String {
        let stream = BufferedOutputByteStream()
        stream <<< "Expected package unedit format:\n"
        stream <<< "swift package unedit --name <packageName> [--force]"
        return stream.bytes.asString!
    }
    
    var pinUsage: String {
        let stream = BufferedOutputByteStream()
        stream <<< "Expected package pin format:\n"
        stream <<< "swift package pin (--all | <packageName> [--version <version>])\n"
        stream <<< "Note: Either provide a package to pin or provide pin all option to pin all dependencies."
        return stream.bytes.asString!
    }

    override class func defineArguments(parser: ArgumentParser, binder: ArgumentBinder<PackageToolOptions>) {
        binder.bind(
            option: parser.add(option: "--version", kind: Bool.self),
            to: { options, _ in options.mode = .version })

        let describeParser = parser.add(subparser: PackageMode.describe.rawValue, overview: "Describe the current package")
        binder.bind(
            option: describeParser.add(option: "--type", kind: DescribeMode.self, usage: "json|text"),
            to: { $0.describeMode = $1 })

        _ = parser.add(subparser: PackageMode.dumpPackage.rawValue, overview: "Print parsed Package.swift as JSON")

        let editParser = parser.add(subparser: PackageMode.edit.rawValue, overview: "")
        binder.bind(
            positional: editParser.add(
                positional: "name", kind: String.self,
                usage: "The name of the package to edit"),
            to: { $0.editOptions.packageName = $1 })
        binder.bind(
            editParser.add(
                option: "--revision", kind: String.self,
                usage: "The revision to edit"),
            editParser.add(
                option: "--branch", kind: String.self,
                usage: "The branch to create"),
            to: { 
                $0.editOptions.revision = $1 
                $0.editOptions.checkoutBranch = $2})

        parser.add(subparser: PackageMode.clean.rawValue, overview: "Delete build artifacts")
        parser.add(subparser: PackageMode.fetch.rawValue, overview: "Fetch package dependencies")
        parser.add(subparser: PackageMode.reset.rawValue, overview: "Reset the complete cache/build directory")

        let resolveParser = parser.add(subparser: PackageMode.resolve.rawValue, overview: "")
        binder.bind(
            option: resolveParser.add(
                option: "--type", kind: PackageToolOptions.ResolveToolMode.self,
                usage: "text|json"),
            to: { $0.resolveToolMode = $1 })

        let updateParser = parser.add(subparser: PackageMode.update.rawValue, overview: "Update package dependencies")
        binder.bind(
            option: updateParser.add(
                option: "--repin", kind: Bool.self,
                usage: "Update without applying pins and repin the updated versions"),
            to: { $0.repin = $1 })

        let initPackageParser = parser.add(subparser: PackageMode.initPackage.rawValue, overview: "Initialize a new package")
        binder.bind(
            option: initPackageParser.add(
                option: "--type", kind: InitMode.self,
                usage: "empty|library|executable|system-module"),
            to: { $0.initMode = $1 })

        let uneditParser = parser.add(subparser: PackageMode.unedit.rawValue, overview: "")
        binder.bind(
            positional: uneditParser.add(
                positional: "name", kind: String.self,
                usage: "The name of the package to unedit"),
            to: { $0.editOptions.packageName = $1 })
        binder.bind(
            option: uneditParser.add(
                option: "--force", kind: Bool.self,
                usage: "Unedit the package even if it has uncommited and unpushed changes."),
            to: { $0.editOptions.forceRemove = $1 })
        
        let showDependenciesParser = parser.add(subparser: PackageMode.showDependencies.rawValue, overview: "Print the resolved dependency graph")
        binder.bind(
            option: showDependenciesParser.add(
                option: "--format", kind: ShowDependenciesMode.self, 
                usage: "text|dot|json"),
            to: { 
                $0.showDepsMode = $1})

        let generateXcodeParser = parser.add(subparser: PackageMode.generateXcodeproj.rawValue, overview: "Generates an Xcode project")
        binder.bind(
            generateXcodeParser.add(
                option: "--xcconfig-overrides", kind: String.self,
                usage: "Path to xcconfig file"),
            generateXcodeParser.add(
                option: "--enable-code-coverage", kind: Bool.self,
                usage: "Enable code coverage in the generated project"),
            generateXcodeParser.add(
                option: "--output", kind: AbsolutePath.self,
                usage: "Path where the Xcode project should be generated"),
            to: { 
                $0.xcodeprojOptions = XcodeprojOptions(flags: $0.buildFlags, xcconfigOverrides: $0.absolutePathRelativeToWorkingDir($1), enableCodeCoverage: $2)
                $0.outputPath = $3 })

        let pinParser = parser.add(subparser: PackageMode.pin.rawValue, overview: "")
        binder.bind(
            positional: pinParser.add(
                positional: "name", kind: String.self, optional: true,
                usage: "The name of the package to pin"),
            to: { $0.pinOptions.packageName = $1 })
        binder.bind(
            option: pinParser.add(
                option: "--enable-autopin", kind: Bool.self,
                usage: "Enable automatic pinning"),
            to: { $0.pinOptions.enableAutoPin = $1 })
        binder.bind(
            option: pinParser.add(
                option: "--disable-autopin", kind: Bool.self,
                usage: "Disable automatic pinning"),
            to: { $0.pinOptions.enableAutoPin = !$1 })

        binder.bind(
            pinParser.add(
                option: "--all", kind: Bool.self,
                usage: "Pin all dependencies"),
            pinParser.add(
                option: "--message", kind: String.self,
                usage: "The reason for pinning"),
            pinParser.add(
                option: "--version", kind: String.self,
                usage: "The version to pin at"),
            to: {
                $0.pinOptions.pinAll = $1 ?? false
                $0.pinOptions.message = $2
                $0.pinOptions.version = $3 })

        let unpinParser = parser.add(subparser: PackageMode.unpin.rawValue, overview: "")
        binder.bind(
            positional: unpinParser.add(
                positional: "name", kind: String.self,
                usage: "The name of the package to unpin"),
            to: { $0.pinOptions.packageName = $1 })

        let shellParser = parser.add(subparser: PackageMode.generateShellScript.rawValue, overview: "")
        binder.bind(
            positional: shellParser.add(
                positional: "shell-name", kind: Shell.self,
                usage: "The name of the shell to generate scripts for"),
            to: { $0.shell = $1 })

        binder.bind(
            parser: parser,
            to: { $0.mode = PackageMode(rawValue: $1)! })
    }
}

enum Shell: String, StringEnumArgument {
    case bash
    case zsh

    static var completion: ShellCompletion = .values([
        (bash.rawValue, ""),
        (zsh.rawValue, "")
    ])
}

public class PackageToolOptions: ToolOptions {
    var mode: PackageMode = .help

    var describeMode: DescribeMode = .text
    var initMode: InitMode = .library

    var inputPath: AbsolutePath?
    var showDepsMode: ShowDependenciesMode = .text

    struct EditOptions {
        var packageName: String?
        var revision: String?
        var checkoutBranch: String?
        var forceRemove = false
    }

    var editOptions = EditOptions()

    var outputPath: AbsolutePath?
    var xcodeprojOptions = XcodeprojOptions()

    struct PinOptions {
        var enableAutoPin: Bool?
        var pinAll = false
        var message: String?
        var packageName: String?
        var version: String?
    }
    var pinOptions = PinOptions()

    /// Repin the dependencies when running package update.
    var repin = false

    enum ResolveToolMode: String, StringEnumArgument {
        case text
        case json

        public static var completion: ShellCompletion = .values([
            (text.rawValue, ""),
            (json.rawValue, "")
        ])
    }
    var resolveToolMode: ResolveToolMode = .text

    var shell: Shell = .bash
}

public enum PackageMode: String, StringEnumArgument {
    case clean
    case describe
    case dumpPackage = "dump-package"
    case edit
    case fetch
    case generateXcodeproj = "generate-xcodeproj"
    case generateShellScript = "generate-shell-script"
    case initPackage = "init"
    case pin
    case reset
    case resolve
    case showDependencies = "show-dependencies"
    case unedit
    case unpin
    case update
    case version
    case help

    // PackageMode is not used as an argument; completions will be
    // provided by the subparsers.
    public static var completion: ShellCompletion = .none
}

extension InitMode: StringEnumArgument {
    public static var completion: ShellCompletion = .values([
        (empty.description, ""),
        (library.description, ""),
        (executable.description, ""),
        (systemModule.description, "")
    ])
}
extension ShowDependenciesMode: StringEnumArgument {
    public static var completion: ShellCompletion = .values([
        (text.description, ""),
        (dot.description, ""),
        (json.description, "")
    ])
}
extension DescribeMode: StringEnumArgument {
    public static var completion: ShellCompletion = .values([
        (text.rawValue, ""),
        (json.rawValue, "")
    ])
}
