# SPDX-FileCopyrightText: Amolith <amolith@secluded.site>
#
# SPDX-License-Identifier: Unlicense

Output demo.gif

Require echo
Require fish

Set Shell "fish"
Set FontSize 32
Set Width 1250
Set Height 750

# Set up the plugin
Hide
Type@1ms "source fish/functions/synu.fish" Enter
Type@1ms "source fish/functions/_synu_get_quota.fish" Enter
Type@1ms "source fish/functions/_synu_cache.fish" Enter
Type@1ms "clear" Enter
Show

# Start interactive model selection
Type "synu i claude" Sleep 750ms
Enter Sleep 2s

# Select Group
Sleep 750ms
Enter Sleep 2s

# Select light group
Down Sleep 250ms
Down Sleep 500ms
Space Sleep 750ms
Enter Sleep 2s

# Select the Haiku model
Type "dsv31t" Sleep 1.25s
Enter Sleep 2s

# Don't save as default
Right Sleep 750ms
Enter Sleep 2.25s

# Send a message
Type "Hi!" Sleep 1.25s
Enter Sleep 4s

# Exit with Ctrl+C twice
Ctrl+c
Sleep 500ms
Ctrl+c

# Show usage
Sleep 5s
