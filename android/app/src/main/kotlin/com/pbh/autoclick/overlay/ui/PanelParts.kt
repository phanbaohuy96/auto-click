package com.pbh.autoclick.overlay.ui

import androidx.compose.foundation.layout.size
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.vector.ImageVector

/** OV-38: every icon button in the panel is this one, so a row of them has one rhythm. */
@Composable
internal fun PanelIconButton(
    onClick: () -> Unit,
    icon: ImageVector,
    description: String?,
    modifier: Modifier = Modifier,
    enabled: Boolean = true,
) {
    IconButton(onClick = onClick, enabled = enabled, modifier = modifier.size(PANEL_ICON_BUTTON)) {
        Icon(imageVector = icon, contentDescription = description, modifier = Modifier.size(PANEL_ICON))
    }
}

/** OV-38: what a section of the panel is called, in the one style they all share. */
@Composable
internal fun PanelSectionLabel(
    text: String,
    modifier: Modifier = Modifier,
) {
    Text(
        text = text,
        style = MaterialTheme.typography.labelMedium,
        color = MaterialTheme.colorScheme.onSurfaceVariant,
        modifier = modifier,
    )
}
