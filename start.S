/*
 * Copyright (C) 2001 MontaVista Software Inc.
 * Author: Jun Sun, jsun@mvista.com or jsun@junsun.net
 *
 * Simple I/O using CBUS UART on Malta board by the AyOdC1 crew, Facultad 
 * de Informatica, Universidad Nacional del Comahue
 *
 * This program is free software; you can redistribute  it and/or modify it
 * under  the terms of  the GNU General  Public License as published by the
 * Free Software Foundation;  either version 2 of the  License, or (at your
 * option) any later version.
 *
 */
#include "asm.h"
.data
memoria:
	palabra0:		.asciiz	"computadora"
	palabra1:		.asciiz	"piero"
	palabra2:		.asciiz	"dificil"
	palabra3:		.asciiz	"redcool"
	palabra4:		.asciiz "parangaricutirimicuaro"
	palabra5:		.asciiz "ahorcado"
	palabra6:		.asciiz "ubuntu"
	palabra7:		.asciiz "fidebian"
	palabra8:		.asciiz	"desoxirribonucleico"
	palabra9:		.asciiz	"informatica"
	palabra10:		.asciiz	"pseudofacil"
	palabra11:		.asciiz "durazno"
	palabra12:		.asciiz "julioprofe"

	PALABRAS:		.word	palabra0, palabra1, palabra2, palabra3, palabra4, palabra5, palabra6, palabra7, palabra8, palabra9, palabra10, palabra11, palabra12

	CANT_PALABRAS:	.word	13

	BUFFER:	.space	32

	BIENVENIDA:	.asciiz "Bienvenido al Juego del AHORCADO!!\n\r"
	YES:		.asciiz "Si!"
	NO:		.asciiz "No!"
	ADIVINA:	.asciiz "\r Adivina: "
	AHORCADO_BUFFER:	.asciiz "         "
	AHORCADO: .asciiz "AHORCADO"
	PETICION_LETRA: .asciiz	"Ingresa una letra: "
	FORFEIT:	.asciiz "PERDEDOOOR!\n\r"
	RONDA_FIN: .asciiz "Bien!\n\r"
	NO_ADIVINA:	.asciiz "\r PERDISTE JAJAJAJA\n\r"
	PALABRA_POSTA:	.asciiz "La palabra era: \t"
	JUGAR_NUEVO:	.asciiz "Jugas otra vez (y/n)? "
	SALTO_LINEA:	.asciiz "\n"
	RETORNO_LINEA: .asciiz "\r"
	BACK_LOOP: .byte 0x1B, 0x5B, 0x32, 0x41, 0x00
	BACK_RONDA: .byte 0x1B, 0X5B, 0x32, 0x4A, 0x00
	DESPEDIDA: .asciiz "Tan temprano?"
	CURSOR_PRINCIPIO: .byte 0x1B, 0x5B, 0x73, 0x00
	DIRIGIR_CURSOR: .byte 0x1B, 0x5B, 0x75, 0x00
	COLOR: .byte 0x1B, 0x5B, 0x31, 0x3B, 0x33, 0x33, 0x6D, 0x00


	.text
LEAF(_start)
	
	.set mips2
	.set reorder

/* Disable interrupts */
	mtc0	zero, CP0_STATUS

/* Disable watch exception. */
	mtc0    zero, CP0_WATCHLO
	mtc0    zero, CP0_WATCHHI

/* disable kernel mode cache */
	mfc0	t0, CP0_CONFIG
	and	t0, ~0x7
	ori	t0, 0x2
	mtc0	t0, CP0_CONFIG

/* set up stack */
	li	sp, 0xa0000000 + RAMSIZE - 16

main:
	la a0, COLOR
	jal mostrar_mensaje
	lw	s0, PALABRAS		# S0 = primera palabra
	and	s1, s1, 0			# S1 = cantidad errores
	and	s2, s2, 0			# S2 = cantidad de jugadas (hasta llegar a CANT_PALABRAS)
	la s5, PALABRAS
	#BIENVENIDA
	la	a0, BIENVENIDA
	jal	mostrar_mensaje
	la a0, CURSOR_PRINCIPIO
	jal mostrar_mensaje
