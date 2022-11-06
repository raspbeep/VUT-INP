; Vernamova sifra na architekture DLX
; Pavel Kratochvil xkrato61
; Povolene registre: xkrato61-r7-r9-r12-r15-r21-r0

        .data 0x04          ; zacatek data segmentu v pameti
login:  .asciiz "xkrato61"  ; <-- nahradte vasim loginem
cipher: .space 9 ; sem ukladejte sifrovane znaky (za posledni nezapomente dat 0)

        .align 2            ; dale zarovnavej na ctverice (2^2) bajtu
laddr:  .word login         ; 4B adresa vstupniho textu (pro vypis)
caddr:  .word cipher        ; 4B adresa sifrovaneho retezce (pro vypis)

        .text 0x40          ; adresa zacatku programu v pameti
        .global main        ; 

; r7  pozicia v logine/cipher
; r9  register na sifrovane pismenko
; r12 register na prvy posun +11 podla pismena k
; r15 register na druhy posun -18 podla pismena r
; r21 register na vysledok porovnavania

main:   
	add r7, r0,r0 ; inicializacia pozicie v logine/cipher na 0
	addi r12, r0, 11 ; inicializacia posunu +11
	addi r15, r0, -18 ; inicializacia posunu -18	


loop:
	lb r9, login(r7) ; nacitanie dalsieho pismenka do r9

	
	slti r21, r9, 58 ; (r9 < 58) ? r21=1 : r21=0 		;kontrola ci to nie je cislo
	bnez r21, number			     		;skok ak to je cislo
	nop
	nop
	

	add r9, r9, r12		; sifrovanie podla prveho pismena
	sgti r21, r9, 122 ; (r9 > 122) ? r21=1 : r21=0			; porovnanie ci nepresiahlo rozsah abecedy
	bnez r21, subtraction ; (r21 == 1) ? goto subtract : continue	; skok ak prekrocilo
	nop
	nop

continue1:
	

	sb cipher(r7), r9	; ulozenie zasifrovaneho pismena
	addi r7, r7, 1		; posun na dalsie pismenko

	lb r9, login(r7)	; nacitanie dalsieho pismenka do r9

	slti r21, r9, 58 ; (r9 < 58) ? r21=1 : r21=0 		; kontrola ci to nie je cislo
	bnez r21, number			     		; skok ak to je cislo
	nop
	nop

	add r9, r9, r15
	slti r21, r9, 97 ; (r9 < 97) ? r21 = 1 : r21 = 0 	; porovnanie ci nepresiahlo rozsah abecedy
	bnez r21, addition ; (r21 == 1) ? goto add : continue 	; skok ak prekrocilo
	nop
	nop
	
continue2:
	sb cipher(r7), r9	; ulozenie zasifrovaneho pismena
	
	addi r7, r7, 1 		; posun na dalsie pismenko

	j loop 			; skok na zaciatok 
	nop
	nop
	

subtraction:
	addi r9, r9, -26	; odcitam o 26 ak som prekrocil rozsah abecedy
	add r21, r0, r0
	j continue1	
	nop
	nop

addition:
	addi r9, r9, 26		; pricitam o 26 ak som prekrocil rozsah abecedy
	add r21, r0, r0
	j continue2
	nop
	nop

number:				; navestie ak najdem cislo
    sb cipher(r7), r0

end:    addi r14, r0, caddr 	; <-- pro vypis sifry nahradte laddr adresou caddr
        trap 5  		; vypis textoveho retezce (jeho adresa se ocekava v r14)
        trap 0  		; ukonceni simulace
