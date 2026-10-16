# Go (toolchain)

go_desc() { echo "Go toolchain"; }
go_supported() { return 0; }
go_default() { return 1; }

go_status() { status_of brew_satisfied go; }

go_install() {
  brew_bundle go
  case ":$PATH:" in
    *":$HOME/go/bin:"*) ;;
    *) log_info "Los binarios de 'go install' van a ~/go/bin, que no está en el PATH" ;;
  esac
}