_loop_juego:
	
	beq	s2, 0, _primera_jugada		# Para no volver a obtener palabra
	lw t0, CANT_PALABRAS
	beq t0, s2, exit
	bne t0, s2, _seleccionar_palabra

_seleccionar_palabra:
	addi s5, s5, 4
	lw s0, 0(s5)
	la a0, AHORCADO_BUFFER
	jal vaciar
	la a0, BACK_RONDA
	jal mostrar_mensaje
	la a0, DIRIGIR_CURSOR
	jal mostrar_mensaje
	la	a0, BIENVENIDA
	jal	mostrar_mensaje
_primera_jugada:
	
	move a0, s0
	
	jal	jugar_partida			# Realiza jugada
	
	addi	s2, s2, 1			#Aumenta jugadas
	
	la	a0, PALABRA_POSTA		
	jal	mostrar_mensaje			
	move	a0, s0				# Muestra la palabra real
	jal	mostrar_mensaje				
	la	a0, SALTO_LINEA
	jal	mostrar_mensaje			#Salto linea
	la a0, RETORNO_LINEA
	jal mostrar_mensaje
	
_peticion_juego:
	la	a0, JUGAR_NUEVO			
	jal	mostrar_mensaje				
	jal	getc
	beq	v0, 121, _loop_juego		# JUEGA DE NUEVO
	bne	v0, 110, _peticion_juego	# NO PRESIONA NI 'N' NI 'Y'
	
    la  a0, DESPEDIDA           
    jal mostrar_mensaje             
	
	
exit:	li	v0, 10
		syscall


END(_start)

.text
# Procedimiento putc: escribir un caracter en el serial (pantalla)
#
# Al no utilizar pila no modificamos sp ni fp
# El caracter a imprimir (ASCII) se pasa como argumento en a0
putc:

	/* CBUS UART base address - data register */
	li t2, 0x9f000900
	/* CBUS UART status register */
	li t3, 0x9f000928

	espera_mostrar:
		lw t4, 0(t3)
		andi t4, t4, 0x20
		beq t4, zero, espera_mostrar
	sw a0, 0(t2)
	jr ra


# Procedimiento mostrar_mensaje: recorre una cadena y envia cada caracter al serial (pantalla), con ayuda de putc
# Este procedimiento utiliza putc, por lo que se debe utilizar la pila
# La direccion de la cadena a imprimir se pasa como argumento en a0
mostrar_mensaje:
	subu sp,sp,32
	sw ra,20(sp)
	sw fp,16(sp)
	addiu fp,sp,28

	move t5, a0
	mostrar_cartel:
	  lb	a0, (t5)
	  jal putc
	  addi t5, t5, 0x01
	  bne a0, zero, mostrar_cartel
	
	lw ra,20(sp)
	lw fp,16(sp)
	addiu sp,sp,32

	jr ra


# Procedimiento getc: espera un byte desde el serial (tecla pulsada)
#		      Devuelve el valor ASCII de la tecla pulsada (en v0)
# Al no utilizar pila no modificamos sp ni fp
getc:
	/* CBUS UART base address - data register */
	li t2, 0x9f000900
	/* CBUS UART status register */
	li t3, 0x9f000928

	espera_tecla:
		lw t4, 0(t3)
		andi t4, t4, 0x01
		beq t4, zero, espera_tecla
	lw v0, 0(t2)

	jr ra

#Procedimiento para la obtencion de la longitud de un string
longitud_string:
	addi	sp, sp, -4		#4 bytes
	sw	a0, 0(sp)			# Guarda a0
	
	li	t0, 1 				#Valor 1
	and	v0, v0, zero		# Iterador = 0
