BITS 64

%use smartalign
alignmode p6 ; use long NOP instructions.

SECTION .data
int_max : DD 2147483648.0 ; 2^31 as float.
flt_zero : DD 0.0
flt_one : DD 1.0

GLOBAL seed
seed : DD 0,0 ; two 32-bit seeds for the PRNG. this needs to be filled by the
; calling code in order to actually get different results from the algorithm.

SECTION .text
; float exp(float x / xmm0)
; this function calculates the value of e^x by using x87 instructions, since
; SSE does not really allow us to do such sophisticated math. this function,
; although exact, is probably quite slow and I'd suspect it to take up the most
; execution time of the main function.
; the function uses the mathematical identity \f$a^{\log_a{b}} = b\f$ in order
; to compute the actual result, but also performs some additional math due to
; the limitations of some of x87's instructions.
align 32
exp:
    push    rbp
    mov     rbp,    rsp
    sub     rsp,    4
    
    movss   [rbp-4],xmm0 ; copy the operand to the stack.
    fld     dword [rbp-4] ; and load it to the FPU.
    fldl2e ; st(0) <= log2e
    fmulp ; st(0) <= x*log2e
    fld     st0 ; st(1) <= st(0) <= x*log2e
    frndint ; st(0) <= int(x*log2e)
    fsub    st1,    st0 ; st(1) <= flt(x*log2e) - float part of the expression
    fxch ; st(1) <=> st(0)
    f2xm1 ; st(0) <= 2^(flt(x*log2e)) - 1
    fld1 ; st(0) <= 1
    faddp ; st(0) <= 2^(flt(x*log2e))
    fscale ; st(0) <= (2^(flt(x*log2e)) * 2^(int(x*log2e)))
    
    ; the result in st(0) is now equal to e^x, as the expression stored in there
    ; is equivalent to e^(flt(x) + int(x)), of course saving for floating-point
    ; inaccuracies.
    
    fstp    dword [rbp-4] ; store st(0), pop
    ffree   st0 ; st(0) now contains int(x*log2e), free it
    fincstp ; and make the stack empty.
    
    movss   xmm0,   [rbp-4] ; move result to xmm0 for returning
    mov     rsp,    rbp
    pop     rbp
    ret

; int int_rand(void)
; this function generates a random integer in the range <0, 2^31 - 1>. it uses
; the multiply-with-carry algorithm invented by George Marsaglia.
align 32
int_rand:
    mov     eax,    [seed]
    mov     edx,    [seed+4]
    mov     esi,    eax
    mov     edi,    edx ; save copies of the seeds for computation.
    
    and     eax,    0xFFFF
    and     edx,    0xFFFF
    shr     esi,    16
    shr     edi,    16
    imul    eax,    eax,    36969
    imul    edx,    edx,    18000
    add     eax,    esi 
    add     edx,    edi ; compute the new seeds according to the algorithm.
    
    mov     [seed],     eax
    mov     [seed+4],   edx ; save the new seeds
    
    ; compute the result of the function, clearing bit 31, as we want the output
    ; to always be a positive integer.
    shl     eax,    16
    add     eax,    edx
    and     eax,    0x7fffffff
    
    ret

; float float_rand(void)
; generate a random floating-point value, using the int_rand function defined
; above. it just calls the function, converts the result to float and divides it
; by 2^31.
align 32
float_rand:
    call        int_rand
    cvtsi2ss    xmm0,   eax
    divss       xmm0,   [int_max]
    
    ret

; void random_shuffle(uint32_t *t / rdi, int ts / esi)
; randomly shuffle the contents of the ts-sized array of 4-byte integers located
; at address 't'. quit if the address or the size is zero.
align 32
random_shuffle:
    push    rbp
    push    rbx
    push    r12
    push    r13
    push    r14
    mov     rbp,    rsp
    
    test    rsi,    rsi
    jz      .end
    
    test    esi,    esi
    jz      .end
    
    mov     rbx,    rdi
    mov     r13d,   esi
    mov     r12d,   esi
    sub     r12d,   1 ; save some fairly constant parameters to protected regs.
    
    ; r14d - counter for .loop1, from 0 to (ts-1).
    xor     r14d,   r14d

align 16
.loop1:
    
    align 16
    .loop2:
        ; .loop2 calls int_rand to obtain a random value as long as the obtained
        ; value is different than the current iteration of .loop1
        call    int_rand
        
        xor     edx,    edx ; div takes edx:eax - clear out "high" bits.
        div     r13d ; divide the obtained random value (eax) by array size
        cmp     edx,    r14d
        je      .loop2 ; if the obtained value modulo array size was the same
        ; as the iteration of .loop1, get a random again.
    
    ; we're out of .loop2 - swap the items in locations r14d (current .loop1) and
    ; edx (random).
    mov     esi,            [rbx+r14*4]
    mov     edi,            [rbx+rdx*4]
    mov     [rbx+r14*4],    edi
    mov     [rbx+rdx*4],    esi
    
    add     r14d,   1
    cmp     r14d,   r12d
    jne     .loop1 ; move on to the next element of the array.

