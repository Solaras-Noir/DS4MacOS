# Fixtures

Raw input report captures from a real controller, written by `ds4probe dump`.

- Files are named `usb-<label>.hex` or `bt-<label>.hex`.
- Line 1 is a comment:
  `# transport=USB label=<label> date=<ISO 8601> maxInputReportSize=<n>`
- Every other line is one input report exactly as the IOKit callback delivered it: the callback's
  `reportID` argument as two hex digits, a space, then the report buffer as space-separated
  two-digit lowercase hex bytes. If the buffer includes the report ID in byte 0, the ID appears
  twice on the line; that is intended.
- `dump` creates or overwrites the file, never appends. Blank lines are ignored.
