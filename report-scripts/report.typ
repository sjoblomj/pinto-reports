// Typst template for the accounting reports.
//
// A report document imports this file, applies the `report` show rule and
// calls one of the table functions with the JSON data of the report:
//
//   #import "report.typ": *
//   #show: report.with(report-type: "Balansräkning")
//   #balance-table(json("balansrapport.json"))
//
// The following values are read from the command line (`typst compile --input key=value`):
//   start-of-period, end-of-period, last-verification, organisation-name, organisation-number, logo
//
// The layout is based on the Minimal Invoice LaTeX template from
// https://www.LaTeXTemplates.com (CC BY-NC-SA 4.0).

//---------------------------------------------------------------------------------
//   REPORT SETTINGS
//---------------------------------------------------------------------------------

// The currency code (e.g. "kr" or "USD"), shown after the summations.
// Set to "" if you don't want the code to appear on the report.
#let currency-code = "kr"

// Some currencies output a symbol before the number (e.g. "$") and some
// a suffix after it. Leave empty if not wanted.
#let currency-symbol = ""
#let currency-suffix = ""

// These three can be set in config.yaml. Without an organisation name or an organisation number,
// that line is left out of the reports. The logo must be in the same directory as the report.
#let organisation-name = sys.inputs.at("organisation-name", default: "")
#let organisation-number = sys.inputs.at("organisation-number", default: "")
#let logo = sys.inputs.at("logo", default: "logo.svg")
#let logo-height = 50pt

//---------------------------------------------------------------------------------
//   ADVANCED REPORT SETTINGS
//---------------------------------------------------------------------------------

#let currency-decimals = 2       // The number of decimal places to round currency numbers to
#let group-minimum-digits = 4    // Delimit numbers (e.g. 4000 -> 4 000) when there are this number of digits or more
#let group-separator = "\u{a0}"  // Character to use for delimiting digit groups (non-breaking space)
#let decimal-marker = ","        // Character to use for specifying decimals
#let negative-sign = "\u{2212}"  // Character to put in front of negative numbers

#let fonts = ("Nimbus Sans", "Liberation Sans") // Helvetica lookalikes; the first installed one is used
#let font-size = 10pt

#let cell-inset = (x: 4pt, y: 3.6pt) // Padding inside table cells
#let row-height = 14.4pt             // Height of an empty table row
#let header-fill = luma(85%)         // Background of header rows
#let summary-fill = luma(95%)        // Background of summary rows

//---------------------------------------------------------------------------------
//   NUMBERS
//---------------------------------------------------------------------------------

// Converts a number from the JSON data to a decimal, so that summations are exact.
#let to-decimal(number) = {
  if type(number) == decimal { number }
  else if type(number) == str { decimal(number) }
  else { decimal(str(number)) }
}

#let sum(numbers) = numbers.fold(decimal("0"), (total, number) => total + to-decimal(number))

// Formats a number with digit grouping and a fixed number of decimals, e.g. -1234.5 -> −1 234,50
#let format-number(number, decimals: currency-decimals) = {
  let rounded = calc.round(to-decimal(number), digits: decimals)
  let parts = str(calc.abs(rounded)).split(".")
  let integer = parts.at(0)
  let fraction = parts.at(1, default: "")
  fraction += "0" * (decimals - fraction.len())

  if integer.len() >= group-minimum-digits {
    let groups = ()
    while integer.len() > 3 {
      groups.insert(0, integer.slice(-3))
      integer = integer.slice(0, -3)
    }
    groups.insert(0, integer)
    integer = groups.join(group-separator)
  }

  if rounded < decimal("0") { negative-sign }
  integer
  if decimals > 0 { decimal-marker + fraction }
}

// Outputs a currency number, taking into account negatives and currency symbol positioning
#let money(number) = {
  let formatted = format-number(number)
  if formatted.starts-with(negative-sign) {
    negative-sign + currency-symbol + formatted.slice(negative-sign.len())
  } else {
    currency-symbol + formatted
  }
  currency-suffix
}

