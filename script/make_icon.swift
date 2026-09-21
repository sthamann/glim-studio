import AppKit
let canvas = NSImage(size: NSSize(width: 1024, height: 1024))
canvas.lockFocus()
let shape = NSBezierPath(roundedRect: NSRect(x: 32,y: 32,width: 960,height: 960), xRadius: 212,yRadius: 212)
NSGradient(starting: NSColor(calibratedRed: 0.38,green: 0.32,blue: 0.91,alpha: 1), ending: NSColor(calibratedRed: 0.14,green: 0.12,blue: 0.38,alpha: 1))!.draw(in: shape, angle: -65)
let configuration = NSImage.SymbolConfiguration(pointSize: 540, weight: .light).applying(.init(paletteColors: [.white]))
if let symbol = NSImage(systemSymbolName: "sparkles.rectangle.stack.fill", accessibilityDescription: nil)?.withSymbolConfiguration(configuration) {
    symbol.draw(in: NSRect(x: 210,y: 242,width: 604,height: 540))
}
canvas.unlockFocus()
let rep = NSBitmapImageRep(data: canvas.tiffRepresentation!)!
try rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
