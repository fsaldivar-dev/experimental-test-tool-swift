//
//  plugin.swift
//  SpockPlugin (SPM BuildToolPlugin)
//
//  Created for SpockSwift 2.
//

import PackagePlugin

@main
struct SpockPlugin: BuildToolPlugin {
    func createBuildCommands(context: PluginContext, target: Target) async throws -> [Command] {
        // En Fase 6 se conectará spock-gen como comando de prebuild
        return []
    }
}
