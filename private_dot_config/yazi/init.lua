-- Yazi Init Configuration
-- https://yazi-rs.github.io/docs/configuration/init

-- Filesystem usage display in header
require("fs-usage"):setup {
    -- Display format: "both" (name + percentage), "name", or "usage"
    format = "both",
    -- Show usage bar
    bar = true,
    -- Warning threshold percentage (changes color when exceeded)
    warning_threshold = 90,
}

-- Smart enter: open multiple files if selected
-- require("smart-enter"):setup {
--     open_multi = true,
-- }
