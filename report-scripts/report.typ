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
#let group-separator = "\u{a0}"  // Character to use for delimiting digit groups (non-breaking space)
#let decimal-marker = ","        // Character to use for specifying decimals
#let negative-sign = "\u{2212}"  // Character to put in front of negative numbers

#let fonts = ("Nimbus Sans", "Liberation Sans") // Helvetica lookalikes; the first installed one is used
#let font-size = 10pt

#let cell-inset = (x: 4pt, y: 3.6pt) // Padding inside table cells
#let section-gap = 0.7cm             // Space between the sections of a report
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
#let money(number) = {
  let rounded = calc.round(to-decimal(number), digits: currency-decimals)
  let (integer, ..fraction) = str(calc.abs(rounded)).split(".")
  let groups = integer.rev().clusters().chunks(3).map(group => group.join()).join(group-separator).rev()
  let fraction = fraction.at(0, default: "")

  if rounded < 0 { negative-sign }
  groups
  if currency-decimals > 0 { decimal-marker + fraction + "0" * (currency-decimals - fraction.len()) }
}

// Splits an amount into the cells of a debit and a credit column: what is positive is debit, and
// what is negative is credit.
#let debit-credit(number) = {
  let amount = to-decimal(number)
  if amount < 0 { ([], money(-amount)) } else { (money(amount), []) }
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
  show footnote.entry: set text(size: 0.8 * font-size)

  body
}

//---------------------------------------------------------------------------------
//   TABLE BUILDING BLOCKS
//---------------------------------------------------------------------------------

// A borderless table
#let plain-table(columns, align, ..cells) = table(
  columns: columns,
  align: align,
  stroke: none,
  inset: cell-inset,
  ..cells,
)

// A report is one table, whose column titles are repeated on every page
#let report-table(columns, align, titles, ..rows) = plain-table(
  columns,
  align,
  table.header(..titles.map(title => table.cell(align: bottom, strong(title)))),
  ..rows.pos().flatten(),
)

// A row where all cells have the given background
#let filled-row(fill, ..cells) = cells.pos().map(cell => table.cell(fill: fill, cell))

// The first rows of a section, which are kept on the same page as the row after them
#let section-header(..rows) = table.header(level: 2, repeat: false, ..rows.pos().flatten())

// An empty row between sections
#let gap(columns) = table.cell(colspan: columns.len(), inset: 0pt, v(section-gap))

//---------------------------------------------------------------------------------
//   BALANCE REPORT (balansrapport)
//---------------------------------------------------------------------------------

// data: array of (category, accounts: array of (account, note, start_amount, diff, end_amount))
#let balance-table(data) = {
  let columns = (1fr, 6%, 14%, 14%, 14%)
  let total(accounts, key) = strong(money(sum(accounts.map(account => account.at(key)))))

  report-table(
    columns,
    (left, center, right, right, right),
    ([KONTO], [NOT], [INGÅENDE BALANS], [PERIOD], [UTGÅENDE BALANS]),
    ..data.map(((category, accounts)) => (
      section-header(filled-row(header-fill, emph(category), [], [], [], [])),
      accounts.map(account => (
        account.account,
        note(account.note),
        money(account.start_amount),
        money(account.diff),
        money(account.end_amount),
      )),
      filled-row(
        summary-fill,
        strong(with-currency-code("SUMMA")),
        [],
        total(accounts, "start_amount"),
        total(accounts, "diff"),
        total(accounts, "end_amount"),
      ),
      gap(columns),
    )),
  )
}

//---------------------------------------------------------------------------------
//   RESULT REPORT (resultatrapport)
//---------------------------------------------------------------------------------

// data: array of (category, accounts: array of (account, note, amount))
#let result-table(data) = {
  let columns = (1fr, 6%, 14%)
  let total(accounts) = sum(accounts.map(account => account.amount))

  report-table(
    columns,
    (left, center, right),
    ([KONTO], [NOT], [PERIODEN]),
    ..data.map(((category, accounts)) => (
      section-header(filled-row(header-fill, emph(category), [], [])),
      accounts.map(account => (account.account, note(account.note), money(account.amount))),
      filled-row(summary-fill, strong(with-currency-code("SUMMA")), [], strong(money(total(accounts)))),
      gap(columns),
    )),
    filled-row(
      summary-fill,
      strong(with-currency-code("RESULTAT")),
      [],
      money(sum(data.map(category => total(category.accounts)))),
    ),
  )
}

//---------------------------------------------------------------------------------
//   VERIFICATION LIST (verifikationslista)
//---------------------------------------------------------------------------------

// data: array of (vernr, date, description, transactions: array of (account, amount))
#let verification-table(data) = {
  let columns = (7%, 13.5%, 1fr, 14%, 14%)
  let align = (left, left, left, right, right)

  report-table(
    columns,
    align,
    ([VER.], [DATUM], [TEXT], [DEBET], [KREDIT]),
    // A verification is a table in a single cell, so that it is never split across pages
    ..data.map(verification => table.cell(
      colspan: columns.len(),
      inset: 0pt,
      breakable: false,
      plain-table(
        columns,
        align,
        ..filled-row(header-fill, str(verification.vernr), verification.date, verification.description, [], []),
        ..verification.transactions.map(transaction => (
          [],
          [],
          transaction.account,
          ..debit-credit(transaction.amount),
        )).flatten(),
      ),
    )),
  )
}

//---------------------------------------------------------------------------------
//   GENERAL LEDGER (huvudbok)
//---------------------------------------------------------------------------------

// data: array of (account, transactions: array of (vernr, date, description, amount)),
// where the first transaction of each account is its opening balance. The balance is
// debit minus credit, so the accounts of liabilities and income are negative.
#let account-table(data) = {
  let columns = (7%, 13.5%, 1fr, 13%, 13%, 14%)

  report-table(
    columns,
    (left, left, left, right, right, right),
    ([VER.], [DATUM], [TEXT], [DEBET], [KREDIT], [SALDO]),
    ..data.map(account => {
      let amounts = account.transactions.map(transaction => to-decimal(transaction.amount))
      let opening = amounts.remove(0)
      let balance = opening

      (section-header(
        filled-row(header-fill, [], [], emph(account.account), [], [], []),
        filled-row(summary-fill, [], [], [INGÅENDE SALDO], [], [], money(opening)),
      ),)
      for (transaction, amount) in account.transactions.slice(1).zip(amounts) {
        balance += amount
        (str(transaction.vernr), transaction.date, transaction.description, ..debit-credit(amount), money(balance))
      }
      filled-row(
        summary-fill,
        [],
        [],
        [OMSLUTNING / UTGÅENDE SALDO],
        money(sum(amounts.filter(amount => amount > 0))),
        money(-sum(amounts.filter(amount => amount < 0))),
        money(balance),
      )
      (gap(columns),)
    }),
  )
}
