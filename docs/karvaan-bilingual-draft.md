# Karvaan — Bilingual Implementation Draft

For Codex. Locked decision (2026-10-13): **bilingual everywhere, side-by-side — English left, Urdu right.**
App UI, printed receipts/PDFs, Excel. No language toggle, no RTL layout flip. **Digits always Latin**
(125,000 — never ۱۲۵۰۰۰). Translations: `bilingual-glossary.md` (same folder).

## Why no intl/ARB

There is no language switch, so `flutter_localizations` + ARB is machinery with no payoff.
A plain Dart string table is simpler, greppable, and Codex-friendly. If a toggle is ever wanted
later, the table migrates to ARB 1:1.

## Step 1 — Add `lib/app/bilingual.dart`

One string table + one widget. Everything else builds on these two.

```dart
import 'package:flutter/material.dart';

/// One UI string in both languages. Source of truth: bilingual-glossary.md
class Bilingual {
  final String en;
  final String ur;
  const Bilingual(this.en, this.ur);
}

/// Central table. Add entries as you extract hardcoded strings (Step 3).
/// Keep keys in SCREAMING_SNAKE matching the English text.
class L10n {
  static const receipt = Bilingual('Receipt', 'رسید');
  static const bilty = Bilingual('Bilty / Goods Receipt', 'بلٹی');
  static const invoice = Bilingual('Invoice', 'بل');
  static const paymentReceipt = Bilingual('Payment Receipt', 'ادائیگی کی رسید');
  static const trip = Bilingual('Trip', 'ٹرپ');
  static const consignment = Bilingual('Consignment', 'کنسائنمنٹ'); // confirm word with office (glossary note 1)
  static const dispatchDate = Bilingual('Dispatch date', 'روانگی کی تاریخ');
  static const arrivalDate = Bilingual('Arrival date', 'آمد کی تاریخ');
  static const vehicle = Bilingual('Vehicle', 'گاڑی');
  static const driver = Bilingual('Driver', 'ڈرائیور');
  static const fare = Bilingual('Fare', 'کرایہ');
  static const totalFare = Bilingual('Total fare', 'کل کرایہ');
  static const commission = Bilingual('Commission', 'کمیشن');
  static const balance = Bilingual('Balance', 'بقایا');
  static const paid = Bilingual('Paid', 'ادا شدہ');
  static const received = Bilingual('Received', 'وصول شدہ');
  static const settlement = Bilingual('Settlement', 'تصفیہ');
  static const save = Bilingual('Save', 'محفوظ کریں');
  static const cancel = Bilingual('Cancel', 'منسوخ کریں');
  static const search = Bilingual('Search', 'تلاش کریں');
  static const print_ = Bilingual('Print', 'پرنٹ کریں');
  static const dashboard = Bilingual('Dashboard', 'ڈیش بورڈ');
  static const trips = Bilingual('Trips', 'ٹرپس');
  static const reports = Bilingual('Reports', 'رپورٹس');
  static const settings = Bilingual('Settings', 'ترتیبات');
  // ... continue per bilingual-glossary.md
}

/// Bilingual label: English left, Urdu right. The app stays LTR;
/// the Urdu run renders its own RTL inside its Text widget.
class BilingualText extends StatelessWidget {
  final Bilingual text;
  final TextStyle? enStyle;
  final TextStyle? urStyle;

  const BilingualText(this.text, {super.key, this.enStyle, this.urStyle});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Expanded(child: Text(text.en, style: enStyle, textAlign: TextAlign.left)),
        const SizedBox(width: 12),
        Expanded(
          child: Text(text.ur,
              style: urStyle,
              textAlign: TextAlign.right,
              textDirection: TextDirection.rtl),
        ),
      ],
    );
  }
}

/// Compact variant for table headers / dense rows: stacked instead of side-by-side.
class BilingualCaption extends StatelessWidget {
  final Bilingual text;
  final TextStyle? enStyle;
  final TextStyle? urStyle;

  const BilingualCaption(this.text, {super.key, this.enStyle, this.urStyle});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(text.en, style: enStyle),
        Text(text.ur, style: urStyle, textDirection: TextDirection.rtl),
      ],
    );
  }
}
```

Usage:

```dart
// before
Text('Dispatch date')
// after
BilingualText(L10n.dispatchDate)

// table headers (dense): use BilingualCaption
BilingualCaption(L10n.vehicle)
```

## Step 2 — Font

Body text: **Noto Sans Arabic** (naskh-style — far more readable than Nastaliq at UI sizes;
glossary note 5). Optional: **Noto Nastaliq Urdu** for printed document headers only.

`pubspec.yaml`:

```yaml
flutter:
  fonts:
    - family: NotoSansArabic
      fonts:
        - asset: assets/fonts/NotoSansArabic-Regular.ttf
        - asset: assets/fonts/NotoSansArabic-Bold.ttf
          weight: 700
```

Set as default in `MaterialApp.theme` (`fontFamily: 'NotoSansArabic'`) — it covers Latin too,
so English text is unaffected. Watch installer size (+~1 MB per weight is fine; Nastaliq is
much heavier — keep it out of the app bundle unless headers demand it).

## Step 3 — Extract the ~200 hardcoded strings

`strings.dart` currently holds 2 strings; ~200 `Text('...')` are hardcoded across `lib/`.
Work file-by-file:

1. Add the pair to `L10n` (English must match the existing text exactly — no rewording
   while extracting; rewording is a separate review).
2. Replace `Text('...')` with `BilingualText(L10n.x)` — or `BilingualCaption` in tables,
   data-table headers, and anywhere horizontal space is tight (Android especially).
3. Numbers, dates, PKR amounts: **do not touch** — Latin digits stay as-is everywhere.

Do NOT flip any layout to RTL. No `Directionality` changes. The chrome stays LTR.

## Step 4 — PDFs (receipts, invoices, statements)

Keep the existing LTR template. For each text element, add the Urdu run next to/below the
English (mirror the `BilingualText`/`BilingualCaption` pattern in the PDF builder).
**Embed the Urdu font in the PDF** — otherwise receipts print as boxes on machines
without the font (glossary implementation hints). Check the font license allows embedding
(Noto fonts do).

## Step 5 — Excel

Urdu exports as plain text cells — no special handling. The existing safe-inline-strings
rule (T18 gate) already neutralizes formula injection; Urdu text doesn't change that.

## Step 6 — QA checklist

- [ ] Every screen visited in Urdu-visible state — no leftover English-only hardcoded strings
      (`grep -rn "Text('" lib --include="*.dart"` should return ~0 UI strings)
- [ ] Long Urdu strings don't overflow on the narrowest supported window (test 1280px + Android)
- [ ] Tables: `BilingualCaption` headers readable, columns not squeezed
- [ ] PDF printed from a machine WITHOUT the Urdu font installed — must not show boxes
- [ ] Amounts everywhere render in Latin digits, including inside Urdu sentences
- [ ] Excel export opens with Urdu intact (UTF-8, no mojibake)

## Open questions for the office (from glossary notes)

1. **Consignment** → کنسائنمنٹ or مال (what they actually write on bilties)?
2. **Bearer / custody** Urdu words — confirm what the office calls these before printing.
3. **Brokerage** on documents: کمیشن (recommended) or بروکریج?

## Out of scope for this update

Language toggle, full RTL mode, Urdu input (typing), translating historical/issued documents
(snapshots stay as-issued — immutability rule).
