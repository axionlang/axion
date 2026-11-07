//! `axionc fmt` — formatter tests. v1 is a layout-neutral normalizer (trailing whitespace, blank-line
//! collapse, final newline) that must preserve meaning; the whole-corpus identical-Core gate lives in
//! `scripts/fmt-check.sh`.
#![allow(clippy::unwrap_used, clippy::expect_used)]

use axionc::format::format_src;

#[test]
fn strips_trailing_ws_and_normalizes_blanks() {
    let src = "main :: IO ()   \nmain = putStrLn \"hi\"\n\n\n\n";
    let got = format_src(src).expect("parses");
    assert_eq!(got, "main :: IO ()\nmain = putStrLn \"hi\"\n");
}

#[test]
fn keeps_one_blank_line_between_decls() {
    let src = "a :: Int\na = 1\n\n\n\nb :: Int\nb = 2\n";
    let got = format_src(src).expect("parses");
    assert_eq!(got, "a :: Int\na = 1\n\nb :: Int\nb = 2\n");
}

#[test]
fn significant_indentation_is_untouched() {
    // the layout-significant leading indentation of case alternatives / do statements must not move
    let src = "f :: Int -> Int\nf x = case x of\n  0 -> 1\n  _ -> 2\n";
    let got = format_src(src).expect("parses");
    assert_eq!(got, src); // already clean → no change
}

#[test]
fn idempotent() {
    let src = "data T = A | B deriving (Eq, Show)  \n\n\nmain = putStrLn (show A)\n";
    let once = format_src(src).expect("parses");
    let twice = format_src(&once).expect("parses");
    assert_eq!(once, twice);
}

#[test]
fn unparseable_is_left_untouched() {
    // a broken file is skipped (None) rather than mangled
    assert_eq!(format_src("main = = =\n"), None);
}

#[test]
fn reindents_over_indented_case_alternatives() {
    // alternatives aligned but over-indented (col 6) → canonical one block level (col 2)
    let src = "f :: Int -> Int\nf x = case x of\n      0 -> 1\n      _ -> 2\n";
    let got = format_src(src).expect("parses");
    assert_eq!(got, "f :: Int -> Int\nf x = case x of\n  0 -> 1\n  _ -> 2\n");
}

#[test]
fn reindents_do_statements() {
    let src = "main :: IO ()\nmain = do\n    putStrLn \"a\"\n    putStrLn \"b\"\n";
    let got = format_src(src).expect("parses");
    assert_eq!(
        got,
        "main :: IO ()\nmain = do\n  putStrLn \"a\"\n  putStrLn \"b\"\n"
    );
}

#[test]
fn reindents_nested_case_in_do() {
    // do-statement at one level (2), its case alternatives at two (4)
    let src = "main :: IO ()\nmain = do\n     case x of\n          A -> f\n          B -> g\n";
    let got = format_src(src).expect("parses");
    assert_eq!(
        got,
        "main :: IO ()\nmain = do\n  case x of\n    A -> f\n    B -> g\n"
    );
}

#[test]
fn where_block_is_left_as_authored() {
    // a `where` body is an unmodeled block → its (idiosyncratically indented) lines are byte-stable
    let src = "f :: Int\nf = g\n  where g = 1\n        h = 2\n";
    let got = format_src(src).expect("parses");
    assert_eq!(got, src);
}

#[test]
fn reindent_is_idempotent_on_messy_input() {
    let src = "main :: IO ()\nmain = do\n        case x of\n            A -> f\n            B -> g\n";
    let once = format_src(src).expect("parses");
    let twice = format_src(&once).expect("parses");
    assert_eq!(once, twice);
}
