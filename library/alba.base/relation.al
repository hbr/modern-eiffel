{: Copyright (C) Helmut Brandl  <helmut dot brandl at gmx dot net>

   This file is distributed under the terms of the GNU General Public License
   version 2 (GPLv2) as published by the Free Software Foundation. :}


use
    predicate_logic
    tuple
end

A: ANY
B: ANY


all(r,s:(A,B)?)
    require
        all(a,b) r(a,b) ==> s(a,b)
    proof
        all(t)
            proof   inspect t
                    ensure r(t) ==> s(t) end
            ensure  r(t) ==> s(t) end
    ensure
        r <= s
    end


domain (r:(A,B)?): ghost A?         -> {a: some(b) r(a,b)}
range  (r:(A,B)?): ghost B?         -> {b: some(a) r(a,b)}

image    (p:A?, r:(A,B)?): ghost B? -> {b: some(a) a in p and r(a,b)}
preimage (p:B?, r:(A,B)?): ghost A? -> {a: some(b) b in p and r(a,b)}

inverse (r:(A,B)?): (B,A)?          -> {b,a: r(a,b)}

all(r:(A,B)?)
    ensure
        range(r)  = domain(inverse(r))
        domain(r) = range (inverse(r))

        range (inverse(r))  = domain(r)
        domain(inverse(r))  = range (r)
    end
