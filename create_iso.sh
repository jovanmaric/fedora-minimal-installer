#!/usr/bin/env bash

set -eo pipefail

RED=$'\e[0;31m'
GREEN=$'\e[0;32m'
YELLOW=$'\e[1;33m'
NC=$'\e[0m'

ROOT_DIR="$(readlink -f "$(dirname "$0")")"

FEDORA_URL=""
ADD_PACKAGES=()
REMOVE_PACKAGES=()

usage() {
  cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Options:
  --fedora-url <url>         URL for base Fedora ISO (required)
  --add-packages <pkg...>    Space-separated packages to add (e.g., git vim curl)
  --remove-packages <pkg...> Space-separated packages to remove (e.g., nano)
  --help                     Show this help message
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --help)
      usage
      exit 0
      ;;
    --fedora-url)
      FEDORA_URL="$2"
      shift 2
      ;;
    --add-packages)
      shift
      while [[ $# -gt 0 && "$1" != -* ]]; do
        ADD_PACKAGES+=("$1")
        shift
      done
      ;;
    --remove-packages)
      shift
      while [[ $# -gt 0 && "$1" != -* ]]; do
        REMOVE_PACKAGES+=("$1")
        shift
      done
      ;;
    *)
      echo -e "${RED}Unknown argument: $1${NC}" >&2
      usage >&2
      exit 1
      ;;
  esac
done

if [ -z "$FEDORA_URL" ]; then
  echo -e "${RED}Error: --fedora-url is required.${NC}" >&2
  exit 1
fi

# Cleanup previous run.
echo -e "\n${YELLOW}  • Cleanup \`.dist\` and \`.build\`...${NC}"
rm -rf "$ROOT_DIR/.dist/"* \
       "$ROOT_DIR/.build/"* \
       || true
mkdir -p "$ROOT_DIR/.build" "$ROOT_DIR/.dist"
echo -e "    Cleanup done!"

# Render kickstart config (1 package per line with indentation).
echo -e "\n${YELLOW}  • Rendering kickstart config...${NC}"
ADD_PKGS_STR=""
for pkg in "${ADD_PACKAGES[@]}"; do
  ADD_PKGS_STR+="  $pkg"$'\n'
done

REMOVE_PKGS_STR=""
for pkg in "${REMOVE_PACKAGES[@]}"; do
  REMOVE_PKGS_STR+="  -$pkg"$'\n'
done

awk -v add="$ADD_PKGS_STR" -v rem="$REMOVE_PKGS_STR" '
  /\{\{ add_packages \}\}/    { printf "%s", add; next }
  /\{\{ remove_packages \}\}/ { printf "%s", rem; next }
  { print }
' "$ROOT_DIR/ks.cfg.template" > "$ROOT_DIR/.build/ks.cfg"
echo -e "    Render done!"

# Validate rendered ks.cfg.
if ! ksvalidator "$ROOT_DIR/.build/ks.cfg" &> /dev/null; then
  echo -e "${RED}\`ks.cfg\` is invalid. Run \`ksvalidator $ROOT_DIR/.build/ks.cfg\` to verify.${NC}"
  exit 1
fi
echo -e "${GREEN}    Validation passed!${NC}"

# Download base ISO.
echo -e "\n${YELLOW}  • Downloading base ISO...${NC}"
curl -L --fail --progress-bar "$FEDORA_URL" -o "$ROOT_DIR/.build/fedora.iso"

if ! file "$ROOT_DIR/.build/fedora.iso" | grep -qi "ISO 9660"; then
  echo -e "${RED}    Error: Downloaded file is not a valid ISO 9660 image (check URL/redirect).${NC}" >&2
  exit 1
fi
echo -e "${GREEN}    Download complete!${NC}"

# Add file to `.iso`.
echo -e "\n${YELLOW}  • Building custom ISO...${NC}"
mkksiso --ks "$ROOT_DIR/.build/ks.cfg" \
             "$ROOT_DIR/.build/fedora.iso" \
             "$ROOT_DIR/.dist/fedora.iso" || {
  echo -e "${RED}    ISO build command failed with exit code $?${NC}" >&2
  exit 1
}

if [ ! -s "$ROOT_DIR/.dist/fedora.iso" ]; then
  echo -e "${RED}    Error: Output ISO is missing or empty!${NC}" >&2
  exit 1
fi

# Done!
echo -e "${GREEN}    ISO generation complete!${NC}"
