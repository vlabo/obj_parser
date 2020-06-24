; Define variables in the data section
section .data
	hello:     db 'Hello dworld!',10
	.len:  equ $-hello

; Code goes in the text section
section .text
	global _main

_main:
	mov rax, 0x2000004            ; 'write' system call = 4
	mov rdi, 1            ; file descriptor 1 = STDOUT
	mov rsi, hello        ; string to write
	mov rdx, hello.len     ; length of string to write
	syscall              ; call the kernel

	; Terminate program
	mov rax,0x2000001            ; 'exit' system call
	mov rdi,0            ; exit with error code 0
	syscall              ; call the kernel
