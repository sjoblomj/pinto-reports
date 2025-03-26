%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Minimal Invoice
% LaTeX Class
% Version 1.1 (April 22, 2022)
%
% This class originates from:
% https://www.LaTeXTemplates.com
%
% Author:
% Vel (vel@latextemplates.com)
%
% License:
% CC BY-NC-SA 4.0 (https://creativecommons.org/licenses/by-nc-sa/4.0/)
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%----------------------------------------------------------------------------------------
%   CLASS CONFIGURATION
%----------------------------------------------------------------------------------------

\NeedsTeXFormat{LaTeX2e}
\ProvidesClass{CSMinimalInvoice}[2022/04/22 Creodocs Minimal Invoice Class v1.1]

\DeclareOption*{\PassOptionsToClass{\CurrentOption}{extarticle}} % Pass through any extra options specified to the base class
\ProcessOptions\relax % Process class options

\LoadClass{extarticle} % Load the base class

%----------------------------------------------------------------------------------------
%   REQUIRED PACKAGES AND MISC CONFIGURATIONS
%----------------------------------------------------------------------------------------

\usepackage{fp} % Required for report calculations

\usepackage[ % Required for automatically formatting numbers with \num{}, such as adding commas for numbers like: 1200 -> 1,200
  detect-all, text-rm, % Detect the weight, family and shape of the current font and match it when outputting a number with \num{}
]{siunitx}

\usepackage{setspace} % Required to enable changing line spacing

\usepackage{etoolbox} % Required for conditional logic and easily changing commands

\usepackage[hidelinks]{hyperref} % For clickable links (e.g. emails and URLs)

\usepackage{lastpage}
\usepackage{fancyhdr}
\pagestyle{fancy}

\newlength{\negativesign}
\settowidth{\negativesign}{--} % Calculate and save the width of the negative sign for subtraction

\setlength\parindent{0pt} % Stop paragraph indentation

\usepackage[table]{xcolor}

\usepackage{xparse}

\usepackage{graphicx} % For logo

\usepackage[document]{ragged2e} % Left align all text in the document (i.e. have a ragged right margin)

\usepackage[yyyymmdd]{datetime}
\renewcommand{\dateseparator}{-}

%----------------------------------------------------------------------------------------
%   HEADER
%----------------------------------------------------------------------------------------

\fancyhf{}
\fancyhead[L]{
    {\large\MakeUppercase{\reporttype{}}} % Document title

    \vspace{0.01\textheight} % Vertical whitespace

    Räkenskapsperiod: \startofperiod{} - \endofperiod{}\\
    Utskrivet: \today\\
    \ifdefempty{\lastverification}{}{Senaste verifikationsnummer: \lastverification{}\\}
    Organisationsnummer: 123456-7890\\
    Sida \thepage{} av \pageref{LastPage}
}
\fancyhead[R]{
    \vspace{10pt}
    \hfill\parbox{.01\textwidth}{
        \includegraphics[height=50pt]{logo.eps}
    }
}
\renewcommand{\headrule}{\hbox to\textwidth{%
  \leaders\hrule height \headrulewidth\hfill}}


%----------------------------------------------------------------------------------------
%   MARGINS
%----------------------------------------------------------------------------------------

\usepackage[
    top=5cm, % Top margin
    bottom=2.25cm, % Bottom margin
    left=2cm, % Left margin
    right=2cm, % Right margin
    %showframe % Uncomment to show frames around the margins for debugging purposes
    headheight=2.5cm,% Height of header
]{geometry}


%----------------------------------------------------------------------------------------
%   FOOTNOTES
%----------------------------------------------------------------------------------------

\makeatletter
\renewcommand\@makefnmark{\normalfont\@thefnmark}

\renewcommand{\@makefntext}[1]{%
  \parindent 1em\noindent  % Indent the footnote text
  \@makefnmark{}:\hspace{0.1em} #1}
\makeatother

%----------------------------------------------------------------------------------------
%   FONTS
%----------------------------------------------------------------------------------------

\usepackage[utf8]{inputenc} % Required for inputting international characters
\usepackage[T1]{fontenc} % Output font encoding for international characters

\usepackage[default]{lato} % Use the Lato sans serif font

\usepackage{textcomp} % Required for currency symbols
\usepackage{tfrupee}  % Required for the rupee symbol

%----------------------------------------------------------------------------------------
%   TABLES
%----------------------------------------------------------------------------------------

\usepackage{longtable} % Required for tables that can span multiple pages
\setlength{\LTpre}{0pt}  % Whitespace above longtables
\setlength{\LTpost}{0pt} % Whitespace below longtables
\setlength{\LTleft}{0pt} % Whitespace to the left of longtables

%----------------------------------------

\usepackage{array} % Required for manipulating table columns

\renewcommand{\arraystretch}{1.2} % Increase the space between table rows

\newcolumntype{R}[1]{>{\raggedleft\arraybackslash}p{#1}} % Define a new right-aligned column type
\newcolumntype{L}[1]{>{\raggedright\arraybackslash}p{#1}} % Define a new left-aligned (no justification) column type
\newcolumntype{C}[1]{>{\centering\arraybackslash}p{#1}} % Define a new centered column type

%----------------------------------------

\setlength{\tabcolsep}{4pt} % Decrease default padding between columns (6pt is the default)

%----------------------------------------------------------------------------------------
%   DETERMINE CURRENCY SYMBOL
%----------------------------------------------------------------------------------------

\newcommand{\currencysymbol}{} % The default currency symbol is nothing
%\newcommand{\currencysymbol}{\$} % The default currency symbol is a dollar sign

\newcommand{\determinecurrencysymbol}[1]{ % Uses the user-submitted currency to determine the symbol to use
    \expandafter\ifstrequal\expandafter{#1}{GBP}{\renewcommand{\currencysymbol}{\textsterling}}{} % GBP (English pounds)

    \ifboolexpr{ test {\expandafter\ifstrequal\expandafter{#1}{JPY}} or test {\expandafter\ifstrequal\expandafter{#1}{CNY}} }{\renewcommand{\currencysymbol}{\textyen}}{} % JPY or CNY (yen)

    \expandafter\ifstrequal\expandafter{#1}{EUR}{\renewcommand{\currencysymbol}{\texteuro}}{} % EUR (European euro)

    \expandafter\ifstrequal\expandafter{#1}{BRL}{\renewcommand{\currencysymbol}{R\$}}{} % BRL (Brazilian real)

    \expandafter\ifstrequal\expandafter{#1}{INR}{\renewcommand{\currencysymbol}{\rupee}}{} % INR (Indian rupee)
}


%----------------------------------------------------------------------------------------
%   REPORT ENTRIES
%----------------------------------------------------------------------------------------

% Define global variables that get updated for each new report item
\gdef\totalresultsummation{0}      % Cumulative variable storing the total summation
\gdef\resultsummation{0}           % Cumulative variable storing the partial summmation

\gdef\accounttransactionsummation{0} % Cumulative variable storing the current value of an account
\gdef\accountsummation{0}          % Cumulative variable storing the current value of an account

\gdef\totalbalanceinsummation{0}   % Cumulative variable storing the total in summation
\gdef\totalbalancediffsummation{0} % Cumulative variable storing the total diff summation
\gdef\totalbalanceoutsummation{0}  % Cumulative variable storing the total out summation
\gdef\balanceinsummation{0}        % Cumulative variable storing the partial in summmation
\gdef\balancediffsummation{0}      % Cumulative variable storing the partial diff summmation
\gdef\balanceoutsummation{0}       % Cumulative variable storing the partial out summmation

%----------------------------------------

% Command to calculate the subtotal for a table category and add it to the running totals for the whole report
\newcommand{\updateresultsummation}[1]{% Takes 1 argument: 1) price
    \FPeval{\sum}{round(\resultsummation + (#1), \roundcurrencytodecimals)}
    \FPeval{\sumtot}{round(\totalresultsummation + (#1), \roundcurrencytodecimals)}
    \global\let\resultsummation\sum
    \global\let\totalresultsummation\sumtot
}

\newcommand{\updateaccountsummation}[2]{% Takes 2 arguments: 1) price for transaction summation 2) price for total summation
    \FPeval{\sum}{round(\accounttransactionsummation + (#1), \roundcurrencytodecimals)}
    \FPeval{\sumtot}{round(\accountsummation + (#2), \roundcurrencytodecimals)}
    \global\let\accounttransactionsummation\sum
    \global\let\accountsummation\sumtot
}

\newcommand{\updatebalancesummations}[3]{% Takes 3 arguments: 1) in 2) diff 3) out
    \FPeval{\sumin}  {round(\balanceinsummation   + (#1), \roundcurrencytodecimals)}
    \FPeval{\sumdiff}{round(\balancediffsummation + (#2), \roundcurrencytodecimals)}
    \FPeval{\sumout} {round(\balanceoutsummation  + (#3), \roundcurrencytodecimals)}

    \FPeval{\sumtotin}  {round(\totalbalanceinsummation   + (#1), \roundcurrencytodecimals)}
    \FPeval{\sumtotdiff}{round(\totalbalancediffsummation + (#2), \roundcurrencytodecimals)}
    \FPeval{\sumtotout} {round(\totalbalanceoutsummation  + (#3), \roundcurrencytodecimals)}

    \global\let\balanceinsummation\sumin
    \global\let\balancediffsummation\sumdiff
    \global\let\balanceoutsummation\sumout

    \global\let\totalbalanceinsummation\sumtotin
    \global\let\totalbalancediffsummation\sumtotdiff
    \global\let\totalbalanceoutsummation\sumtotout
}

\newcommand{\resetresultsummation}[0]{
    \gdef\resultsummation{0}
}

\newcommand{\resetaccountsummation}[0]{
    \gdef\accountsummation{0}
    \gdef\accounttransactionsummation{0}
}

\newcommand{\resetbalancesummations}[0]{
    \gdef\balanceinsummation{0}
    \gdef\balancediffsummation{0}
    \gdef\balanceoutsummation{0}
}

%----------------------------------------

% Command to correctly output a currency number to the reports, taking into account negatives and currency symbol positioning
\newcommand{\outputcurrency}[1]{%
    \FPifneg{#1}% If the number is negative
        \FPmul{\positivenumber}{#1}{-1}% Make the negative number positive
        \hspace{-\negativesign}--\currencysymbol\FPeval{\roundedpositivenumber}{round(\positivenumber, \roundcurrencytodecimals)}\num{\roundedpositivenumber}\currencysuffix% Output the negative sign before the currency symbol (pulled left in case of left aligned table columns), otherwise it would be e.g. $-55.00, and round to the specified number of decimal places
    \else% If the number is positive
        \currencysymbol\FPeval{\roundednumber}{round(#1, \roundcurrencytodecimals)}\num{\roundednumber}\currencysuffix% Round to the specified number of decimal places
    \fi%
}

%----------------------------------------

\newcommand{\balanceresult}{
    \cellcolor{gray!10} \textbf{SUMMA\ifdefempty{\currencycode}{}{ (\currencycode)}} & \cellcolor{gray!10} & \cellcolor{gray!10} \textbf{\outputcurrency{\balanceinsummation}} & \cellcolor{gray!10} \textbf{\outputcurrency{\balancediffsummation}} & \cellcolor{gray!10} \textbf{\outputcurrency{\balanceoutsummation}}\\ % Don't output the currency code if it has not been set
    \\[0.2cm]
    \resetbalancesummations{}%Reset balance summation counts
}
\newcommand{\balanceheaderrow}[1]{ % Arguments: 1) title
    \cellcolor{gray!30} \textit{#1} & \cellcolor{gray!30} & \cellcolor{gray!30} & \cellcolor{gray!30} & \cellcolor{gray!30} \\% Output the item description
}
\newcommand{\balanceitem}[5]{ % Arguments: 1) description 2) note 3) in 4) diff 5) out
    \updatebalancesummations{#3}{#4}{#5}% Calculate the subtotal for the current item and update totals for the whole report
    #1 & % Output the item description
    \expandafter\ifstrequal\expandafter{#2}{}{}{\footnote{#2}} & % Output the footnote to a table cell
    \outputcurrency{#3} & % Output the price to a table cell
    \outputcurrency{#4} & % Output the price to a table cell
    \outputcurrency{#5}\\ % Output the price to a table cell
}


\newcommand{\resultresult}{
    \cellcolor{gray!10} \textbf{SUMMA\ifdefempty{\currencycode}{}{ (\currencycode)}} & \cellcolor{gray!10} & \cellcolor{gray!10} \textbf{\outputcurrency{\resultsummation}}\\ % Don't output the currency code if it has not been set
    \\[0.2cm]
    \resetresultsummation{}%Reset result summation count
}
\newcommand{\resultheaderrow}[1]{ % Arguments: 1) title
    \cellcolor{gray!30} \textit{#1} & \cellcolor{gray!30} & \cellcolor{gray!30} \\*% Output the item description
}
\newcommand{\resultitem}[3]{ % Arguments: 1) description 2) note 3) price
    \updateresultsummation{#3}% Calculate the subtotal for the current item and update totals for the whole report
    #1 & % Output the item description
    \expandafter\ifstrequal\expandafter{#2}{}{}{\footnote{#2}} & % Output the footnote to a table cell
    \outputcurrency{#3} \\% Output the price to a table cell
}


\newcommand{\accountheaderrow}[1]{ % Arguments: 1) title
    \\\cellcolor{gray!30} & \cellcolor{gray!30} & \cellcolor{gray!30} \textit{#1} & \cellcolor{gray!30} & \cellcolor{gray!30} \\*% Output the item description
    \resetaccountsummation{}
}
\newcommand{\accountopeningrow}[1]{ % Arguments: 1) amount
    \updateaccountsummation{0}{#1}
    \cellcolor{gray!10} & \cellcolor{gray!10} & \cellcolor{gray!10} INGÅENDE SALDO & \cellcolor{gray!10} & \cellcolor{gray!10} \outputcurrency{#1} \\*
}
\newcommand{\accountclosingrow}[0]{ % Arguments: None
    \cellcolor{gray!10} & \cellcolor{gray!10} & \cellcolor{gray!10} SUMMA PERIODEN / UTGÅENDE SALDO & \cellcolor{gray!10} \outputcurrency{\accounttransactionsummation} & \cellcolor{gray!10} \outputcurrency{\accountsummation} \\
}
\newcommand{\accounttransaction}[4]{ % Arguments: 1) verification number 2) date 3) description 4) price
    \updateaccountsummation{#4}{#4}% Calculate the subtotal for the current item and update totals for the whole report
    #1 & #2 & #3 &
    \outputcurrency{#4} & \outputcurrency{\accountsummation} \\% Output the price to a table cell
}


% Define \transactionitem* and \transactionitem. The former prevents linebreaks.
\NewDocumentCommand{\transactionitem}{s m m}{ % Arguments: 1) account 2) price
  \IfBooleanTF{#1}
    {& & #2 & \outputcurrency{#3} \\*} % If \transactionitem*{}{} is used
    {& & #2 & \outputcurrency{#3} \\}  % If \transactionitem{}{}  is used
}
\newcommand{\verificationitem}[3]{ % Arguments: 1) verification number 2) date 3) description
    \cellcolor{gray!30} #1 & \cellcolor{gray!30} #2 & \cellcolor{gray!30} #3 & \cellcolor{gray!30}  \\*
}

%----------------------------------------------------------------------------------------
%   TABLE ENVIRONMENTS
%----------------------------------------------------------------------------------------

\newenvironment{balancetable}{
    \begin{longtable}[H]{L{0.5\textwidth} R{0.01\textwidth} R{0.15\textwidth} R{0.11\textwidth} R{0.15\textwidth}} % Define report table column widths and alignments (L, R or C for left, right or center alignment)
    \textbf{KONTO} & \textbf{NOT} & \textbf{INGÅENDE BALANS} &\textbf{PERIOD} & \textbf{UTGÅENDE BALANS} \\[0.3cm] % Header row
}{
    \\ % Extra line before the summary numbers
    \cellcolor{gray!10} \textbf{\expandafter\ifstrequal\expandafter{\reporttype}{Balansräkning}{ÅRETS RESULTAT}{BERÄKNAT RESULTAT}\ifdefempty{\currencycode}{}{ (\currencycode)}} & \cellcolor{gray!10} & \cellcolor{gray!10} \outputcurrency{\totalbalanceinsummation} & \cellcolor{gray!10} \outputcurrency{\totalbalancediffsummation} & \cellcolor{gray!10} \outputcurrency{\totalbalanceoutsummation}\\ % Don't output the currency code if it has not been set
    \end{longtable}

    \vspace{0.02\textheight} % Fixed vertical whitespace in case the table uses up all the stretch space
}


\newenvironment{resulttable}{
    \begin{longtable}[H]{L{0.78\textwidth} L{0.05\textwidth} R{0.12\textwidth}} % Define report table column widths and alignments (L, R or C for left, right or center alignment)
    \textbf{KONTO} & \textbf{NOT} & \textbf{PERIODEN} \\[0.3cm] % Header row
}{
    \\ % Extra line before the summary numbers
    \cellcolor{gray!10} \textbf{RESULTAT\ifdefempty{\currencycode}{}{ (\currencycode)}} & \cellcolor{gray!10} & \cellcolor{gray!10} \outputcurrency{\totalresultsummation}\\ % Don't output the currency code if it has not been set
    \end{longtable}

    \vspace{0.02\textheight} % Fixed vertical whitespace in case the table uses up all the stretch space
}


\newenvironment{verificationtable}{
    \begin{longtable}[H]{L{0.05\textwidth} L{0.12\textwidth} L{0.645\textwidth} R{0.12\textwidth}} % Define report table column widths and alignments (L, R or C for left, right or center alignment)
    \textbf{VER.}\\\textbf{NR.} & \textbf{DATUM} & \textbf{TEXT} & \textbf{} \\[0.3cm] % Header row
}{
    %\\ % Extra line before the summary numbers
    %\cellcolor{gray!10} \textbf{BERÄKNAT RESULTAT\ifdefempty{\currencycode}{}{ (\currencycode)}} & \cellcolor{gray!10} \outputcurrency{\totalresultsummation}\\ % Don't output the currency code if it has not been set
    \end{longtable}

    \vspace{0.02\textheight} % Fixed vertical whitespace in case the table uses up all the stretch space
}


\newenvironment{accounttable}{
    \begin{longtable}[H]{L{0.05\textwidth} L{0.12\textwidth} L{0.51\textwidth} R{0.12\textwidth} R{0.12\textwidth}} % Define report table column widths and alignments (L, R or C for left, right or center alignment)
    \textbf{VER.}\\\textbf{NR.} & \textbf{DATUM} & \textbf{TEXT} & \textbf{} & \textbf{SALDO} \\[0.3cm] % Header row
}{
    \end{longtable}

    \vspace{0.02\textheight} % Fixed vertical whitespace in case the table uses up all the stretch space
}


%----------------------------------------------------------------------------------------
%   CUSTOM COMMANDS
%----------------------------------------------------------------------------------------

\newcommand{\reporttype}[1]{\renewcommand{\reporttype}{#1}}
\newcommand{\currencycode}[1]{\renewcommand{\currencycode}{#1}}
\newcommand{\currencysuffix}[1]{\renewcommand{\currencysuffix}{#1}}
\newcommand{\roundquantitytodecimals}[1]{\renewcommand{\roundquantitytodecimals}{#1}}
\newcommand{\roundcurrencytodecimals}[1]{\renewcommand{\roundcurrencytodecimals}{#1}}