// "SUMMA" -> "SUMMA (kr)", unless the currency code is empty
#let with-currency-code(label) = if currency-code == "" { label } else { label + " (" + currency-code + ")" }

//---------------------------------------------------------------------------------
//   NOTES
//---------------------------------------------------------------------------------

// Notes are Typst markup. The report scripts turn $123.45$ into #amount("123.45");
// and @1920@ into #account("1920 - Bank - Plusgiro");
#let note-scope = (
  amount: number => money(number) + if currency-code != "" { "\u{a0}" + currency-code },
  account: name => emph(name),
)

#let note(markup) = {
  if markup != none and markup != "" {
    footnote(eval(markup, mode: "markup", scope: note-scope))
  }
}

//---------------------------------------------------------------------------------
//   PAGE LAYOUT
//---------------------------------------------------------------------------------

#let page-header(report-type) = {
  let start-of-period = sys.inputs.at("start-of-period", default: "")
  let end-of-period = sys.inputs.at("end-of-period", default: "")
  let last-verification = sys.inputs.at("last-verification", default: "")

  grid(
    columns: (1fr, auto),
    align: (left + top, right + horizon),
    {
      block(below: 1.3em, text(size: 1.2em, upper(report-type)))
      if organisation-name != "" [#organisation-name \ ]
      [Räkenskapsperiod: #start-of-period - #end-of-period \ ]
      [Utskrivet: #datetime.today().display("[year]-[month]-[day]") \ ]
      if last-verification != "" [Senaste verifikationsnummer: #last-verification \ ]
      if organisation-number != "" [Organisationsnummer: #organisation-number \ ]
      context [Sida #counter(page).get().first() av #counter(page).final().first()]
    },
    image(logo, height: logo-height),
  )
  v(1em, weak: true)
  line(length: 100%, stroke: 0.4pt)
}

// The document setup. Use as `#show: report.with(report-type: "...")`
#let report(report-type: "", body) = {
  set document(title: report-type)
  set text(font: fonts, size: font-size, lang: "sv")
  set par(leading: 0.48em)
  set page(
    paper: "a4",
    margin: (top: 5cm, bottom: 2.25cm, x: 2cm),
    header-ascent: 8pt,
    header: page-header(report-type),
  )

  // Footnotes are numbered in a column of their own, so show the numbers as normal text
  show footnote: set super(typographic: false, baseline: 0pt, size: 1em)
  set footnote.entry(indent: 0pt, gap: 0.4em)
  show footnote.entry: set text(size: 0.8 * font-size)
  show footnote.entry: it => {
    let number = numbering(it.note.numbering, ..counter(footnote).at(it.note.location()))
    [#number: #it.note.body]
  }

  body
}

//---------------------------------------------------------------------------------
//   TABLE BUILDING BLOCKS
//---------------------------------------------------------------------------------

// Lays out rows (arrays of cells) as a borderless table
#let rows-table(columns, align, rows) = table(
  columns: columns,
  align: align,
  stroke: none,
  inset: cell-inset,
  ..rows.flatten(),
)

// As rows-table, but the first `keep` rows will never be separated by a page break
#let section(columns, align, rows, keep: 2) = {
  let keep = calc.min(keep, rows.len())
  block(breakable: false, rows-table(columns, align, rows.slice(0, keep)))
  if rows.len() > keep {
    rows-table(columns, align, rows.slice(keep))
  }
}

// A row where all cells have the given background
#let filled-row(fill, ..cells) = cells.pos().map(cell => table.cell(fill: fill, cell))

// The row with the column titles
#let title-row(columns, align, ..titles) = {
  rows-table(columns, align.map(alignment => alignment + bottom), (titles.pos().map(strong),))
  v(0.3cm)
}

//---------------------------------------------------------------------------------
//   BALANCE REPORT (balansrapport)
//---------------------------------------------------------------------------------

// data: array of (category, accounts: array of (account, note, start_amount, diff, end_amount))
#let balance-table(data) = {
  set block(spacing: 0pt)
  let columns = (1fr, 6%, 14%, 14%, 14%)
  let align = (left, center, right, right, right)

  title-row(columns, align)[KONTO][NOT][INGÅENDE BALANS][PERIOD][UTGÅENDE BALANS]

  for category in data {
    let accounts = category.accounts
    let rows = (filled-row(header-fill, emph(category.category), [], [], [], []),)
    for account in accounts {
      rows.push((
        account.account,
        note(account.note),
        money(account.start_amount),
        money(account.diff),
        money(account.end_amount),
      ))
    }
    rows.push(filled-row(
      summary-fill,
      strong(with-currency-code("SUMMA")),
      [],
      strong(money(sum(accounts.map(account => account.start_amount)))),
      strong(money(sum(accounts.map(account => account.diff)))),
      strong(money(sum(accounts.map(account => account.end_amount)))),
    ))

    section(columns, align, rows)
    v(row-height + 0.2cm)
  }
}

//---------------------------------------------------------------------------------
//   RESULT REPORT (resultatrapport)
//---------------------------------------------------------------------------------

// data: array of (category, accounts: array of (account, note, amount))
#let result-table(data) = {
  set block(spacing: 0pt)
  let columns = (1fr, 6%, 14%)
  let align = (left, center, right)

  title-row(columns, align)[KONTO][NOT][PERIODEN]

  for category in data {
    let accounts = category.accounts
    let rows = (filled-row(header-fill, emph(category.category), [], []),)
    for account in accounts {
      rows.push((account.account, note(account.note), money(account.amount)))
    }
    rows.push(filled-row(
      summary-fill,
      strong(with-currency-code("SUMMA")),
      [],
      strong(money(sum(accounts.map(account => account.amount)))),
    ))

    section(columns, align, rows)
    v(row-height + 0.2cm)
  }

  let total = sum(data.map(category => sum(category.accounts.map(account => account.amount))))
  v(row-height)
  rows-table(columns, align, (
    filled-row(summary-fill, strong(with-currency-code("RESULTAT")), [], money(total)),
  ))
}

