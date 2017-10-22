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
	# --PALABRAS SECRETAS-- 
	palabra1: .asciiz "computadora"
	palabra2: .asciiz "mips"
	palabra3: .asciiz "aprobar"
	palabra4: .asciiz "gorila"
	palabra5: .asciiz "isomorfo"

	PALABRAS: .word palabra1, palabra2, palabra3, palabra4, palabra5
	cantidad_palabras: .byte 4
	puntero_palabras: .byte 0
	jugadas: .byte 0

	mensaje:  .asciiz "Bienvenido al Juego del Ahorcado!\n"
	ahorcado: .asciiz " AHORCADO"
	jugar_otra: .asciiz "Jugas otra? (y/n): "
	buffer: .space 20
	errores: .byte 0


.text
LEAF(_start)
	
	.set	mips2
	.set	reorder

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


	# Inicio del programa principal
	#MOSTRAR MENSAJE BIENVENIDA ----- OK
	#ELEGIR PALABRA RANDOM ----- OK
	#COMPLETAR CON - SEGUN CANTIDAD DE CARACTERES DE PALABRA ELEGIDA ----- OK
	#SETEAR RONDA DE JUEGO
		#INGRESA CARACTER (GETC) -- OK
		#SI CARACTER ESTA EN PALABRA LLENAR - CORRESPONDIENTES AL CARACTER (modificar buffer) (cantidad de letras distintas del string para control fin partida?)
		#SI CARACTER NO ESTA EN PALABRA
			#CONTADOR DE ERRORES ++
			#INSERTAR LETRA CORRESPONDIENTE SEGUN INTENTO FALLIDO
	#SI FINAL PARTIDA (CONTADOR ERRORES = 8) -> LIMPIA LINEA. "GAME OVER PECHO FRIO"
	#(LETRAS ADIVINADAS) -> "HA GANADO!"
	#MENSAJE CONTINUAR -- OK		

main:

	la	a0, mensaje #Muestra el mensaje de bienvenida
	jal	mostrar_mensaje
	
	# Sin exit
_loop_juego:
	la a0, PALABRAS 			#Cargo direccion de memoria de palabras
	la a1, puntero_palabras
	la a2, cantidad_palabras
	la a3, jugadas
	jal	elegir_palabra_random		#Obtiene siguiente palabra
	lw s4, errores 	#guarda en s4 cantidad de errores 
	move s0, v0			#Almacena la palabra en s0
	move a0, s0			#Mueve la palabra como parametro
	jal longitud
	
	move s1,v0 	#Guarda en s1 la longitud de la palabra
	la a0, buffer 		#a0 = dir memoria buffer
	move a1, s1			#a1 = longitud string
	jal crear_guiones	#Crea guiones en el buffer
	la s2, buffer 		#Almacena en s2 la dir de memoria del buffer con guiones
	move a0, s2
	jal mostrar_mensaje
	#la s3, ahorcadomove a0, s3jal mostrar_mensaje
	jal	ronda_juego			# Juega una ronda
	
_seguir:
	la	a0, jugar_otra			
	jal	mostrar_mensaje				
	jal	getc			

	beq	v0, 121, _loop_juego		
	bne	v0, 110, _seguir	
	
	#SE ROMPE TODO // ETERNAL LOOP
	
	
salida:	
	li	v0, 10
	syscall
	
	# Fin del programa principal

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

#Este procedimiento elige una palabra dentro de las guardadas en memoria aleatoriamente.
elegir_palabra_random:
		lw t0, 0(a0) #dir memoria PALABRAS
		lw t1, 0(a1) #dir memoria puntero_palabras
		lw t2, 0(a2) #cantidad palabras totales
		lw t3, 0(a3)
		add t4, t0, t1 #desplazamiento en PALABRAS
		addi t1, t1, 0x04 #siguiente posicion de PALABRAS
		addi t3, t3, 0x01 #Incremento cantidad jugadas
		sw t1, 0(a1) #Actualizo
		sw t3, 0(a3)
		beq t3, t2, terminar_juego #Si la cantidad de jugadas es igual a la cantidad de palabras
		lw v0, 0(t4) #retorno palabra
		jr ra
#Este procedimiento escribe tantos guiones en el buffer como letras en la palabra y los ubica en el buffer. Loop pensado de adelante
#para atras.
# a0 = dir buffer, a1 = longitud string (cantidad de guiones a poner)
crear_guiones:
	addi	sp, sp, -8			# 8 bytes
	sw	a0, 0(sp)			#Guarda a0
	sw	a1, 4(sp)			#Guarda a1
	
	add	a0, a0, a1			# a0 = dir de memoria del buffer + longitud
	addi	t1, zero, 0x2D			# valor ascii de '-' en t1
	#sb	zero,0(a0)			# primer byte en null
