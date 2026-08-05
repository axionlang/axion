-- TCP Echo Server: listens on port 8080, accepts a connection, reads data,
-- echoes it back, closes.  Each step is forced via `case` chains because Axion's
-- `let` bindings are lazy and FFI side-effects must be sequenced eagerly.
--
-- Usage: axionc --release echo_server.axi
-- Test:   echo "hello" | nc localhost 8080

echoLoop :: Int -> IO ()
echoLoop sock =
  case ax_net_accept sock of
    client ->
      case ax_net_recv client of
        msg ->
          case ax_net_send client msg of
            _ ->
              case ax_net_close client of
                _ -> echoLoop sock

main :: IO ()
main =
  case ax_net_listen 8080 of
    sock ->
      case putStrLn "listening on :8080" of
        _ -> echoLoop sock
