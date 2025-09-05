import Cocoa

// Explicit main function to debug Swift runtime
print("🚨 SWIFT MAIN: main.swift executing")
fflush(stdout)

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate

print("🚨 SWIFT MAIN: About to run app")
fflush(stdout)

app.run()

print("🚨 SWIFT MAIN: App finished")
fflush(stdout)