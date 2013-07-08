{ cabal, blaze-builder, data-default, text, time }:

cabal.mkDerivation (self: {
  pname = "cookie";
  version = "0.4.0.1";
  sha256 = "01k5gq9kwbrivkhr1sj8aw4cgf2c1xgwwajqvd435r0g99fpx5kk";
  buildDepends = [ blaze-builder data-default text time ];
  doCheck = false;
  meta = {
    homepage = "http://github.com/snoyberg/cookie";
    description = "HTTP cookie parsing and rendering";
    license = self.stdenv.lib.licenses.bsd3;
    platforms = self.ghc.meta.platforms;
  };
})