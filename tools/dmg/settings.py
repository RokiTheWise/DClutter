"""Finder layout for the drag-to-Applications disk image."""

from pathlib import Path

application = Path(defines["app"])  # Provided by dmgbuild's -D option.
project = Path(defines["project"])

format = "UDZO"
filesystem = "HFS+"
files = [
    str(application),
    (str(project / "tools/dmg/INSTALLATION.txt"), "READ ME FIRST.txt"),
    str(project / "LICENSE"),
]
symlinks = {"Applications": "/Applications"}
hide = ["LICENSE"]
hide_extensions = ["READ ME FIRST.txt"]
icon = str(application / "Contents/Resources/AppIcon.icns")
background = "builtin-arrow"
window_rect = ((200, 200), (640, 440))
default_view = "icon-view"
show_toolbar = False
show_sidebar = False
show_status_bar = False
show_pathbar = False
show_tab_view = False
show_icon_preview = True
arrange_by = None
icon_size = 96
text_size = 14
icon_locations = {
    "DClutter.app": (140, 120),
    "Applications": (500, 120),
    "READ ME FIRST.txt": (320, 270),
}