//---------------------------------------------------------------------------------
//   VERIFICATION LIST (verifikationslista)
//---------------------------------------------------------------------------------

// data: array of (vernr, date, description, transactions: array of (account, amount))
#let verification-table(data) = {
  set block(spacing: 0pt)
  let columns = (7%, 13.5%, 1fr, 14%)
  let align = (left, left, left, right)

  title-row(columns, align)[VER. \ NR.][DATUM][TEXT][]

  for verification in data {
    let rows = (
      filled-row(header-fill, str(verification.vernr), verification.date, verification.description, []),
    )
    for transaction in verification.transactions {
      rows.push(([], [], transaction.account, money(transaction.amount)))
    }

    // A verification is never split across pages
    section(columns, align, rows, keep: rows.len())
  }
}

//---------------------------------------------------------------------------------
//   GENERAL LEDGER (huvudbok)
//---------------------------------------------------------------------------------

// data: array of (account, transactions: array of (vernr, date, description, amount)),
// where the first transaction of each account is its opening balance
#let account-table(data) = {
  set block(spacing: 0pt)
  let columns = (7%, 13.5%, 1fr, 14%, 14%)
  let align = (left, left, left, right, right)

  title-row(columns, align)[VER. \ NR.][DATUM][TEXT][][SALDO]

  for account in data {
    let opening = to-decimal(account.transactions.first().amount)
    let transactions = account.transactions.slice(1)
    let balance = opening

    let rows = (
      filled-row(header-fill, [], [], emph(account.account), [], []),
      filled-row(summary-fill, [], [], [INGÅENDE SALDO], [], money(opening)),
    )
    for transaction in transactions {
      balance += to-decimal(transaction.amount)
      rows.push((
        str(transaction.vernr),
        transaction.date,
        transaction.description,
        money(transaction.amount),
        money(balance),
      ))
    }
    rows.push(filled-row(
      summary-fill,
      [],
      [],
      [SUMMA PERIODEN / UTGÅENDE SALDO],
      money(balance - opening),
      money(balance),
    ))

    v(row-height, weak: true)
    // Keep the account name, the opening balance and the row after them together
    section(columns, align, rows, keep: 3)
  }
}
