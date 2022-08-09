# experimental-test-tool-swift


<img width="640" alt="Captura de Pantalla 2022-08-08 a la(s) 7 07 24" src="https://user-images.githubusercontent.com/16517868/183414396-108611c1-8585-4ce5-8b4f-088ea4d15f04.png">

[![GitHub issues](https://img.shields.io/github/issues/fsaldivar-dev/experimental-test-tool-swift?style=for-the-badge)](https://github.com/fsaldivar-dev/experimental-test-tool-swift/issues)
[![GitHub forks](https://img.shields.io/github/forks/fsaldivar-dev/experimental-test-tool-swift?style=for-the-badge)](https://github.com/fsaldivar-dev/experimental-test-tool-swift/network)
[![GitHub stars](https://img.shields.io/github/stars/fsaldivar-dev/experimental-test-tool-swift?style=for-the-badge)](https://github.com/fsaldivar-dev/experimental-test-tool-swift/stargazers)
[![GitHub license](https://img.shields.io/github/license/fsaldivar-dev/experimental-test-tool-swift?style=for-the-badge)](https://github.com/fsaldivar-dev/experimental-test-tool-swift/blob/main/LICENSE.md)

Pod creado para facilitar la creación de pruebas únitarias mediante código simple

# Roadmap

|                Roadmap             |    Estado     |
| -----------------------------------| ------------- |
| Crear código base                  | ✅            |
| SwiftPackage                       | ⌛ 👨‍💻         |
| [CocoaPods](https://cocoapods.org) | 👨‍💻            |
| Example                            | ✅            |
| [Simple Dummy](./Sources/SpockDummy/assets//SpockableDummy.md)| ✅            |
| Spy                                | ⌛ 👨‍💻         |
| Mock                               | ⌛ 👨‍💻         |
| Stubed                             | ⌛ 👨‍💻         |
| UnitTest                           | ⌛ 👨‍💻         |
| Documentación                      | ⌛  👨‍💻        |
| Extensiones                        | ⌛  👨‍💻        |


### Swift Package Manager
Swift Package Manager es una herramienta para automatizar la distribución de código Swift y está integrado en el compilador Swift. Está en desarrollo temprano, pero experimental-annotation-swift admite su uso en plataformas compatibles.


Una vez que haya configurado su paquete Swift, agregar experimental-annotation-swift como dependencia es tan fácil como agregarlo al valor de dependencias de su Package.swift.
```swift
In working
```

### CocoaPods
[CocoaPods](https://cocoapods.org) es un administrador de dependencias para proyectos Cocoa. Para obtener instrucciones de uso e instalación, visite su sitio web. Para integrar AnnotationSwift en su proyecto Xcode usando CocoaPods, especifíquelo en su `Podfile`:


```ruby
 pod SpockSwift, '0.0.1'
```

## [Dummy](./Sources/SpockDummy/assets//SpockableDummy.md)
**Definición**
Los objetos Dummy son objetos que no se utilizan en una prueba y solo actúan como marcadores de posición. Por lo general, no contiene ninguna implementación.
### Ejemplo
````Swift

struct User: Codable, SpockDummy {
  let name: String
  var lastName: String
  var age: Int
  var profession: Profession
}

struct Profession: Codable, SpockDummy {
  var name: String
  var university: University
}

struct University: Codable: SpockDummy {
   let name: String
   var country: String
}

let user: User = try .dummy()
print(user.name) // return ""
print(user.age) // return 0
print(user.profession.name) // return ""
print(user.profession.university.name) // return ""
print(user.profession.university.country) // return ""

let user = try Profession.dummy()
print(profession.name) // return ""
print(profession.university.name) // return ""
print(profession.university.country) // return ""

let university = try University.dummy()
print(university.name) // return ""
print(university.country) // return ""
````



# Author & License

Proyecto creado por **Francisco Javier Saldivar** [![image](https://img.shields.io/badge/LinkedIn-0077B5?style=for-the-badge&logo=linkedin&logoColor=white)](www.linkedin.com/in/fsaldivar-dev)


