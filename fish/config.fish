# PATH, lowest precedence first: fish_add_path prepends, and skips a directory
# that does not exist, so a machine without Postgres.app just goes without.
# --path edits PATH itself. Without it, fish_add_path writes the universal
# fish_user_paths, which lands in fish_variables — machine state, not config.
fish_add_path --path /usr/local/bin /usr/local/sbin
if test -x /opt/homebrew/bin/brew
    /opt/homebrew/bin/brew shellenv fish | source
end
fish_add_path --path /Applications/Postgres.app/Contents/Versions/latest/bin

# ASDF configuration code
if test -z "$ASDF_DATA_DIR"
    set _asdf_shims "$HOME/.asdf/shims"
else
    set _asdf_shims "$ASDF_DATA_DIR/shims"
end

# Do not use fish_add_path (added in Fish 3.2) because it
# potentially changes the order of items in PATH
if not contains $_asdf_shims $PATH
    set -gx --prepend PATH $_asdf_shims
end
set --erase _asdf_shims

fish_add_path --path $HOME/.local/bin

# Keep commands that carry a secret out of fish_history, a plain-text file
# that every home-folder backup copies. Defining this function turns off
# fish's own rule that skips a command starting with a space, so the first
# check restores it. A false positive costs one command in history; a miss
# keeps the secret on disk for years.
function fish_should_add_to_history
    string match -qr '^\s' -- $argv; and return 1
    # An assignment whose name holds a secret word: PGPASSWORD=,
    # GITHUB_TOKEN=, STRIPE_KEY=, and ?access_token= or &key= in a URL.
    string match -qir '\w*(password|passwd|token|secret|key)\w*=' -- $argv; and return 1
    # The same names set the fish way: set -gx GITHUB_TOKEN ...
    string match -qir '\bset\s+(-\S+\s+)*\w*(password|passwd|token|secret|key)\w*\s+\S' -- $argv; and return 1
    # A flag that takes the secret as its next word: --access-token abc
    string match -qir -- '--(\w+-)*(token|password|secret|key)\s' $argv; and return 1
    # An HTTP auth header, and curl's -u user:password.
    string match -qir '\b(authorization:|bearer\s)' -- $argv; and return 1
    string match -qr '\s-u\s*[^\s:]+:\S' -- $argv; and return 1
    # A password between the user name and the @ in a URL. Redis leaves the
    # user name empty.
    string match -qr '://[^/\s:@]*:[^/\s@]+@' -- $argv; and return 1
    return 0
end

# Secrets and machine-only settings. This file sits outside the repo, so
# nothing in it can be committed by accident.
if test -f $__fish_config_dir/local.fish
    source $__fish_config_dir/local.fish
end
