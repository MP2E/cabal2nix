module Main ( main ) where

import Cabal2Nix.Hackage ( hashPackage, readCabalFile )
import Cabal2Nix.Package ( cabal2nix )
import Distribution.NixOS.Derivation.Cabal
import Distribution.NixOS.Derivation.Meta

import Control.Exception ( bracket )
import Control.Monad ( when )
import Distribution.PackageDescription ( package, packageDescription )
import Distribution.PackageDescription.Parse ( parsePackageDescription, ParseResult(..) )
import Distribution.Text ( disp )
import System.Console.GetOpt ( OptDescr(..), ArgDescr(..), ArgOrder(..), usageInfo, getOpt )
import System.Environment ( getArgs )
import System.Exit ( exitFailure )
import System.IO ( hPutStrLn, hFlush, stdout, stderr )

data CliOption = PrintHelp | SHA256 String | Maintainer String | Platform String | NoHaddock
  deriving (Eq)

main :: IO ()
main = bracket (return ()) (\() -> hFlush stdout >> hFlush stderr) $ \() -> do
  let options :: [OptDescr CliOption]
      options =
        [ Option ['h'] ["help"]       (NoArg PrintHelp)                 "show this help text"
        , Option []    ["sha256"]     (ReqArg SHA256 "HASH")            "sha256 hash of source tarball"
        , Option ['m'] ["maintainer"] (ReqArg Maintainer "MAINTAINER")  "maintainer of this package (may be specified multiple times)"
        , Option ['p'] ["platform"]   (ReqArg Platform "PLATFORM")      "supported build platforms (may be specified multiple times)"
        , Option []    ["no-haddock"] (NoArg NoHaddock)                 "don't run Haddock when building this package"
        ]

      usage :: String
      usage = usageInfo "Usage: cabal2nix [options] url-to-cabal-file" options ++ unlines
              [ ""
              , "Recognized URI schemes:"
              , ""
              , "  cabal://pkgname-pkgversion       download the specified package from Hackage"
              , "  http://host/path                 fetch the Cabel file via HTTP"
              , "  file:///local/path               load the Cabal file from the local disk"
              , "  /local/path                      abbreviated version of file URI"
              ]

      cmdlineError :: String -> IO a
      cmdlineError ""     = hPutStrLn stderr usage >> exitFailure
      cmdlineError errMsg = hPutStrLn stderr errMsg >> cmdlineError ""

  args' <- getArgs
  (opts,args) <- case getOpt Permute options args' of
     (o,n,[]  ) -> return (o,n)
     (_,_,errs) -> cmdlineError (concatMap (\e -> '*':'*':'*':' ':e) errs)

  when (PrintHelp `elem` opts) (cmdlineError "")

  let uri         = args
      hash        = [ h | SHA256 h <- opts ]
      noHaddock   = NoHaddock `elem` opts
      maints      = [ if '.' `elem` m then m else "self.stdenv.lib.maintainers." ++ m | Maintainer m <- opts ]
      plats'      = [ if '.' `elem` p then p else "self.stdenv.lib.platforms." ++ p | Platform p <- opts ]
      plats
        | null plats' = if not (null maints) then ["self.ghc.meta.platforms"] else []
        | otherwise   = plats'

  when (length uri /= 1) (cmdlineError "*** exactly one URI must be specified")
  when (length hash > 1) (cmdlineError "*** the --sha256 option may be specified only once")

  cabal' <- fmap parsePackageDescription (readCabalFile (head uri))
  cabal <- case cabal' of
             ParseOk _ a -> return a
             ParseFailed err -> do
               hPutStrLn stderr ("*** cannot parse cabal file: " ++ show err)
               exitFailure

  let packageId = package (packageDescription cabal)

  sha <- if null hash then hashPackage packageId else return (head hash)

  let deriv  = (cabal2nix cabal) { sha256 = sha, runHaddock = not noHaddock }
      deriv' = deriv { metaSection = (metaSection deriv)
                                     { maintainers = maints
                                     , platforms   = plats
                                     }
                     }

  putStr (show (disp deriv'))
