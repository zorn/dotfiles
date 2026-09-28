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
if test -z $ASDF_DATA_DIR
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

# Make it so we always open from Cursor classic.
alias c 'cursor --classic'

# Secrets and machine-only settings. This file sits outside the repo, so
# nothing in it can be committed by accident.
if test -f $__fish_config_dir/local.fish
    source $__fish_config_dir/local.fish
end