align 16
.end:
    mov     rsp,    rbp
    pop     r14
    pop     r13
    pop     r12
    pop     rbx
    pop     rbp
    ret

; void annealing(float Tstart / xmm0,float Tmin / xmm1,float alpha / xmm2,
;   uint32_t *solution / rdi, int solution_size / esi,
;   int (*crit_func)(uint32_t* / rdi,int / esi) / rdx);
align 32
GLOBAL annealing
annealing:
    push    rbp
    push    rbx
    push    r12
    push    r13
    push    r14
    mov     rbp,    rsp
    
    movss   xmm6,   [flt_zero]
    
    test    esi,    esi ; solsize == 0
    jz      .end
    
    test    rdi,    rdi ; solution == NULL
    jz      .end
    
    test    rdx,    rdx ; crit_func == NULL
    jz      .end
    
    comiss  xmm2,   xmm6 ; alpha <= 0
    jbe     .end
    
    comiss  xmm2,   [flt_one] ; alpha >= 1
    jae     .end
    
    comiss  xmm0,   xmm6 ; Tstart <= 0
    jbe     .end
    
    comiss  xmm1,   xmm0 ; Tmin >= Tstart
    jae     .end
    
    comiss  xmm1,   xmm6 ; Tmin <= 0
    jbe     .end
    
    ; set up the contents of protected registers
    mov     rbx,    rdi
    mov     r12d,   esi
    mov     r13,    rdx
    
    ; set up the stack space for local variables. variables used in this func :
    ; -4 : float - current process' temperature
    ; -8 : float - minimum temperature
    ; -12 : float - alpha parameter
    ; -16 : float - e^x (very temporary)
    ; -20 : dword - evaluation of the solution with two random elements swapped
    ; -24 : dword - index of the swapped element, needed for rollback
    ; -28 : dword - see above.
    sub     rsp,        28
    movss   [rbp-4],    xmm0
    movss   [rbp-8],    xmm1
    movss   [rbp-12],   xmm2
    
    ; let's create a new, random solution. the parameters are all in place.
    call    random_shuffle
    
    ; now calculate the evaluation of this solution...
    mov     rdi,    rbx
    mov     esi,    r12d
    call    r13
    
    ; and save the result as the best known.
    mov     r14d,   eax
    
align 16
.anneal_loop:
    align 16
    .rand_idx:
        ; get two random integers, which will be used as indices of the swapped
        ; elements. repeat as long as they're the same.
        call    int_rand
        xor     edx,    edx
        div     r12d
        mov     r10d,   edx
        
        call    int_rand
        xor     edx,    edx
        div     r12d
        mov     r11d,   edx
        
        cmp     r11d,   r10d
        je      .rand_idx
    
    ; r11d and r10d now contain the indices of the elements to be swapped.
    ; actually swap them and save the indices locally.
    mov     r8d,            [rbx+r10*4]
    mov     r9d,            [rbx+r11*4]
    mov     [rbx+r11*4],    r8d
    mov     [rbx+r10*4],    r9d
    mov     [rbp-24],       r10d
    mov     [rbp-28],       r11d
    
    ; now, calculate the evaluation of the solution with the swapped elements.
    mov     rdi,        rbx
    mov     esi,        r12d
    call    r13
    
    ; if the new evaluation value is higher (=> worse) than the currently best
    ; known one, check if the temperature allows us to accept it as new "best".
    mov     [rbp-20],   eax
    cmp     eax,        r14d
    jg      .checktemp
    
align 16
.newcrit:
    ; else, just take the new solution to use.
    mov     r14d,       eax
    jmp     .newtemp
    
align 16
.checktemp:
    ; calculate the x for e^x.
    sub         ecx,    eax
    cvtsi2ss    xmm0,   ecx
    divss       xmm0,   [rbp-4] ; x = (f(S) - f(S')) / cur_temp
    call        exp
    
    ; get a random value.
    movss       [rbp-16],   xmm0
    call        float_rand
    
    ; if the received random value is lower than our e^x value, we accept the
    ; solution with the lower criterion value.
    mov     eax,    [rbp-20] ; needed for .newcrit (if taken)
    comiss  xmm0,   [rbp-16]
    jl      .newcrit
    
    ; else, we need to roll back the change
    mov     r10d,           [rbp-24]
    mov     r11d,           [rbp-28]
    mov     r8d,            [rbx+r10*4]
    mov     r9d,            [rbx+r11*4]
    mov     [rbx+r11*4],    r8d
    mov     [rbx+r10*4],    r9d

align 16
.newtemp:
    ; calculate the new temperature and repeat the main loop, if temperature is
    ; not lower than the given minimum.
    movss   xmm0,   [rbp-4]
    mulss   xmm0,   [rbp-12]
    comiss  xmm0,   [rbp-8]
    movss   [rbp-4],xmm0
    jnb     .anneal_loop

align 16
.end:
    mov     rsp,    rbp
    pop     r14
    pop     r13
    pop     r12
    pop     rbx
    pop     rbp
    ret
