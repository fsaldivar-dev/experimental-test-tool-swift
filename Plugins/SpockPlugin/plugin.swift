//
//  plugin.swift
//  SpockPlugin (SPM BuildToolPlugin)
//
//  Created for SpockSwift 2.
//

import PackagePlugin
import Foundation

@main
struct SpockPlugin: BuildToolPlugin {
    func createBuildCommands(context: PluginContext, target: Target) async throws -> [Command] {
        guard let sourceTarget = target as? SourceModuleTarget else {
            return []
        }

        let executable = try context.tool(named: "spock-gen")
        let outputDirectory = context.pluginWorkDirectory.appending(["Generated"])
        let outputFile = outputDirectory.appending(["Stubs.generated.swift"])
        let cacheFile = context.pluginWorkDirectory.appending([".spock-cache.json"])

        let testDir = sourceTarget.directory.string

        var sourceDirs: [String] = []
        for dep in sourceTarget.dependencies {
            switch dep {
            case .target(let target):
                if let src = target as? SourceModuleTarget {
                    sourceDirs.append(src.directory.string)
                }
            case .product(let product):
                for target in product.targets {
                    if let src = target as? SourceModuleTarget {
                        sourceDirs.append(src.directory.string)
                    }
                }
            @unknown default:
                break
            }
        }

        if sourceDirs.isEmpty {
            sourceDirs.append(context.package.directory.appending(["Sources"]).string)
        }

        var arguments: [String] = ["--sources"]
        arguments.append(contentsOf: sourceDirs)
        arguments.append(contentsOf: [
            "--tests", testDir,
            "--output", outputFile.string,
            "--cache", cacheFile.string
        ])

        return [
            .prebuildCommand(
                displayName: "SpockSwift 2: AutoTree Stub Generation",
                executable: executable.path,
                arguments: arguments,
                outputFilesDirectory: outputDirectory
            )
        ]
    }
}
