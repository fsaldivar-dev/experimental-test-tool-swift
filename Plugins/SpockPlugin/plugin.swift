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
        let outputDirectory = context.pluginWorkDirectoryURL.appendingPathComponent("Generated")
        let outputFile = outputDirectory.appendingPathComponent("Stubs.generated.swift")
        let cacheFile = context.pluginWorkDirectoryURL.appendingPathComponent(".spock-cache.json")

        let testDir = sourceTarget.directoryURL.path

        var sourceDirs: [String] = []
        for dep in sourceTarget.dependencies {
            switch dep {
            case .target(let target):
                if let src = target as? SourceModuleTarget {
                    sourceDirs.append(src.directoryURL.path)
                }
            case .product(let product):
                for target in product.targets {
                    if let src = target as? SourceModuleTarget {
                        sourceDirs.append(src.directoryURL.path)
                    }
                }
            @unknown default:
                break
            }
        }

        if sourceDirs.isEmpty {
            sourceDirs.append(context.package.directoryURL.appendingPathComponent("Sources").path)
        }

        var arguments: [String] = ["--sources"]
        arguments.append(contentsOf: sourceDirs)
        arguments.append(contentsOf: [
            "--tests", testDir,
            "--output", outputFile.path,
            "--cache", cacheFile.path
        ])

        return [
            .prebuildCommand(
                displayName: "SpockSwift 2: AutoTree Stub Generation",
                executable: executable.url,
                arguments: arguments,
                outputFilesDirectory: outputDirectory
            )
        ]
    }
}
