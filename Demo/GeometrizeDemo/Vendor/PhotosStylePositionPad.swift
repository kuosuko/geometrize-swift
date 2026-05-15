//
//  PhotosStylePositionPad.swift
//  PositionalPadSlider
//
//  Created by Balaji Venkatesh on 27/03/26.
//

import SwiftUI

struct PhotosStylePositionPad: View {
    var config: Config = .init()
    @Binding var position: CGPoint
    /// View Properties
    @State private var rows: [Row] = []
    @State private var activeRow: Int = 0
    @State private var activeColumn: Int = 0
    /// Gesture
    @GestureState private var dragLocation: CGPoint?
    @State private var isDragging: Bool = false
    @State private var touchPointOffset: CGSize = .zero
    var body: some View {
        VStack(spacing: 0) {
            ForEach(rows) { row in
                HStack(spacing: 0) {
                    ForEach(row.columns) { column in
                        Circle()
                            .fill(config.tint)
                            .frame(width: config.circleSize, height: config.circleSize)
                            .opacity(column.opacity)
                            .scaleEffect(column.scale)
                            .frame(width: itemSize, height: itemSize)
                    }
                }
            }
        }
        .frame(width: config.size, height: config.size)
        /// OPTIONAL START:
        //.drawingGroup()
        /// OPTIONAL END:
        .overlay(alignment: .topLeading) {
            /// Touch Point Indicator
            Circle()
                .fill(config.tint)
                .frame(
                    width: isDragging ? config.touchPointSize : config.circleSize * circleZoom,
                    height: isDragging ? config.touchPointSize : config.circleSize * circleZoom
                )
                .offset(touchPointOffset)
                .frame(width: itemSize, height: itemSize)
        }
        .contentShape(.rect)
        .gesture(
            DragGesture(minimumDistance: 0, coordinateSpace: .named("POSITIONALPAD"))
                .updating($dragLocation) { value, out, _ in
                    let location = value.location
                    /// Capping location to match with the itemSize
                    out = .init(
                        x: max(min(location.x, config.size - itemSize / 2), itemSize / 2),
                        y: max(min(location.y, config.size - itemSize / 2), itemSize / 2)
                    )
                }
        )
        .onChange(of: dragLocation) { oldValue, newValue in
            if let newValue {
                /// Dragging
                updateActiveRowAndColumn(location: newValue)
                
                if oldValue == nil {
                    /// Animating First Change
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isDragging = true
                        createAndUpdateRows(location: newValue, isDragging: true)
                        updateTouchPointOffset(location: newValue)
                        translateLocationIntoPosition(location: newValue)
                    }
                } else {
                    /// Regular Update
                    createAndUpdateRows(location: newValue, isDragging: true)
                    withAnimation(.easeInOut(duration: 0)) {
                        updateTouchPointOffset(location: newValue)
                    }
                    translateLocationIntoPosition(location: newValue)
                }
            } else {
                /// Dragging End
                if let oldValue {
                    updateActiveRowAndColumn(location: oldValue)
                    
                    /// Animating Last Change
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isDragging = false
                        createAndUpdateRows(location: oldValue, isDragging: false)
                        updateTouchPointOffset(location: oldValue)
                        translateLocationIntoPosition(location: oldValue)
                    }
                }
            }
        }
        .coordinateSpace(.named("POSITIONALPAD"))
        .onAppear {
            guard rows.isEmpty else { return }
            setupRows()
        }
        .onChange(of: position) { oldValue, newValue in
            if !isDragging {
                /// Update from Outside
                setupRows()
            }
        }
    }
    
    private func setupRows() {
        let cappedPosition = CGPoint(
            x: max(min(position.x, 1), 0),
            y: max(min(position.y, 1), 0)
        )
        let location = translatePositionIntoLocation(position: cappedPosition)
        updateActiveRowAndColumn(location: location)
        updateTouchPointOffset(location: location)
        createAndUpdateRows(location: location, isDragging: false)
    }
    
    private func createAndUpdateRows(location: CGPoint, isDragging: Bool) {
        if rows.isEmpty {
            for row in 0..<config.count {
                var columns: [Column] = []
                for column in 0..<config.count {
                    columns.append(.init(column: column, scale: 0, opacity: 0))
                }
                
                rows.append(.init(row: row, columns: columns))
            }
        }
        
        /// Updating Scale and Opacity based on the location with influcence radius
        for rowItem in rows {
            let row = rowItem.row
            for columnItem in rowItem.columns {
                let column = columnItem.column
                
                let xPos: CGFloat = CGFloat(column) * itemSize
                let yPos: CGFloat = CGFloat(row) * itemSize
                
                let dx: CGFloat = location.x - xPos
                let dy: CGFloat = yPos - location.y
                
                let distance = sqrt(dx * dx + dy * dy)
                let proximity = 1 - max(min(distance / config.influcenceRadius, 1), 0)
                /// Update these values according to your needs!
                let scale: CGFloat = 0.7 + (proximity * 1)
                let opacity: CGFloat = 0.1 + (proximity * 1)
                
                let isActive = activeRow == row || activeColumn == column
                let isZoomed = activeRow == row && activeColumn == column
                
                rows[row].columns[column].scale = isDragging ? scale : (isZoomed ? circleZoom : 1)
                rows[row].columns[column].opacity = isDragging ? opacity : (isActive ? 1 : 0.3)
            }
        }
    }
    
    private func updateActiveRowAndColumn(location: CGPoint) {
        activeColumn = Int((location.x / itemSize))
        activeRow = Int((location.y / itemSize))
    }
    
    private func updateTouchPointOffset(location: CGPoint) {
        let snappedX: CGFloat = CGFloat(activeColumn) * itemSize
        let snappedY: CGFloat = CGFloat(activeRow) * itemSize
        let radius: CGFloat = isDragging ? (itemSize / 2) : 0
        
        touchPointOffset = .init(
            width: (isDragging ? location.x : snappedX) - radius,
            height: (isDragging ? location.y : snappedY) - radius
        )
    }
    
    /// Translating Location into Position(0-1 in x & y)
    private func translateLocationIntoPosition(location: CGPoint) {
        let minValue = itemSize / 2
        let maxValue = config.size - itemSize / 2
        
        let x = (location.x - minValue) / (maxValue - minValue)
        let y = (location.y - minValue) / (maxValue - minValue)
        
        position = .init(
            x: max(0, min(1, x)),
            y: max(0, min(1, y))
        )
    }
    
    /// Translating Position Into Location (0-1 to some x and y location value)
    private func translatePositionIntoLocation(position: CGPoint) -> CGPoint {
        let minValue = itemSize / 2
        let maxValue = config.size - itemSize / 2

        let clampedX = max(0, min(1, position.x))
        let clampedY = max(0, min(1, position.y))

        let x = minValue + clampedX * (maxValue - minValue)
        let y = minValue + clampedY * (maxValue - minValue)

        return CGPoint(x: x, y: y)
    }
    
    /// Positional Pad Config
    struct Config {
        /// NOTE: Don't go above 15!
        var count: Int = 11
        var size: CGFloat = 140
        var tint: Color = Color.white
        var circleSize: CGFloat = 4
        var touchPointSize: CGFloat = 35
        var influcenceRadius: CGFloat = 60
    }
    
    /// Circle Info
    private struct Row: Identifiable {
        var id: String = UUID().uuidString
        var row: Int
        var columns: [Column]
    }
    
    private struct Column: Identifiable {
        var id: String = UUID().uuidString
        var column: Int
        var scale: CGFloat
        var opacity: CGFloat
    }
    
    /// Computed Properties
    private var itemSize: CGFloat {
        config.size / CGFloat(config.count)
    }
    
    private var circleZoom: CGFloat {
        return 3
    }
}
