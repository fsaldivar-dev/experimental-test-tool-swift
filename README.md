# experimental-test-tool-swift


<img width="661" alt="Captura de Pantalla 2022-08-06 a la(s) 8 06 21" src="https://user-images.githubusercontent.com/16517868/183250159-668900e0-23b1-4f7a-8d30-034557d89ca9.png">

Pod creado para facilitar la creación de pruebas únitarias mediante código simple

# Roadmap

| Roadmap | Estado |
| ------------- | ------------- |
| Crear código base | ✅ |
| SwiftPackage | ✅ |
| [CocoaPods](https://cocoapods.org) | 👨‍💻 |
| Example | ⌛ 👨‍💻|
| Spy | ⌛ 👨‍💻|
| Mock | ⌛ 👨‍💻|
| Stubed | ⌛ 👨‍💻|
| UnitTest | ⌛ 👨‍💻|
| Documentación  | ⌛  👨‍💻|
| Extensiones  | ⌛  👨‍💻|


### Swift Package Manager
Swift Package Manager es una herramienta para automatizar la distribución de código Swift y está integrado en el compilador Swift. Está en desarrollo temprano, pero experimental-annotation-swift admite su uso en plataformas compatibles.


Una vez que haya configurado su paquete Swift, agregar experimental-annotation-swift como dependencia es tan fácil como agregarlo al valor de dependencias de su Package.swift.
```swift
dependencies: [
    .package(url: "https://github.com/JavierSaldivarRubio/esperimental-annotation-swift", .upToNextMajor(from: "0.0.1"))
]
```

### CocoaPods
[CocoaPods](https://cocoapods.org) es un administrador de dependencias para proyectos Cocoa. Para obtener instrucciones de uso e instalación, visite su sitio web. Para integrar AnnotationSwift en su proyecto Xcode usando CocoaPods, especifíquelo en su `Podfile`:


```ruby
In working
```


Dummy
A dummy is a test double that doesn't do anything.

You might use this as a placeholder for an input parameter of the system under test when it doesn't interact or affect the behaviour you are testing.



### Fake
A fake is test double returning the same value or performing the same behaviour all the time.

You might want to use this when the behaviour of the system under test has something your component does as a pre-requisite, regardless of its outcome.

For example when writing an integration test you might want to provide a different implementation of the storage layer, say an in-memory one rather than one writing to disk. Your integration test depends on the storage behaving properly and consistently, but you never need to look into the it as part of what you're testing.


### Stub
A stub is a test double you can use to control the input provided to the system under test.

When the behaviour you are testing depends on what an input does you should use a stub for that input in your tests.

A common use case for stubs is to allow testing how objects behave depending on the success or failure of an operation.

My favourite use case for stubs is when testing the behaviour of objects consuming a service making a request that can succeed or fail. We can write a stub in which we control whether the request succeeds or fail, and this allows us to test the behaviour of our component in both scenarios.

Say we have a PizzaPresenter charged with providing view controllers the logic to fetch pizzas from the server and transform them into objects that can be displayed. We can test how it behaves if the request succeeds or fails using a stub.

### Spy
A spy is a test double you can use to inspect the output produced by the system under test.

Spies are the opposite of stubs. When the system under test performs a side effect on a dependency you can use a spy to record the effect and then verify it matches the expected behaviour.

For example, every one is implementing Dark Mode in their iOS apps nowadays. Say you want to test SettingsController, the component which your settings view controller uses to relay the user interaction with the UI.
