-- Extra autostart processes.
-- o.launch_on_start("my-service")

-- Toshy's installer writes ~/.config/autostart/Toshy_Tray.desktop, but Hyprland
-- does not process XDG autostart entries, so the tray never launches.
o.launch_on_start("toshy-tray")
