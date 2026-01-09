package com.example.amber_list.widget

/**
 * Medium Widget Provider (4x2)
 *
 * Inherits all functionality from AmberWidgetProvider.
 * Overrides getWidgetSize() to force MEDIUM layout.
 */
class AmberWidgetMediumProvider : AmberWidgetProvider() {
    override fun getWidgetSize(): WidgetSize = WidgetSize.MEDIUM
}