_loop_guion:
	beq	a1, 0, _loop_fin_guion	# Si a0 = 0
	addi	a0, a0, -1			# decrenta la posicion del buffer
	addi	a1, a1, -1			# decrementa longitud
	sb	t1, 0(a0)			# guarda guion
	j	_loop_guion
_loop_fin_guion:
	lw	a0, 0(sp)			# carga a0
	lw	a1, 4(sp)			# carga a1
	addi	sp, sp, 8			# devuelve los 8 bytes
	jr	ra				

#Aca empieza y continuan las rondas del juego
ronda_juego:

	jal getc #Obtiene la tecla presionada. Guardada en v0
	move a0, s0 #a0 = palabra
	move a1, v0 #a1 = caracter ingresado
	jal busqueda_caracter #Busca el caracter
	
	bne v0, zero, _char_correcto #si el char esta
	beq v0, zero, _letra_equivocada
	
	_char_correcto:
		move a0, s2
		move a2, s0
		jal completar_correcto
		move a0, s0
		li a1, 45
		jal busqueda_caracter
		bne v0, zero, _fin_ronda_gano
		j ronda_juego

	_letra_equivocada:
		
		addi	s4, s4, 0x01			# suma cantidad de errores
		beq	s4, 8, _fin_ronda_perdio	# COMPLETA AHORCAD CON O Y GAME OVER
		
		j	ronda_juego		# Guess again!
	_fin_ronda_perdio:

	_fin_ronda_gano:
		la a0, ronda_ganada
		jal mostrar_mensaje
		jr ra

#Busqueda caracter en la palabra
busqueda_caracter:
	addi	sp, sp, -4			# 4 bytes
	sw	a0, 0(sp)			# guarda a0
	
	
	and	v0, v0, zero			# v0 como boolean. 0 false 1 true. v0 = false
	
_loop_busqueda:
	lb	t0, 0(a0)				# carga char del string
	beq	t0, 0, _loop_busqueda_fin		# fin del string, termina de ciclar
	beq	t0, a1, _char_encontrado			# char encontrado
	addi	a0, a0, 0x01				# dir memoria + 1. Siguiente char
	j	_loop_busqueda
_char_encontrado:
	addi	v0, zero, 0x01				# como fue encontrado v0 = 1
_loop_busqueda_fin:
	lw	a0, 0(sp)			# carga a0
	addi	sp, sp, 0x04			# devuelve 4 bytes 
	jr	ra				

#Completa con el caracter correcto en el buffer.
#a0 = buffer, a1 = char, a2 = palabra
completar_correcto:

	addi	sp, sp, -8			#4 bytes
	sw	a0, 0(sp)			# Guarda a0
	sw	a2, 4(sp)			# Guarda a1
	
	
_loop_correcto:
	lb	t0, 0(a2)				# Carga el char desde el string
	beq	t0, 0, _loop_correcto_fin		#fin
	bne	t0, a1, _char_no_esta		#si el char no pertenece al encontrado, lo saltea
	sb	a1, 0(a0)				# corresponde por lo tanto se lo pone en el buffer (reemplaza el '-')
	j _char_no_esta 	#incrementa (al no encontrarlo hace lo mismo)
_char_no_esta:
	addi	a0, a0, 1				#incrementa buffer
	addi	a2, a2, 1				#incrementa posicion de la palabra
	j	_loop_correcto
_loop_correcto_fin:
	
	lw	a2, 4(sp)			# carga a1
	lw	a0, 0(sp)			# carga a0
	addi	sp, sp, 8			# 4 bytes
	jr	ra				
	
#Ultima ronda
ultima_ronda:

#Cantidad letras. a0 = string
longitud:
	
	addi	sp, sp, -4 		#4 bytes
	sw	a0, 0(sp)			# guardo a0
	

	and	v0, v0, $0			# Iterador v0 en 0
_loop:
	lb	t7, 0(a0)			# obtiene caracter ASCII	
	beq	t7, zero, _loop_fin		# Si null, finaliza
	
	addi	a0, a0, 0x01			# Siguiente letra
	addi	v0, v0, 0x01			# Iterador++
	
	j	_loop			

_loop_fin:	
	
	lw	a0, 0(sp)			#devuelvo a0 a su valor original
	addi	sp, sp, 0x04		#dlo mismo con el stack	
	jr	ra	

#NO HAY MAS PALABRAS JEJEJE			
 terminar_juego:
 	_loop_fin_juego:
 		j _loop_fin_juego


