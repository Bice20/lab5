; Archivo: laboratorio5.s
; Dispositivo: PIC16F887 
; Autor: Brandon Cruz
; Copilador: pic-as (v2.30), MPLABX v5.40
;
; Programa: Displays Simultaneos
; Hardware: Contador binario de 8 bits que incremente en RB0 Y decremente en RB1
;
; Creado: 21 de febrero , 2022
; Última modificación: 26 febrero, 2022
    
PROCESSOR 16F887
#include <xc.inc>

; CONFIG1
  CONFIG  FOSC = INTRC_NOCLKOUT ; Oscillator Selection bits (INTOSCIO oscillator: I/O function on RA6/OSC2/CLKOUT pin, I/O function on RA7/OSC1/CLKIN)
  CONFIG  WDTE = OFF            ; Watchdog Timer Enable bit (WDT disabled and can be enabled by SWDTEN bit of the WDTCON register)
  CONFIG  PWRTE = OFF           ; Power-up Timer Enable bit (PWRT enabled)
  CONFIG  MCLRE = OFF           ; RE3/MCLR pin function select bit (RE3/MCLR pin function is digital input, MCLR internally tied to VDD)
  CONFIG  CP = OFF              ; Code Protection bit (Program memory code protection is disabled)
  CONFIG  CPD = OFF             ; Data Code Protection bit (Data memory code protection is disabled)
  CONFIG  BOREN = OFF           ; Brown Out Reset Selection bits (BOR disabled)
  CONFIG  IESO = OFF            ; Internal External Switchover bit (Internal/External Switchover mode is disabled)
  CONFIG  FCMEN = OFF           ; Fail-Safe Clock Monitor Enabled bit (Fail-Safe Clock Monitor is disabled)
  CONFIG  LVP = OFF             ; Low Voltage Programming Enable bit (RB3/PGM pin has PGM function, low voltage programming enabled)

; CONFIG2
  CONFIG  BOR4V = BOR40V        ; Brown-out Reset Selection bit (Brown-out Reset set to 4.0V)
  CONFIG  WRT = OFF             ; Flash Program Memory Self Write Enable bits (Write protection off)

// config statements should precede project file includes.
#include <xc.inc>
 
; ------- VARIABLES EN MEMORIA --------
UP EQU 1
DOWN EQU 0
 
PSECT udata_bank0
    CONTA:		DS 1	; 1byte
    CENTENA:		DS 1	;1 byte
    DECENA:		DS 1	;1 byte
    UNIDADES:		DS 1	;1 byte
    BANDERADISP:	DS 1	;1 byte
    DISPLAY:		DS 3	;3 byte
  
; -------------- MACRO --------------- 
  
  RESETTIMER0 MACRO
    BANKSEL TMR0 ;Dirección al banco 00
    MOVLW   217  ;cargar literal en W
    MOVWF   TMR0 ;configuración para que tenga 10ms de retraso
    BCF	    T0IF ;llamar de bandera
    ENDM
  
; ------- Status para interrupciones --------
PSECT udata_shr		     ; Memoria compartida
    W_TEMP:		        DS 1 ;1 byte
    STATUS_TEMP:		DS 1 ;1 byte
    
PSECT resVect, class=CODE, abs, delta=2
		   
;------------ VECTOR RESET --------------
ORG 00h	
resVect:
    PAGESEL MAIN		
    GOTO    MAIN
    
PSECT inVect, class=CODE, abs, delta=2
			
;------- VECTOR INTERRUPCIONES ----------

ORG 04h	
push:
    MOVWF   W_TEMP	   ;Se mueve W a la varibale W_TEMP
    SWAPF   STATUS, W      ;swapf de nibbles del status y se almacena en W
    MOVWF   STATUS_TEMP	   ;se mueve w a la variable
    
isr:
    
    BTFSC   RBIF		; Fue interrupción? No=0 Si=1
    CALL    INTERRUPI0CB        ; si-> subrutina de interrupcion del puerto B
    BANKSEL PORTA    
    BTFSC   T0IF                ; Fue interrupción del TMR0? No=0 Si=1
    CALL    INT_TMR0            ;si-> subrutina de interrupción del TMR0
	
    
pop:
    SWAPF   STATUS_TEMP, W      ;swap de nibbles de la variable
    MOVWF   STATUS		;se mueve w a status 
    SWAPF   W_TEMP, F	        ;swap de nibbles de la variable w_temp y se al macena en la varibale
    SWAPF   W_TEMP, W		;swap de nibbles de la varibale w_temp y se almacena en W
    RETFIE			
        
PSECT code, delta=2, abs
ORG 100h			
;------------- CONFIGURACION ------------
MAIN:
    CALL    CONFIG_IO		;Configuración de IO(entradas y salidas)
    CALL    CONFIG_RELOJ	;Configuración de oscilador
    CALL    CONFIG_TMR0		;Configuración de TMR0
    CALL    CONFIG_INT          ;Configuración de interrupciones
    CALL    CONFII0CB           ;Configuración de interrupción en PORTB
    BANKSEL PORTA		

