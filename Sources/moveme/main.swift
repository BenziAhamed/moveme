//
//  moveme.swift
//  resize main window relatve to screen it is in
//
//  Created by Benzi  on 10/02/2023.
//

import AppKit
import AXSwift
import Cocoa
import Foundation

// process command line args
var offsets = CommandLine.arguments.dropFirst().map { CGFloat(($0 as NSString).floatValue) }
if
    offsets.count < 4 // less than expected arguments
    || offsets.filter({ $0 == 0 }).count >= 3 // window dimension is zero in at least one axis
{
    print("error: expected frame offsets as percentage")
    print("       format - x1 y1 x2 y2 % offsets")
    print("       x1 y1 is lower left, x2 y2 is top right")
    print("       e.g.")
    print("       ./moveme 10 10 90 90")
    print("           will center the window leaving a 10% margin around")
    exit(-1)
}
// adjust for rounding off error
offsets = offsets.map { $0 == 0 ? 0.01 : $0 }

extension UIElement {
    func setSize(width: CGFloat, height: CGFloat) {
        try? self.setAttribute(Attribute.size, value: NSValue(size: .init(width: width, height: height)))
    }

    func setPosition(x: CGFloat, y: CGFloat) {
        try? self.setAttribute(Attribute.position, value: NSValue(point: NSPoint(x: x, y: y)))
    }

    func getFrame() -> CGRect? {
        return try? self.attribute(.frame)
    }
}

extension Application {
    static var frontmostApplication: Application? {
        guard let runningApp = NSWorkspace.shared.frontmostApplication else {
            return nil
        }
        return Application(forProcessID: runningApp.processIdentifier)
    }
}

guard let frontmostApplication = Application.frontmostApplication else {
    print("error: unable to get frontmostApplication")
    exit(-1)
}

struct SystemScreens {
    let screens: [NSScreen]
    let maxY: CGFloat
    init() {
        self.screens = NSScreen.screens
        // always the menu owning screen
        // and always AXFrames for windows uses
        // this screen's space for origin
        self.maxY = NSScreen.screens[0].frame.maxY
    }
}

let screens = SystemScreens()

extension CGRect {
    // window coordinate to screen coordinate space conversion
    // find max Y
    // formula to convert window coordinate to screen coordinate is
    // maxY = maxY of bounding box of all screens
    // maxY_screen = height of main screen,
    //               for main screen, maxY == height since main screen is always origined at (0,0)
    // maxY_window = maxY of window IN WINDOW COORDINATES
    // inverted Y position = maxY - (maxY - maxY_screen + maxY_window)
    //                       maxY - maxY + maxY_screen - maxY_window
    //                       maxY_screen - maxY_window
    func invert() -> CGRect {
        return .init(
            x: origin.x,
            y: screens.maxY - maxY,
            width: width,
            height: height
        )
    }
}

// find the main window of the front most app
// note that the main window need not be on the main screen (which is screen 0)
let mainWindow = try? frontmostApplication.windows()?.first(where: {
    let isMain: NSNumber = (try? $0.attribute(.main)) ?? NSNumber(integerLiteral: 0)
    return isMain == 1
})

guard let mainWindow else {
    print("error: unable to get a main window, does one exist for this app?")
    exit(-1)
}

// get window frame in SCREEN COORDINATES
guard let windowFrame = mainWindow.getFrame()?.invert() else {
    print("error: unable to get main window frame")
    exit(-1)
}

struct Overlap {
    let screen: NSScreen
    let overlap: Double
}

extension CGRect {
    var area: CGFloat {
        return width * height
    }
}

// find the screen that has maximum
// overlap with the window frame
let bestScreen = screens.screens.map {
    Overlap(screen: $0, overlap: $0.frame.intersection(windowFrame).area)
}.max(by: { $0.overlap < $1.overlap })!

// visible frame accounts for notch in newer mac book pro models
// visible frame accounts for dock size always
// visible frame does not account for menu bar height
let availableFrame = bestScreen.screen.visibleFrame

// map the offsets to screen space
let x = availableFrame.minX + availableFrame.width * offsets[0] / 100.0
let y = availableFrame.minY + availableFrame.height * offsets[1] / 100.0
let width = (offsets[2] - offsets[0]) * availableFrame.width / 100.0
let height = (offsets[3] - offsets[1]) * availableFrame.height / 100.0

let newFrame = CGRect(x: x, y: y, width: width, height: height)
let newFrameForWindow = newFrame.invert()

mainWindow.setPosition(x: newFrameForWindow.origin.x, y: newFrameForWindow.origin.y)
mainWindow.setSize(width: newFrameForWindow.width, height: newFrameForWindow.height)

//print("available frame", availableFrame)
//print("window frame (screen) ", windowFrame)
//print("resized frame (screen)", newFrame)
//print("resized frame (window)", newFrameForWindow)
//
//print("after resize", mainWindow.getFrame()!.invert())
