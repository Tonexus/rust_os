## defines the standard c functions memset, memcpy, and memcmp

	.text
	
	.align 16
	.global	memset2
memset2:
	movl	%edi, %edx	## callee saved edi
	movl	4(%esp), %edi	## get destination arg
	movl	8(%esp), %eax	## get source value arg
	movl	12(%esp), %ecx	## get count arg
	rep stosb		## repeat store byte
	movl	%edx, %edi	## restore edi
	movl	4(%esp), %eax	## set return value
	ret
	.size	memset2, .-memset2

	.align 16
	.global	memcpy2
memcpy2:
	movl	%edi, %edx	## callee saved edi
	movl	%esi, %eax	## callee saved esi
	movl	4(%esp), %edi	## get destination arg
	movl	8(%esp), %esi	## get source arg
	movl	12(%esp), %ecx	## get count arg
	rep movsb		## repeat move byte
	movl	%eax, %esi	## restore esi
	movl	%edx, %edi	## restore edi
	movl	4(%esp), %eax	## set return value
	ret
	.size	memcpy2, .-memcpy2

	.align 16
	.global	memcmp2
memcmp2:
	movl	12(%esp), %ecx	## get count arg
	testl	%ecx, %ecx	## skip if count == 0
	je	skip
	movl	%edi, %edx	## callee saved edi
	movl	%esi, %eax	## callee saved esi
	movl	4(%esp), %edi	## get destination arg
	movl	8(%esp), %esi	## get source arg
	repe cmpsb		## repeat compare byte
	movzbl	-1(%esi), %ecx	## get first unequal/last char of source
	movl	%eax, %esi	## restore esi
	movzbl	-1(%edi), %eax	## get first unequal/last char of destination
	movl	%edx, %edi	## restore edi
	subl	%ecx, %eax	## set return value
	ret
	.align 16
skip:
	xorl	%eax, %eax	## set return value
	ret
	.size	memcmp2, .-memcmp2
