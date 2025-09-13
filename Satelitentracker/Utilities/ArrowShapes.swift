//
//  ArrowShapes.swift
//  BLE_TestApp
//
//  Created by Raphael Schwierz on 10.06.25.
//

import SwiftUI

struct ArrowShape: Shape {
    enum Direction {
        case up, down, left, right
    }

    let direction: Direction

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let width = rect.width
        let height = rect.height

        switch direction {
        case .up:
            path.move(to: CGPoint(x: width * 0.5, y: height * 0.2))
            path.addLine(to: CGPoint(x: width * 0.2, y: height * 0.6))
            path.addLine(to: CGPoint(x: width * 0.4, y: height * 0.6))
            path.addLine(to: CGPoint(x: width * 0.4, y: height * 0.8))
            path.addLine(to: CGPoint(x: width * 0.6, y: height * 0.8))
            path.addLine(to: CGPoint(x: width * 0.6, y: height * 0.6))
            path.addLine(to: CGPoint(x: width * 0.8, y: height * 0.6))
            path.closeSubpath()
        case .down:
            path.move(to: CGPoint(x: width * 0.5, y: height * 0.8))
            path.addLine(to: CGPoint(x: width * 0.8, y: height * 0.4))
            path.addLine(to: CGPoint(x: width * 0.6, y: height * 0.4))
            path.addLine(to: CGPoint(x: width * 0.6, y: height * 0.2))
            path.addLine(to: CGPoint(x: width * 0.4, y: height * 0.2))
            path.addLine(to: CGPoint(x: width * 0.4, y: height * 0.4))
            path.addLine(to: CGPoint(x: width * 0.2, y: height * 0.4))
            path.closeSubpath()
        case .left:
            path.move(to: CGPoint(x: width * 0.2, y: height * 0.5))
            path.addLine(to: CGPoint(x: width * 0.6, y: height * 0.2))
            path.addLine(to: CGPoint(x: width * 0.6, y: height * 0.4))
            path.addLine(to: CGPoint(x: width * 0.8, y: height * 0.4))
            path.addLine(to: CGPoint(x: width * 0.8, y: height * 0.6))
            path.addLine(to: CGPoint(x: width * 0.6, y: height * 0.6))
            path.addLine(to: CGPoint(x: width * 0.6, y: height * 0.8))
            path.closeSubpath()
        case .right:
            path.move(to: CGPoint(x: width * 0.8, y: height * 0.5))
            path.addLine(to: CGPoint(x: width * 0.4, y: height * 0.8))
            path.addLine(to: CGPoint(x: width * 0.4, y: height * 0.6))
            path.addLine(to: CGPoint(x: width * 0.2, y: height * 0.6))
            path.addLine(to: CGPoint(x: width * 0.2, y: height * 0.4))
            path.addLine(to: CGPoint(x: width * 0.4, y: height * 0.4))
            path.addLine(to: CGPoint(x: width * 0.4, y: height * 0.2))
            path.closeSubpath()
        }
        
        return path
    }
}
