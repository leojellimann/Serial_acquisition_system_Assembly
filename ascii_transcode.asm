#include "p16f877.inc"

__CONFIG _FOSC_XT & _WDTE_OFF & _PWRTE_OFF & _CP_OFF & _BOREN_OFF & _LVP_OFF & _CPD_OFF & _WRT_ON

ORG 0x000
 
    CBLOCK 0x20                            ;Init de valeur pour plus tard
                valBinaireEntiere : 1
                valDecEntiere : 1
                valDecDecimale : 1
    ENDC
        
        
    banksel TXSTA
    movlw         B'00100110'
    movwf        TXSTA  ;config transmit usart

    banksel SPBRG
    movlw         0x0019
    movwf         SPBRG  ;X pour le baudrate pour 9600
    
    banksel RCSTA
    movlw         B'10000000'
    movwf          RCSTA ;config receive usart
       
   ; configuration de l'ADC
    banksel ADCON1
    movlw        B'00001110'        ;Left justify,1 analog channel
    movwf        ADCON1                ;VDD and VSS references

    banksel ADCON0        
    movlw        B'01000001'        ;Fosc/8, A/D enabled
    movwf        ADCON0
        
    goto         main
    

;fonctions
    
envoie                            
    banksel PIR1                ; demarrage usart
                
wait
    BTFSS        PIR1, TXIF     ;verification comm libre
    goto         wait
    banksel      TXREG               ;envoie message dans registre envoie
    movwf        TXREG
verif        
    banksel      TXSTA
    BTFSC        TXSTA, TRMT    ;verififcation comm effectué
    goto         verif 
    return  
    
    
conversionValEntiere
            banksel       ADRESH                        ;Selection du registre 
            movfw         ADRESH                        ;Envoie dans le registre W la valeur de la conversion Ana/Num de 0 à 5V
            movwf         valBinaireEntiere
            movlw         D'0'				;On initialise l'entier et le décimal à 0 pour réécrire la nouvelle valeur lue
            movwf         valDecDecimale
            movwf         valDecEntiere
            goto          conversionMain

        conversionMain
            movlw        D'51'                           ;51 est la valeur pour l'unité du V 0,1,2,3,4 ou 5
            subwf        valBinaireEntiere,0             ;Calcul de W (=51) - valBinaireEntiere. On stocke le résultat dans le registre W
	    btfss        STATUS,C                        ;Permet de vérifier si la carry d'overflow=1. Si C = 1 alors on skip l'instruction suivante, si C = 0 alors on continue normalement
			
	    goto         conversionDec
            incf         valDecEntiere
            movwf        valBinaireEntiere		 ;
            goto         conversionMain

        conversionDec
            movlw        D'5'                            ;5 est la valeur pour 0,1V. On soustrait 5 pour avoir les décimales
            subwf        valBinaireEntiere,0		 ;Calcul de W (=5) - valBinaireEntiere. On stocke le résultat dans le registre W 
            btfss        STATUS,C                        ;Permet de vérifier si la carry d'overflow=1. Si C = 1 alors on skip l'instruction suivante, si C = 0 alors on continue normalement
            continue
	    goto         conversionFin
	    movwf        valBinaireEntiere
	    movlw        D'9'
	    subwf        valDecDecimale,0		 ; voir si la partie decimal vaux 9 et lui soustraire 9 
	    btfss        STATUS,Z			 ; skip if Z = 1 et donc que l'opération vaux 0
            incf         valDecDecimale
            goto         conversionMain

        conversionFin
            movfw        valDecEntiere              
            addlw        0x30				 ;Addition de la valeur dans W de W + 0x30 pour l'avoir en mode ascii 
return                
	    
main
    banksel ADCON0                                 ;On mesure la tension entre 0 et 5V
    bsf         ADCON0,GO			   ;Go est mis à 1 dans le registre ADCON0
mesure
    BTFSC       ADCON0,GO
    goto        mesure                                ;attente fin mesure
    call        conversionValEntiere                ;conversion binaire to decimal si ADCON0 = 0
    call        envoie
    movlw       ','
    call        envoie
    call        conversionValEntiere
    movfw       valDecDecimale
    addlw	0x30				    ;permet d'afficher la valeur décimale en ascii sur le terminal série
    call	envoie
    movlw       'V'
    call        envoie
    movlw       '\n'
    call        envoie
    movlw       '\r'
    call        envoie
    goto	main
    
    return
    end                                        ; du programme (directive d'assemblage)