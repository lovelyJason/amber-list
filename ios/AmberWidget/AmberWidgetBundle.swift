//
//  AmberWidgetBundle.swift
//  AmberWidget
//
//  琥珀清单 iOS Widget Extension 入口
//  注册三种尺寸的 Widget: Small (2x2), Medium (4x2), Large (4x4)
//

import WidgetKit
import SwiftUI

@main
struct AmberWidgetBundle: WidgetBundle {
    var body: some Widget {
        // Small Widget (2x2) - 任务列表，支持皮肤切换
        SmallAmberWidget()

        // Medium Widget (4x2) - 左侧日期，右侧任务列表
        MediumAmberWidget()

        // Large Widget (4x4) - 月历视图
        LargeAmberWidget()
    }
}
