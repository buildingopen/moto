# moto — open-all-sessions wrappers.
# The heavy lifting lives in `moto up` (background). `axo` is kept as a legacy alias.

axo()    { moto up; }
axo-fg() { moto up -fg; }