_loop_longitud:
	lb	t1, 0(a0)			# Obtiene el char del string //FALLA?	
	beq	t1, zero, _loop_longitud_fin		# Si 00, termina
	add	a0, a0, t0			# Desplazamiento en string
	add	v0, v0, t0			# Iterador++
	
	j _loop_longitud		

_loop_longitud_fin:	
	lw	a0, 0(sp)			#Carga a0
	addi	sp, sp, 4		#4 bytes
	jr	ra				

#Se desarrolla la partida a partir de la palabra obtenida
jugar_partida:
	
	addi	sp, sp, -24			# 24 bytes
	sw	ra, 0(sp)			# Guardo RA
	sw	a0, 4(sp)			# Guardo a0
	sw	a1, 8(sp)			# Guardo a1
	sw	s0, 12(sp)			# Guardo s0
	sw	s1, 16(sp)			# Guardo s1
	sw	s2, 20(sp)			# Guardo s2
	
	
	jal longitud_string
	move	s3, v0			# s3 = longitud string
	
	#Completa guiones
	la	a0, BUFFER			# Obtiene el buffer
	move	a1, s3			# longitud string
	jal	completar_guiones			
	
_loop_ronda:
	# ERRORES = 8 
	
	beq	s1, 8, _loop_ronda_fin

	la	a0, ADIVINA		
	jal	mostrar_mensaje
	la	a0, BUFFER			
	jal	mostrar_mensaje
	la a0, AHORCADO_BUFFER
	jal mostrar_mensaje

	la a0, SALTO_LINEA
	jal mostrar_mensaje
	la a0, RETORNO_LINEA
	jal mostrar_mensaje
	la	a0, PETICION_LETRA		
	jal	mostrar_mensaje			
	jal	getc			#Obtiene el char
	move	s4, v0			# S2 = char

	beq	s4, 46, _rendicion	
	
	#Busca el char en el string			
	move	a0, s0 #string
	move 	a1, s4 #char			
	jal	contiene		

	bne	v0, 0, _char_encontrado	#v0 = 0 falso, 1 verdadero
	
	la a0, AHORCADO_BUFFER
	la a1, AHORCADO
	move a2, s1
	jal completar_error

	addi	s1, s1, 0x01			# AUMENTA ERRORES

	la	a0, NO				
	jal	mostrar_mensaje
	la a0, SALTO_LINEA
	jal mostrar_mensaje
	beq	s1, 8, _perdio
	la a0, BACK_LOOP
	jal mostrar_mensaje
	j	_loop_ronda			
_char_encontrado:
	
	# Actualiza buffer
	la	a0, BUFFER			
	move	a1, s0			
	move	a2, s4			
	jal	actualizar_buffer			
	
	la	a0, BUFFER			
	addi	a1, zero, 0x2D	# Busca si quedan letras por adivinar
	jal	contiene			
	beq	v0, 0, _loop_ronda_fin
	
	la	a0, YES			
	jal	mostrar_mensaje
	la a0, SALTO_LINEA
	jal mostrar_mensaje
	la a0, BACK_LOOP
	jal mostrar_mensaje
	j	_loop_ronda			

_rendicion:
	la	a0, FORFEIT			
	jal	mostrar_mensaje		
	and	s1, s1, 8

_loop_ronda_fin:
	beq s1, 8, _perdio
	bne s1, 8, _gano
_perdio:
	la a0, AHORCADO_BUFFER
	la a1, AHORCADO
	move a2, s1
	jal completar_error
	la a0, RETORNO_LINEA
	jal mostrar_mensaje
	la a0, AHORCADO_BUFFER
	jal mostrar_mensaje
	j _fin
_gano:
	la	a0, RONDA_FIN		
	jal	mostrar_mensaje
_fin:
	move	v0, s0			
		
	lw	ra, 0(sp)			# Carga return address
	lw	a0, 4(sp)			# Carga a0
	lw	a1, 8(sp)			# Carga a1
	lw	s0, 12(sp)			# Carga s0
	lw	s1, 16(sp)			# Carga s1
	lw	s2, 20(sp)			# Carga s2
	addi	sp, sp, 24		# 24 bytes
	jr	ra					