;----------LOOP PRINCIPAL---------------
LOOP:	
    CALL    VALOR_DEC	       ;llamar rutina de movimientos de valores decimales a 7seg
    CALL    OBTENER_CENTENAS   ;llamar rutina para obtener de centenas,decenas,unidades	
    GOTO    LOOP	       
    
;------------- SUBRUTINAS ---------------

CONFIG_RELOJ:
    BANKSEL OSCCON		;se direcciona a banco 01
    BSF	    OSCCON, 0	        ;se configura el reloj interno /frecuencia interna del oscilador a 4MHZ
    BSF	    OSCCON, 6           ;bit 6 en 1
    BSF	    OSCCON, 5           ;bit 5 en 1
    BCF	    OSCCON, 4		;bit 4 en 0
    RETURN
  
CONFIG_TMR0:
    BANKSEL OPTION_REG		;se direcciona al banco 01
    BCF	OPTION_REG, 5           ;el timer 0 como temporizador
    BCF	OPTION_REG, 3           ;prescaler a TMR0
    BSF	OPTION_REG, 2           ;bit 2 en 1
    BSF	OPTION_REG, 1           ;bit 1 en 1
    BSF	OPTION_REG, 0           ;bit 0 en 1
    //Prescaler en 256
    RESETTIMER0
    RETURN 
    
    
CONFIG_IO:
    BANKSEL ANSEL               ;se direcciona al banco 11
    CLRF    ANSEL               ;I/O digitales 
    CLRF    ANSELH
    
    BANKSEL TRISA	        ;se direcciona al banco 01
    BSF	    TRISB, UP	        ;RB0 como entrada
    BSF	    TRISB, DOWN         ;RB1 como entrada
    
    CLRF    TRISA               ;PORTA como salida
    CLRF    TRISC               ;PORTC como salida
    CLRF    TRISD               ;PORTD como salida
    
    BCF	    OPTION_REG,	7       ;se habilita las resistencias pull-up
    BSF	    WPUB,   UP          ;habilita el registro pullup en RB0
    BSF	    WPUB,   DOWN        ;habilita el registro pullup en RB1
    
    BANKSEL PORTA               ;se direcciona al banco 00
    CLRF    PORTA               ;se limpia
    CLRF    PORTB               ;se limpia
    CLRF    PORTC               ;se limpia
    CLRF    PORTD               ;se limpia

    CLRF    CENTENA             ;se limpia la variable
    CLRF    DECENA              ;se limpia la variable
    CLRF    UNIDADES            ;se limpia la variable
    CLRF    BANDERADISP	        ;se limpia la variable
    RETURN
    
CONFIG_INT:
    BANKSEL INTCON
    BSF	    GIE                 ;se habilita las interrupciones globales
    BSF	    RBIE                ;habilita interrupciones de cambio de estado del PORTB
    BCF	    RBIF                ;se limpia la bandera 
    BSF	    T0IE                ;se habilita interrupción TMR0
    BCF	    T0IF                ;se limpia la bandera del TMR0
    RETURN
    
CONFII0CB:
    BANKSEL TRISA               
    BSF	    IOCB, UP            ;interrupcion de cambio en el valor de B
    BSF	    IOCB, DOWN          ;interrupcion de cambio en el valor de B       
    BANKSEL PORTA
    MOVF    PORTB,  W           ;termina la condición de mismatch comparada con W
    BCF	    RBIF                ;se limpia la bandera de PORTB
    RETURN
    
INTERRUPI0CB:
    BANKSEL PORTA
    BTFSS   PORTB,  UP          ;se analiza RB0 /(si no está presionado salta una linea)
    INCF    PORTA
    BTFSS   PORTB,  DOWN        ;se analiza RB1/(si no está presionado salta una linea)
    DECF    PORTA
    BCF	RBIF                    ;se limpia la bandera (de cambio de estado del PORTB)
    RETURN 
    
INT_TMR0:
    RESETTIMER0                 ;reinicio TMR0 para 10ms
    CALL    MOSTRAR_VALORDEC    ;configuración de encendido/apago
    RETURN
    
VALOR_DEC:
    MOVF    UNIDADES,W          ;se mueve el valor a W
    CALL    TABLA               ;se busca el valor que se va a cargar a PORTC
    MOVWF   DISPLAY             ;se guarda en una nueva variable
    
    MOVF    DECENA,W            ;se mueve el valor a W
    CALL    TABLA               ;se busca el valor que se va a cargar a PORTC
    MOVWF   DISPLAY+1           ;se guarda en una nueva variable
    
    MOVF    CENTENA,W           ;se mueve el valor a W
    CALL    TABLA               ;se busca el valor que se va a cargar a PORTC
    MOVWF   DISPLAY+2           ;se guarda en una nueva variable
    RETURN
    
