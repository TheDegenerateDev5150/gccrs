/* { dg-do compile } */
/* { dg-options "-O3 -march=x86-64 -std=c++17 -fasynchronous-unwind-tables -fdwarf2-cfi-asm -DMODE=0" } */
/* Keep labels and directives ('.cfi_startproc', '.cfi_endproc').  */
/* { dg-final { check-function-bodies "**" "" "" { target lp64 } {^\t?\.} } } */

/*
**_Z22makeDefaultConstructedv:
**.LFB[0-9]+:
**	.cfi_startproc
**	pxor	%xmm0, %xmm0
**	movq	\$0, 80\(%rdi\)
**	movq	%rdi, %rax
**	movups	%xmm0, \(%rdi\)
**	movups	%xmm0, 16\(%rdi\)
**	movups	%xmm0, 32\(%rdi\)
**	movups	%xmm0, 48\(%rdi\)
**	movups	%xmm0, 64\(%rdi\)
**	ret
**...
*/

struct S {
    long int c[10] = {};
    int x{};
#if MODE == 0
#elif MODE == 1
    S() = default;
#elif MODE == 2
    S() noexcept {}
#endif
};

S makeDefaultConstructed() { return S{}; }

/* { dg-final { scan-assembler-not "rep stos" } } */
