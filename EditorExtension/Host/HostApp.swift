//
//  HostApp.swift
//  SpockExtension Host App
//
//  Created for SpockSwift 2.
//

import SwiftUI

@main
struct HostApp: App {
    var body: some Scene {
        WindowGroup {
            VStack(spacing: 20) {
                Image(systemName: "wand.and.stars")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 64, height: 64)
                    .foregroundColor(.accentColor)

                Text("SpockSwift 2 - Extensión para Xcode")
                    .font(.title2)
                    .fontWeight(.bold)

                Text("Esta aplicación hospeda la extensión de edición de código para Xcode.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                Divider()

                VStack(alignment: .leading, spacing: 12) {
                    Text("Cómo habilitar en Xcode:")
                        .font(.headline)

                    HStack(alignment: .top) {
                        Text("1.")
                        Text("Abre **Ajustes del Sistema (System Settings)** > **Extensiones (Extensions)**.")
                    }

                    HStack(alignment: .top) {
                        Text("2.")
                        Text("Selecciona **Xcode Source Editor** y activa **SpockXcodeExtension**.")
                    }

                    HStack(alignment: .top) {
                        Text("3.")
                        Text("En Xcode, accede a **Editor > Spock** para usar los comandos.")
                    }
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(10)

                Text("Para atajos de teclado rápidos, configura Key Bindings en Xcode > Settings > Key Bindings.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(30)
            .frame(width: 480, height: 380)
        }
    }
}
