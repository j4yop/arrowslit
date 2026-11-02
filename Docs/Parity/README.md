# Notch parity harness

The harness compares Arrowslit's live notch panel with a committed golden set at fixed states.
The comparison source is Notch Shell **1.4.2**, upstream commit **10a1dfa**
(`https://github.com/shandilyaswagat/arrowslit`). Manual reference captures from the 1.4.2
DMG are in `Docs/Images/dl-142-*.png`; Arrowslit's regression goldens are in
`Docs/Images/Parity-Golden/`.

## Run

```bash
./Scripts/parity.sh            # compare
./Scripts/parity.sh --update   # replace the golden set
```

The script builds a debug `0.10.1` app, launches it, drives the debug states with distributed
notifications, verifies the window size against the layout contract, and captures each panel with
`screencapture -o -l`. It restores the user's defaults when it exits.

## States

`compact`, `home`, `elongated`, `calendar`, `timer`, `stats`, `notes`, `launcher`, `tray`,
`clipboard`, `hud`, `goal`, `nowplaying` and `agent`.

## What the diff proves

- Panel size: expected vs actual, with a 2 pt tolerance.
- Shape/alpha mask: maximum alpha delta and the percentage of changed alpha pixels. Clock, media,
  calendar and other dynamic text can change without a false failure.
- The RGB maximum is reported for review, but dynamic content is not a hard failure.

Glass/backdrop states remain a manual visual review. The golden set is generated on this Mac's
Retina display, so it is a regression baseline rather than a cross-machine pixel oracle.
