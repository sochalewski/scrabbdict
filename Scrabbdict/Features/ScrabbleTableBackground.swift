//
//  Scrabbdict
//  Copyright © 2026 Piotr Sochalewski.
//  Licensed under the Apache License, Version 2.0.
//

import SwiftUI

struct ScrabbleTableBackground: View {
    var body: some View {
        GeometryReader { proxy in
            ZStack {
                tableBase

                ScrabbleCornerBoard(
                    tiles: [
                        ScrabbleBackgroundTile(letter: "S", points: 1, column: 1, row: 1),
                        ScrabbleBackgroundTile(letter: "A", points: 1, column: 0, row: 3)
                    ],
                    bonuses: [
                        ScrabbleBackgroundBonus(column: 2, row: 1, color: Color.TableBackground.bonusBlue),
                        ScrabbleBackgroundBonus(column: 1, row: 4, color: Color.TableBackground.bonusRed)
                    ]
                )
                .frame(width: proxy.size.width * 0.58, height: proxy.size.width * 0.77)
                .rotationEffect(.degrees(-11))
                .position(x: proxy.size.width * 0.28, y: proxy.size.height * 0.17)

                ScrabbleCornerBoard(
                    tiles: [
                        ScrabbleBackgroundTile(letter: "B", points: 3, column: 2, row: 3),
                        ScrabbleBackgroundTile(letter: "L", points: 1, column: 4, row: 4)
                    ],
                    bonuses: [
                        ScrabbleBackgroundBonus(column: 1, row: 4, color: Color.TableBackground.bonusBlue),
                        ScrabbleBackgroundBonus(column: 4, row: 3, color: Color.TableBackground.bonusRed),
                        ScrabbleBackgroundBonus(column: 5, row: 4, color: Color.TableBackground.bonusBlue)
                    ]
                )
                .frame(width: proxy.size.width * 0.60, height: proxy.size.width * 0.80)
                .rotationEffect(.degrees(-11))
                .position(x: proxy.size.width * 0.82, y: proxy.size.height * 0.89)

                centerVeil
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }

    private var tableBase: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color.TableBackground.tableBackgroundTop,
                    Color.TableBackground.tableBackgroundMiddle,
                    Color.TableBackground.tableBackgroundBottom
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            RadialGradient(
                colors: [
                    Color.TableBackground.tableHighlight,
                    .clear
                ],
                center: .center,
                startRadius: 20,
                endRadius: 430
            )
        }
    }

    private var centerVeil: some View {
        RadialGradient(
            colors: [
                Color.TableBackground.tableVeil,
                Color.TableBackground.tableVeilSecondary,
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

    var body: some View {
        GeometryReader { proxy in
            let cell = proxy.size.width / 6

            ZStack(alignment: .topLeading) {
                // Grid cells
                ForEach(0..<6, id: \.self) { column in
                    ForEach(0..<7, id: \.self) { row in
                        RoundedRectangle(cornerRadius: 4.5, style: .continuous)
                            .stroke(
                                Color.TableBackground.boardGrid,
                                lineWidth: 0.8
                            )
                            .background(Color.clear)
                            .frame(width: cell, height: cell)
                            .position(x: CGFloat(column) * cell + cell / 2, y: CGFloat(row) * cell + cell / 2)
                    }
                }

                // Premium bonus squares (blue and red tiles with soft watercolor/stamp glow effect as in the image)
                ForEach(bonuses) { bonus in
                    ZStack {
                        PremiumSquare()
                            .fill(bonus.color)
                            .blur(radius: 2.8) // Soft glow to blend into the board

                        PremiumSquare()
                            .stroke(Color.TableBackground.bonusStroke, lineWidth: 1.0)
                            .blur(radius: 0.6) // Slightly soften the white border
                    }
                    .frame(width: cell * 1.04, height: cell * 1.04)
                    .position(x: CGFloat(bonus.column) * cell + cell / 2, y: CGFloat(bonus.row) * cell + cell / 2)
                }

                // Letter tiles (completely sharp, crisp, and three-dimensional)
                ForEach(tiles) { tile in
                    ScrabbleBackgroundLetterTile(letter: tile.letter, points: tile.points)
                        .frame(width: cell * 0.97, height: cell * 0.97)
                        .position(x: CGFloat(tile.column) * cell + cell / 2, y: CGFloat(tile.row) * cell + cell / 2)
                }
            }
        }
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
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.TableBackground.tileTop,
                                Color.TableBackground.tileBottom
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                // Outer subtle border
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(
                        Color.TableBackground.tileStroke,
                        lineWidth: 0.8
                    )

                // Inner 3D bevel highlight
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                Color.TableBackground.tileHighlight,
                                Color.TableBackground.tileBevelBottom
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
                color: Color.TableBackground.tileShadow,
                radius: 1.5,
                x: 0.5,
                y: 1.0
            )
            .shadow(
                color: Color.TableBackground.tileElevatedShadow,
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