MOSTRAR_VALORDEC:
    BCF	    PORTD,  0           ;se limpia el set-display de centenas
    BCF	    PORTD,  1           ;se limpia el set-display de decenas 
    BCF	    PORTD,  2           ;se limpia el set-display de unidades 
    BTFSC   BANDERADISP,  0     ;se verifica la bandera del display centenas (apagado= salta)
    goto    DISPLAY3            ;si está encendido se mueve al display de centenas
    BTFSC   BANDERADISP,  1     ;se verificia la bandera del display decena (apaado=salta)
    GOTO    DISPLAY2            ;si está encendido se mueve al display decenas 
    BTFSC   BANDERADISP,  2     ;se verifica la bandera del display 
    GOTO    DISPLAY1            ;si esta encendido se mueve al display de unidades
    
    
DISPLAY1:
    MOVF    DISPLAY,	W           ;se mueve valor(UNIDADES) a w 
    MOVWF   PORTC                   ;se muestra en el display
    BSF	    PORTD,  2               ;se enciende set-display de unidades
    BCF	    BANDERADISP,    2       ;se apaga la bandera de unidades
    BSF	    BANDERADISP,    1       ;se enciende la bandera de decenas
    RETURN
    
DISPLAY2:
    MOVF    DISPLAY+1,	W           ;se mueve el valor(DECENA) a W
    MOVWF   PORTC                   ;se muestra en el display
    BSF	    PORTD,  1               ;se enciende set-display de decenas
    BCF	    BANDERADISP,    1       ;se apaga la bandera de centenas
    BSF	    BANDERADISP,    0       ;se enciende la bandera de centenas
    RETURN    
    
DISPLAY3:
    MOVF    DISPLAY+2,	W           ;se mueve valor de CENTENA a w
    MOVWF   PORTC                   ;se muestra en el display
    BSF	    PORTD,  0               ;se enciende display de centenas
    BCF	    BANDERADISP,    0       ;se apaga la bandera de centena
    BSF	    BANDERADISP,    2       ;se enciende la bandera de unidades
    RETURN    
      
OBTENER_CENTENAS:
    CLRF    CENTENA  ;se limpian las variables
    CLRF    DECENA
    CLRF    UNIDADES
    ;programación de obtención de centenas
    MOVF    PORTA,  W ;se mueve el valor de PORTA a W
    MOVWF   CONTA     ;se mueve w, a la variable
    MOVLW   100       ;se mueve 100 a w
    SUBWF   CONTA,  F ;se resta 100 a w 
    INCF    CENTENA   ;se incrementa en 1 la varibale
    BTFSC   STATUS, 0 ;se verifica el estado la bandera((apagado)
    
    GOTO    $-4        
    DECF    CENTENA
    
    MOVLW   100       ;se mueve 100 a W
    ADDWF   CONTA,  F ;se añaden los 100 a lo que tenga en ese momento negativo en CONTA para que sea positivo
    CALL    OBTENER_DECENAS; se llaman la subrutina para obtener las decenas
    RETURN
    
OBTENER_DECENAS:
    MOVLW   10        ;se mueve 10 a W
    SUBWF   CONTA,  F ;se resta 10 a CONTA y se guarda en CONTA
    INCF    DECENA    ;se incrementa en 1 la variable DECENA
    BTFSC   STATUS, 0 ;se verifica si está apagada la bandera de BORROW
    
    GOTO    $-4   
    DECF    DECENA
    
    MOVLW   10        ;se mueve 10 a W
    ADDWF   CONTA,  F ;se añaden los 10 a lo que tenga en ese momento negativo en CONTA para que sea positivo
    CALL    OBTENER_UNIDADES ; se llama la subrutina para obtener la unidades
    RETURN
    
    
OBTENER_UNIDADES:  
    MOVLW   1         ;se mueve 1 a W
    SUBWF   CONTA,  F ;se resta 1 a CONTA y se guarda en CONTA 
    INCF    UNIDADES  ;se incrementa en 1 la variable UNIDADES
    BTFSC   STATUS, 0 ;se verifica si está apagada la bandera BORROW
    
    GOTO    $-4
    DECF    UNIDADES
    MOVLW   1        ;se mueve 1 a W
    ADDWF   CONTA,  F;se añaden 1 a lo que tenga en ese momento negativo en CONTA para que sea positivo (en este caso, cero)
    RETURN
    
     
ORG 200h
TABLA:
    CLRF    PCLATH		
    BSF	    PCLATH, 1	
    ANDLW   0x0F		
    ADDWF   PCL
    RETLW   00111111B	;0
    RETLW   00000110B	;1
    RETLW   01011011B	;2
    RETLW   01001111B	;3
    RETLW   01100110B	;4
    RETLW   01101101B	;5
    RETLW   01111101B	;6
    RETLW   00000111B	;7
    RETLW   01111111B	;8
    RETLW   01101111B	;9
    RETLW   01110111B	;A
    RETLW   01111100B	;b
    RETLW   00111001B	;C
    RETLW   01011110B	;d
    RETLW   01111001B	;E
    RETLW   01110001B	;F
    
END