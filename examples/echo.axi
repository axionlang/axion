-- TCP Echo (single-shot): listens on port 8080, accepts one connection,
-- reads data, echoes it back, closes.  Single-connection version — no
-- loop, simpler to test.
--
-- Usage: axionc --release echo.axi
-- Test:   echo "hello" | nc -w1 localhost 8080
main :: IO ()
main =
  case ax_net_listen 8080 of
    sock ->
      case ax_net_accept sock of
        client ->
          case ax_net_recv client of
            msg ->
              case ax_net_send client msg of
                _ ->
                  case ax_net_close client of
                    _ ->
                      case ax_net_close sock of
                        _ -> putStrLn "echoed and closed"
