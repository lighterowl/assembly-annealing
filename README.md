assembly-annealing
==================

This is a project whose sole purpose was to provide an implementation of
the simulated annealing algorithm in x86 assembly. The only limitation was that
no libc could be used in the final solution.

The assembly code was written for Linux, running on a x86-64 machine. The global
exported function complies with the AMD64 ABI, and as such can be safely called
from inside C code, which is illustrated by the attached example.

There are no guarantees as to whether this implementation is in any way better
or faster than its analogous C implementation. In fact, I'd suspect it to
perform much worse, since modulo operations are performed by the `div`
instruction, as opposed to a mixture of multiplications usually produced by C
compilers.

The main function itself is as generic as it can be, probably : it accepts a
pointer to an array, which contains the starting solution. The solution is then
evaluated by a user-supplied callback function, and the solution is customized
in order to minimize the value returned by this callback function. See the
header for more information.

(c) Daniel Kamil Kozar 2013. Public domain.