#Procedimiento para completar guiones segun cantidad de letras del string
completar_guiones:
	addi	sp, sp, -8		#8 bytes
	sw	a0, 0(sp)			# Guardo a0
	sw	a1, 4(sp)			# Guardo a1
	
	add	a0, a0, a1			# a0 = dir buffer + longitud string
	addi	t1, zero, 0x2D	# guion
	sb	zero,0(a0)			# ultimo byte en null
_completar_guiones_loop:
	beq	a1, 0, _completar_guiones_loop_fin	
	addi	a0, a0, -1			# decrementa buffer
	addi	a1, a1, -1			# decrement longitud
	sb	t1, 0(a0)				# almacena guion
	j	_completar_guiones_loop	

_completar_guiones_loop_fin:
	lw 	a0, 0(sp)			# carga a0
	lw	a1, 4(sp)			# Carga a1
	addi	sp, sp, 8		# 8 bytes
	jr	ra			

#Procedimiento para completar guiones segun cantidad de letras del string
vaciar:
	addi	sp, sp, -4		#8 bytes
	sw	a0, 0(sp)			# Guardo a0
	
	li t0, 8	
	add	a0, a0, t0			# a0 = dir buffer + longitud string
	addi	t1, zero, 0x00	# null
	sb	zero,0(a0)			# ultimo byte en null
_vaciar_loop:
	beq	t0, 0, _vaciar_fin	
	addi	a0, a0, -1			# decrementa buffer
	addi	t0, t0, -1			# decrement longitud
	sb	t1, 0(a0)				# almacena null
	j	_vaciar_loop	

_vaciar_fin:
	lw 	a0, 0(sp)			# carga a0
	addi	sp, sp, 4		# 8 bytes
	jr	ra			




#Procedimiento para buscar si determinado char esta en un string
contiene:
	addi	sp, sp, -4		#4 bytes
	sw	a0, 0(sp)			# Guardo a0
	
	and	v0, v0, 0			# falso
	
_contiene_loop:
	lb	t0, 0(a0)					# Carga char del string
	beq	t0, 0, _contiene_loop_fin	
	beq	t0, a1, _char_hallado			# Encontrado
	addi	a0, a0, 1				# incrementa string
	j	_contiene_loop			
_char_hallado:
	addi	v0, zero, 1				# verdadero
_contiene_loop_fin:
	lw	a0, 0(sp)			# Carga a0
	addi	sp, sp, 4		# 4 bytes
	jr	ra			

#Actualiza el buffer
actualizar_buffer:
	addi	sp, sp, -8		#8 bytes
	sw	a0, 0(sp)			# Guardo a0
	sw	a1, 4(sp)			# Guardo a1
	
_loop_actualizar:
	lb	t0, 0(a1)						# Carga char del string
	beq	t0, 0, _loop_actualizar_fin		
	bne	t0, a2, _no_es_char		#NO es
	sb	a2, 0(a0)				# Guardo char en el buffer
_no_es_char:
	addi	a0, a0, 1				#incrementa BUFFER
	addi	a1, a1, 1				#incrementa string
	j	_loop_actualizar

_loop_actualizar_fin:
	lw	a1, 4(sp)			# Carga a1
	lw	a0, 0(sp)			# Carga a0
	addi	sp, sp, 8		# 8 bytes
	jr	ra				

#Completa la palabra AHORCADO a medida que el usuario ingresa caracteres equivocados.
completar_error:
	addi sp, sp, -12
	sw a0, 0(sp)
	sw a1, 4(sp)
	sw a2, 8(sp)

	add a0,a0,a2 #dir buffer + cant errores
	add a1,a1,a2 #dir ahorcado + cant errores

	lb t0, 0(a1) #caracter error
	sb t0, 0(a0) #lo inserta en el buffer
	
	lw a0, 0(sp)
	lw a1, 4(sp)
	lw a2, 8(sp)
	addi sp, sp, 12

	jr ra