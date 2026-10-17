--!strict
-- Public numeric bounds only; the server owns balances and validates every mutation.
-- 1 quadrillion leaves >5 final-collection Open 10 batches of wallet headroom.
-- Six full banks total 6e15, below the IEEE-754 exact-integer limit (2^53 - 1).
return table.freeze({ limit = 1000000000000000, creditLimit = 9007199254740990 })
