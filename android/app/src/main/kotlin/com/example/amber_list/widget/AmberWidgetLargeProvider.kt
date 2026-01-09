package com.example.amber_list.widget

/**
 * Large Widget Provider (4x4)
 *
 * Inherits all functionality from AmberWidgetProvider.
 * Overrides getWidgetSize() to force LARGE layout.
 */
class AmberWidgetLargeProvider : AmberWidgetProvider() {
    override fun getWidgetSize(): WidgetSize = WidgetSize.LARGE
}
