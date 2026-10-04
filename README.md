# iconize

A Bash script that optimizes and converts image files (`.svg`, `.png`, etc.) into tiny `.ico` files using multiple compression strategies and automated candidate selection.

## Features

- **Multi-method optimization**: Evaluates `icotool` and several ImageMagick PNG/BMP3/Zip modes in parallel to pick the smallest resulting file.
- **Batch processing**: Converts multiple files in a single execution without halting on individual errors.
- **Automatic PNG optimization**: Uses `pngquant` for palette reduction and metadata stripping before icon packaging.
- **Custom sizing**: Defaults to **256x256 px** (ideal for KDE Dolphin, desktop folders, and KeePassXC), with full support for custom pixel sizes.
- **GNU/FSF compliant**: Includes standard CLI options (`--help`, `--version`) and formatted tabular output.
- **Noexec friendly**: Can be run via `bash iconize.sh` on partitions mounted with `noexec` (e.g., NTFS mounts).

## Dependencies

Required tools:
- `bash` (v4.0+)
- `imagemagick` (`magick` or `convert`)
- `pngquant`

Optional (recommended):
- `icoutils` (`icotool` — enables direct PNG-in-ICO packaging)
- `coreutils` (`numfmt` — human-readable file sizes)

### Installation of dependencies

On Debian / Ubuntu:

  sudo apt update
  sudo apt install imagemagick pngquant icoutils coreutils

## Usage

  iconize [OPTIONS] <file1> [file2 ...]

### Options

| Option | Description |
| :--- | :--- |
| `-s, --size SIZE` | Target icon resolution in pixels (default: `256`) |
| `-a, --all-methods` | Keep every valid method output, named `<file>.<method>.ico` |
| `-v, --verbose` | Display step-by-step candidate size evaluations |
| `-h, --help` | Display usage instructions and exit |
| `--version` | Display version and license information |

### Examples

Convert a single SVG file using default 256x256 resolution:

  bash iconize.sh app-logo.svg

Batch convert multiple files to 64x64 px with verbose output:

  bash iconize.sh -s 64 -v *.png *.svg

Keep every valid conversion method output:

  bash iconize.sh --all-methods foo.svg

This creates files such as `foo.im_png.ico`, `foo.im_bmp3.ico`, and `foo.im_zip.ico` (plus `foo.icotool.ico` when `icotool` is available).

## License

This project is licensed under the **GNU General Public License v3.0 or later** (GPLv3+). See the `LICENSE` file for full terms.
