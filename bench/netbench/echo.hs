-- Concurrent keep-alive TCP echo server — Haskell, one lightweight `forkIO` green thread per
-- connection, scheduled by GHC's epoll IO manager via threadWaitRead/Write (the same mechanism the
-- `network` package uses). Raw FFI sockets so it needs only `base` (no package fetch). Run with
-- the threaded RTS: `+RTS -N`. This is the idiomatic GHC concurrent-server model, the closest
-- analogue to Axión's M:N session tasks.
{-# LANGUAGE ForeignFunctionInterface #-}
module Main (main) where

import Control.Concurrent (forkIO, threadWaitRead, threadWaitWrite)
import Control.Monad (forever, when, void)
import Foreign hiding (void)
import Foreign.C.Types
import System.Environment (getArgs)
import System.Posix.Types (Fd(..))

foreign import ccall unsafe "socket"     c_socket :: CInt -> CInt -> CInt -> IO CInt
foreign import ccall unsafe "bind"       c_bind :: CInt -> Ptr Word8 -> CInt -> IO CInt
foreign import ccall unsafe "listen"     c_listen :: CInt -> CInt -> IO CInt
foreign import ccall unsafe "accept"     c_accept :: CInt -> Ptr Word8 -> Ptr CInt -> IO CInt
foreign import ccall unsafe "recv"       c_recv :: CInt -> Ptr Word8 -> CSize -> CInt -> IO CLong
foreign import ccall unsafe "send"       c_send :: CInt -> Ptr Word8 -> CSize -> CInt -> IO CLong
foreign import ccall unsafe "close"      c_close :: CInt -> IO CInt
foreign import ccall unsafe "setsockopt" c_setsockopt :: CInt -> CInt -> CInt -> Ptr CInt -> CInt -> IO CInt
foreign import ccall unsafe "fcntl"      c_fcntl :: CInt -> CInt -> CInt -> IO CInt

afInet, sockStream, solSocket, soReuse, fGetfl, fSetfl, oNonblock :: CInt
afInet = 2; sockStream = 1; solSocket = 1; soReuse = 2
fGetfl = 3; fSetfl = 4; oNonblock = 0o4000

setNonblock :: CInt -> IO ()
setNonblock fd = do
  fl <- c_fcntl fd fGetfl 0
  void $ c_fcntl fd fSetfl (fl .|. oNonblock)

-- Retry an accept/recv that a wakeup raced (result < 0 = EAGAIN here) after waiting for readability.
main :: IO ()
main = do
  [portStr] <- getArgs
  let port = read portStr :: Int
  lfd <- c_socket afInet sockStream 0
  with (1 :: CInt) $ \p -> void $ c_setsockopt lfd solSocket soReuse p 4
  allocaBytes 16 $ \sa -> do
    fillBytes sa 0 16
    pokeByteOff sa 0 (2 :: Word8)                              -- sin_family = AF_INET (LE)
    pokeByteOff sa 2 (fromIntegral (port `div` 256) :: Word8)  -- sin_port hi (network order)
    pokeByteOff sa 3 (fromIntegral (port `mod` 256) :: Word8)  -- sin_port lo
    _ <- c_bind lfd sa 16
    return ()
  _ <- c_listen lfd 512
  setNonblock lfd
  forever $ do
    threadWaitRead (Fd lfd)
    cfd <- c_accept lfd nullPtr nullPtr
    when (cfd >= 0) $ do
      setNonblock cfd
      void $ forkIO (handle cfd)

handle :: CInt -> IO ()
handle fd = allocaBytes 4096 $ \buf -> do
  let loop = do
        threadWaitRead (Fd fd)
        n <- c_recv fd buf 4096 0
        if n > 0 then sendAll buf (fromIntegral n) >> loop
        else if n == 0 then void (c_close fd)         -- peer closed
        else loop                                     -- EAGAIN race → wait again
      sendAll p len
        | len <= 0  = return ()
        | otherwise = do
            w <- c_send fd p (fromIntegral len) 0
            if w > 0 then sendAll (p `plusPtr` fromIntegral w) (len - fromIntegral w)
            else threadWaitWrite (Fd fd) >> sendAll p len
  loop
