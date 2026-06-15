//
//  Scrabbdict
//  Copyright © 2026 Piotr Sochalewski.
//  Licensed under the Apache License, Version 2.0.
//

import SwiftUI

struct ScrabbleTableBackground: View {
    var body: some View {
        GeometryReader { proxy in
            let boardWidth = min(proxy.size.width * 0.60, 340)
            let boardHeight = boardWidth * 7 / 6
            let boardRotation = Angle.degrees(-11)
            let rotationRadians = CGFloat(-11 * Double.pi / 180)
            let cosRotation = cos(rotationRadians)
            let sinRotation = sin(rotationRadians)
            let halfBoardWidth = boardWidth / 2
            let halfBoardHeight = boardHeight / 2
            let topLeftOffset = CGPoint(
                x: cosRotation * -halfBoardWidth - sinRotation * -halfBoardHeight,
                y: sinRotation * -halfBoardWidth + cosRotation * -halfBoardHeight
            )
            let topRightOffset = CGPoint(
                x: cosRotation * halfBoardWidth - sinRotation * -halfBoardHeight,
                y: sinRotation * halfBoardWidth + cosRotation * -halfBoardHeight
            )
            let bottomLeftOffset = CGPoint(
                x: cosRotation * -halfBoardWidth - sinRotation * halfBoardHeight,
                y: sinRotation * -halfBoardWidth + cosRotation * halfBoardHeight
            )
            let bottomRightOffset = CGPoint(
                x: cosRotation * halfBoardWidth - sinRotation * halfBoardHeight,
                y: sinRotation * halfBoardWidth + cosRotation * halfBoardHeight
            )

            ZStack {
                tableBase

                ScrabbleCornerBoard(
                    tiles: [
                        ScrabbleBackgroundTile(letter: "S", points: 1, column: 1, row: 1),
                        ScrabbleBackgroundTile(letter: "A", points: 1, column: 0, row: 3)
                    ],
                    bonuses: [
                        ScrabbleBackgroundBonus(column: 2, row: 1, color: .TableBackground.bonusBlue),
                        ScrabbleBackgroundBonus(column: 1, row: 4, color: .TableBackground.bonusRed)
                    ],
                    gridFade: .topLeading
                )
                .frame(width: boardWidth, height: boardHeight)
                .rotationEffect(boardRotation)
                .position(
                    x: -bottomLeftOffset.x,
                    y: -topLeftOffset.y
                )

                ScrabbleCornerBoard(
                    tiles: [
                        ScrabbleBackgroundTile(letter: "B", points: 3, column: 5, row: 1),
                        ScrabbleBackgroundTile(letter: "L", points: 1, column: 4, row: 4)
                    ],
                    bonuses: [
                        ScrabbleBackgroundBonus(column: 4, row: 3, color: .TableBackground.bonusRed),
                        ScrabbleBackgroundBonus(column: 5, row: 2, color: .TableBackground.bonusBlue)
                    ],
                    gridFade: .bottomTrailing
                )
                .frame(width: boardWidth, height: boardHeight)
                .rotationEffect(boardRotation)
                .position(
                    x: proxy.size.width - topRightOffset.x,
                    y: proxy.size.height - bottomRightOffset.y
                )

                centerVeil
            }
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }
}

private extension ScrabbleTableBackground {
    var tableBase: some View {
        ZStack {
            LinearGradient(
                colors: [
                    .TableBackground.tableBackgroundTop,
                    .TableBackground.tableBackgroundMiddle,
                    .TableBackground.tableBackgroundBottom
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            RadialGradient(
                colors: [
                    .TableBackground.tableHighlight,
                    .clear
                ],
                center: .center,
                startRadius: 20,
                endRadius: 430
            )
        }
    }

    var centerVeil: some View {
        RadialGradient(
            colors: [
                .TableBackground.tableVeil,
                .TableBackground.tableVeilSecondary,
                .clear
            ],
            center: .center,
            startRadius: 40,
            endRadius: 500
        )
    }
}

private struct ScrabbleCornerBoard: View {
    let tiles: [ScrabbleBackgroundTile]
    let bonuses: [ScrabbleBackgroundBonus]
    let gridFade: ScrabbleGridFade

    var body: some View {
        GeometryReader { proxy in
            let cell = proxy.size.width / 6
            let boardWidth = cell * 6
            let boardHeight = cell * 7

            ZStack(alignment: .topLeading) {
                ZStack(alignment: .topLeading) {
                    ForEach(0...7, id: \.self) { row in
                        Path { path in
                            let y = CGFloat(row) * cell
                            path.move(to: CGPoint(x: 0, y: y))
                            path.addLine(to: CGPoint(x: boardWidth, y: y))
                        }
                        .stroke(Color.TableBackground.boardGrid, lineWidth: 0.8)
                    }

                    ForEach(0...6, id: \.self) { column in
                        Path { path in
                            let x = CGFloat(column) * cell
                            path.move(to: CGPoint(x: x, y: 0))
                            path.addLine(to: CGPoint(x: x, y: boardHeight))
                        }
                        .stroke(Color.TableBackground.boardGrid, lineWidth: 0.8)
                    }
                }
                .mask(gridFade.mask)

                ForEach(bonuses) { bonus in
                    ZStack {
                        PremiumSquare()
                            .fill(bonus.color)
                            .blur(radius: 2.8)

                        PremiumSquare()
                            .stroke(Color.TableBackground.bonusStroke, lineWidth: 1.0)
                            .blur(radius: 0.6)
                    }
                    .frame(width: cell * 1.04, height: cell * 1.04)
                    .position(x: CGFloat(bonus.column) * cell + cell / 2, y: CGFloat(bonus.row) * cell + cell / 2)
                }

                ForEach(tiles) { tile in
                    ScrabbleBackgroundLetterTile(letter: tile.letter, points: tile.points)
                        .frame(width: cell * 0.97, height: cell * 0.97)
                        .position(x: CGFloat(tile.column) * cell + cell / 2, y: CGFloat(tile.row) * cell + cell / 2)
                }
            }
        }
    }
}

private enum ScrabbleGridFade {
    case topLeading
    case bottomTrailing

    private var startPoint: UnitPoint {
        switch self {
        case .topLeading:
            .topLeading
        case .bottomTrailing:
            .bottomTrailing
        }
    }

    private var endPoint: UnitPoint {
        switch self {
        case .topLeading:
            .bottomTrailing
        case .bottomTrailing:
            .topLeading
        }
    }

    var mask: some View {
        LinearGradient(
            colors: [.black, .clear],
            startPoint: startPoint,
            endPoint: endPoint
        )
    }
}

private struct ScrabbleBackgroundLetterTile: View {
    let letter: String
    let points: Int

    var body: some View {
        GeometryReader { proxy in
            let cornerRadius = proxy.size.width * 0.14
            ZStack(alignment: .bottomTrailing) {
                // Tile base with ivory gradient
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(
                        LinearGradient(
                            colors: [
                                .TableBackground.tileTop,
                                .TableBackground.tileBottom
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                // Outer subtle border
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(
                        Color.TableBackground.tileStroke,
                        lineWidth: 0.8
                    )

                // Inner 3D bevel highlight
                RoundedRectangle(cornerRadius: cornerRadius)
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                .TableBackground.tileHighlight,
                                .TableBackground.tileBevelBottom
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.2
                    )

                // Letter
                Text(verbatim: letter)
                    .font(.system(size: proxy.size.width * 0.53, weight: .bold))
                    .foregroundStyle(Color.TableBackground.tileInk)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                // Points
                Text(verbatim: "\(points)")
                    .font(.system(size: proxy.size.width * 0.16, weight: .bold))
                    .foregroundStyle(Color.TableBackground.tileInk)
                    .padding(proxy.size.width * 0.10)
            }
            .shadow(
                color: .TableBackground.tileShadow,
                radius: 1.5,
                x: 0.5,
                y: 1.0
            )
            .shadow(
                color: .TableBackground.tileElevatedShadow,
                radius: 7.0,
                x: 1.5,
                y: 3.5
            )
        }
    }
}

private struct PremiumSquare: Shape {
    func path(in rect: CGRect) -> Path {
        let side = min(rect.width, rect.height)
        let toothDepth = side * 0.065
        let toothHalfWidth = side * 0.115
        let cornerRadius = side * 0.032
        let square = rect.insetBy(dx: toothDepth, dy: toothDepth)
        let center = CGPoint(x: square.midX, y: square.midY)
        var path = Path()

        path.move(to: CGPoint(x: square.minX + cornerRadius, y: square.minY))
        path.addLine(to: CGPoint(x: center.x - toothHalfWidth, y: square.minY))
        path.addLine(to: CGPoint(x: center.x, y: rect.minY))
        path.addLine(to: CGPoint(x: center.x + toothHalfWidth, y: square.minY))
        path.addLine(to: CGPoint(x: square.maxX - cornerRadius, y: square.minY))
        path.addArc(
            center: CGPoint(x: square.maxX - cornerRadius, y: square.minY + cornerRadius),
            radius: cornerRadius,
            startAngle: .degrees(-90),
            endAngle: .degrees(0),
            clockwise: false
        )

        path.addLine(to: CGPoint(x: square.maxX, y: center.y - toothHalfWidth))
        path.addLine(to: CGPoint(x: rect.maxX, y: center.y))
        path.addLine(to: CGPoint(x: square.maxX, y: center.y + toothHalfWidth))
        path.addLine(to: CGPoint(x: square.maxX, y: square.maxY - cornerRadius))
        path.addArc(
            center: CGPoint(x: square.maxX - cornerRadius, y: square.maxY - cornerRadius),
            radius: cornerRadius,
            startAngle: .degrees(0),
            endAngle: .degrees(90),
            clockwise: false
        )

        path.addLine(to: CGPoint(x: center.x + toothHalfWidth, y: square.maxY))
        path.addLine(to: CGPoint(x: center.x, y: rect.maxY))
        path.addLine(to: CGPoint(x: center.x - toothHalfWidth, y: square.maxY))
        path.addLine(to: CGPoint(x: square.minX + cornerRadius, y: square.maxY))
        path.addArc(
            center: CGPoint(x: square.minX + cornerRadius, y: square.maxY - cornerRadius),
            radius: cornerRadius,
            startAngle: .degrees(90),
            endAngle: .degrees(180),
            clockwise: false
        )

        path.addLine(to: CGPoint(x: square.minX, y: center.y + toothHalfWidth))
        path.addLine(to: CGPoint(x: rect.minX, y: center.y))
        path.addLine(to: CGPoint(x: square.minX, y: center.y - toothHalfWidth))
        path.addLine(to: CGPoint(x: square.minX, y: square.minY + cornerRadius))
        path.addArc(
            center: CGPoint(x: square.minX + cornerRadius, y: square.minY + cornerRadius),
            radius: cornerRadius,
            startAngle: .degrees(180),
            endAngle: .degrees(270),
            clockwise: false
        )

        path.closeSubpath()
        return path
    }
}

private struct ScrabbleBackgroundTile: Identifiable {
    let id = UUID()
    let letter: String
    let points: Int
    let column: Int
    let row: Int
}

private struct ScrabbleBackgroundBonus: Identifiable {
    let id = UUID()
    let column: Int
    let row: Int
    let color: Color
}

#Preview {
    ScrabbleTableBackground()
}
