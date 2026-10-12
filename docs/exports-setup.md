# Local PDF, Excel and printing

T14 adds Save / share PDF, Save / share Excel and Print to current authorized previews and issued-document views. Every action obtains a fresh backend payload before generating bytes. Saving and printing do not issue a document or post money. A preview is labelled not issued; issue it through the separate T13 transaction when permanent numbering is needed.

`prepare_output_export(command)` revalidates current account/office/recipient/preset access, fetches every 50-row page under the existing business lock and returns one coherent, redacted payload. More than 100,000 additional offsets is rejected rather than silently truncating. Issued outputs call `get_issued_document` again and verify its canonical SHA-256 and snapshot equality. Company, issuer, fares, selected field order and formatting come from that immutable snapshot. Later changes affect new documents only.

The renderer accepts schema/template version 1 and the server-owned field catalogue, applies a secondary recipient field denylist and serializes only selected rows, approved metadata and authoritative summaries. No raw source object, request identity, Auth identity, contact-details object or filter ID is embedded. Hiding detail fields never recalculates accounting. Office names, period, date bases, currency and scope remain visible; assigned-office scope is explicitly incomplete business scope.

PDF uses A4 AUTO orientation, with portrait/landscape overrides. Body text is at least 9 pt. Wide tables use ordered sections of three portrait or four landscape detail columns with source-row references, repeated table headings, page numbers and required metadata/summaries. Long strings wrap and use visible continuation rows; a money value appears once per source record in its section. Noto Sans regular/bold fonts are bundled under SIL OFL; exports do not download fonts.

Excel contains one visible Records sheet (or the validated selected sheet name), ordered selected columns, visible scope metadata and canonical summaries, wrapped text, PKR formatting, date styles, frozen headings, autofilter and repeated print titles. Monetary values are written from exact decimal strings. Values beyond Excel's 15-digit numeric precision are stored as canonical text with a visible precision note. Untrusted text is explicitly OOXML inline text, including `=`, `+`, `-`, `@` and HYPERLINK expressions; there are no formulas, external links, comments, hidden sheets/columns or embedded source objects. Wide Excel print areas paginate horizontally instead of scaling unlimited columns to fit.

Windows saves use the native file picker and report success only after the file write. Cancelled save/print operations are not reported as success. Printing submits the generated fixed-layout PDF through the printing plugin; a submitted job is not proof of physical output. Android PDF sharing uses printing's share API; Excel uses share_plus. Device share results and physical paper output remain T19/T20 release checks where hardware is unavailable. Authorization errors never fall back to a previously cached preview. A file deliberately saved by an authorized person cannot subsequently be recalled from their filesystem.

Pinned packages: pdf 3.13.1, printing 5.15.1, archive 4.5.1, crypto 3.0.7 and share_plus 13.3.1. The XLSX writer creates explicit OOXML with archive rather than converting money through a spreadsheet package's floating-point model. Dependencies were checked against official pub.dev package metadata and their published SDK requirements before installation. The lockfile is committed.

Run from the repository root against an empty, isolated local Supabase:

```powershell
python tools/tests/t03_api.py --trips --lifecycle --finance --payments --expenses --corrections --reports --reports-functional --outputs --documents --exports --native-exports
```

The harness supplies synthetic accounts through an ignored temporary configuration, runs `app/integration_test/exports_test.dart` on Windows and deletes the temporary configuration. Independent inspection uses the bundled Python runtime with pypdf/openpyxl. `tools/tests/t14_file_inspection.py` scans actual PDF text/content streams/metadata, ZIP XML and hidden-sheet/row/column state, checks selected order, exact money, minimum PDF font size and actual local privileged values without printing them. Synthetic files and visual QA renders stay under ignored `tools/.local/t14-*-files`.

`tools/tests/t14_virtual_print.ps1` can print ignored synthetic page images through the existing Microsoft Print to PDF printer, with a new output file confined to the synthetic fixture directory. It does not install printers or change defaults. This verifies the Windows virtual spooler path separately from Flutter capability/raster testing, and does not claim physical printing or an exercised interactive Flutter print dialog.
