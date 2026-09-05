# Modules (multi-file programs)

Axión programs can span multiple files. A module brings another file's top-level
definitions — functions, `data` types, classes, instances, and `foreign` imports — into
scope.

```haskell
-- Lib.axi
double :: Int -> Int
double n = n + n

-- Main.axi
import Lib
main :: Int
main = double 21        -- 42
```

```sh
axionc run Main.axi           # resolves `import Lib` → ./Lib.axi
```

## Resolution

- `import Foo` loads `Foo.axi` from the **importing file's directory**; `import Foo.Bar`
  loads `Foo/Bar.axi`.
- Imports are **transitive** — an imported module's own imports are resolved too.
- Each module is loaded and merged **at most once** across the whole program, so a
  **diamond** (two modules importing a third) merges the shared module once, and an import
  **cycle** (`A` imports `B` imports `A`) terminates cleanly instead of looping.
- A definition the importing file already provides is **not** overwritten by an import (local
  definitions win), the same rule the built-in prelude follows.

## Qualified imports

`import qualified Foo as F` prefixes the imported names with `F_` (e.g. `F_double`). A plain
`import Foo` merges names unprefixed.

## Status / limitations

Whole-module import works and is exercised across all three backends
(`multi_file_imports_resolve_and_handle_cycles`). Not yet supported: selective import lists
(`import Foo (bar, baz)`) and dotted qualified *use* syntax (`F.double` — the prefix is the
underscore form `F_double`). Explicit export lists are not enforced — every top-level
definition of an imported module is visible.
