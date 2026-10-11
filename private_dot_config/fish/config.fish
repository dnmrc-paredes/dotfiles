# Set the Starship config path
set -gx STARSHIP_CONFIG ~/.config/starship/starship.toml

# Initialize Starship for Fish
starship init fish | source

# Initialize Zoxide for Fish
zoxide init fish --cmd cd | source

abbr --add n nvim
abbr --add edf nvim ~/.config/fish/config.fish
abbr --add srcf source ~/.config/fish/config.fish
abbr --add root cd ~
abbr --add las open -a Aerospace
abbr --add cz chezmoi
abbr --add cfgs cd ~/.config
abbr --add p python3

