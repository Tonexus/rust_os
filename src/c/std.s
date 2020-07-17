## defines the standard c functions memset, memcpy, and memcmp

	.text
	
	.align 16
	.global	memset
memset:
	pushl	%ebp
	movl	%esp, %ebp
	pushl	%edi		## callee saved edi
	movl	8(%ebp), %edx	## gets destination arg
	movl	16(%ebp), %ecx	## gets count arg
	movl	12(%ebp), %eax	## gets source value arg
	movl	%edx, %edi
	rep stosb		## repeat store byte
	movl	-4(%ebp), %edi	## restore edi
	movl	%edx, %eax	## set return value
	leave
	ret
	.size	memset, .-memset

	.align 16
	.global	memcpy
memcpy:
	pushl	%ebp
	movl	%esp, %ebp
	pushl	%edi		## callee saved edi
	movl	8(%ebp), %eax	## gets destination arg
	movl	16(%ebp), %ecx	## gets count arg
	pushl	%esi		## callee saved esi
	movl	12(%ebp), %esi	## gets source arg
	movl	%eax, %edi
	rep movsb		## repeat move byte
	popl	%esi		## restore esi
	popl	%edi		## restore edi
	popl	%ebp
	ret
	.size	memcpy, .-memcpy

	.align 16
	.global	memcmp
memcmp:
	pushl	%ebp
	xorl	%eax, %eax
	movl	%esp, %ebp
	pushl	%edi
	movl	16(%ebp), %ecx
	pushl	%esi
	testl	%ecx, %ecx
	je	skip
	movl	8(%ebp), %edi
	movl	12(%ebp), %esi
	repe cmpsb
	movzbl	-1(%edi), %eax
	movzbl	-1(%esi), %edx
	subl	%edx, %eax
skip:
	popl	%esi
	popl	%edi
	popl	%ebp
	ret
	.size	memcmp, .-memcmp
