# powerlevel10k (prompt). La config está en zsh/.p10k.zsh

p10k_desc() { echo "powerlevel10k lean · 2 líneas · iconos nerd font"; }
p10k_supported() { return 0; }
p10k_default() { return 0; }

p10k_status() { status_of brew_satisfied p10k; }

p10k_install() { brew_bundle p10k; }
