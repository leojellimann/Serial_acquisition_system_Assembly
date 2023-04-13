;R�alisation d'un syst�me d'acquisiton s�rie pour PC
;Programme r�alis� par L�o Jellimann
;FIP 2A promotion 2023


#include "p16f877.inc"

__CONFIG _FOSC_XT & _WDTE_OFF & _PWRTE_OFF & _CP_OFF & _BOREN_OFF & _LVP_OFF & _CPD_OFF & _WRT_ON

ORG 0x000
 
    CBLOCK 0x20                            ;Initialisation des variables
                valBinaire : 1
                valDecEntiere : 1
                valDecDecimale : 1
				compteur : 1
				statbtn : 1 
    ENDC
        
    
    banksel TXSTA				;configuration Transmit Status And Control Register
    movlw         B'00100110'	;autorisation de la transmission TXEN, vitesse des bauds haute en asynchrone, bit TMRT � 1 pour vider le registre TSR
    movwf        TXSTA  		;ajout de la configuration

    banksel SPBRG							;configuration de la fr�quence d'envoi des donn�es au port s�rie
    movlw         B'0000000000011001'		;SPBRG = 25 pour une fr�quence � 4MHz � 9600 bauds en asynchrone
    movwf         SPBRG  
    
    banksel RCSTA				;configuration de la reception des status et le controle des registres pour USART
    movlw         B'10000000'	;autorisation du bit du port s�rie SPEN
    movwf         RCSTA 
       
    ;configuration du convertisseur analogique/num�rique
	banksel ADCON0        
    movlw        B'01000001'        	;Utilisation de Fosc/8 et autorisation de l'utilisation du convertisseur analogique/num�rique
    movwf        ADCON0
	
    banksel ADCON1
    movlw        B'00001110'        	;Configuration du convertisseur pour avoir 7 ports num�riques et les tensions de r�f�rence Vref+ = VDD et Vref- = VSS
    movwf        ADCON1                 

  
    ;configuration du timer 1 pour compter 1sec
    banksel T1CON
    movlw	B'00110000'	    	;selection du prescaler 1:8 pour pouvoir compter assez longtemps pour 1sec
    movwf T1CON
    
    banksel PIR1
    bcf 	PIR1, TMR1IF
    
    
	bsf statbtn, 0				;initialisation du mode automatique
	call envoie					;on veut d�marrer la communication USART
    goto         main
    

;fonctions
    
envoie                            
    banksel PIR1                ;d�marrage de la communication USART
	verifmsg
    btfss        PIR1, TXIF     ;verification si la communication est libre. Le flag du bit TXIF est mis � 0 en chargeant TXREG
    goto         verifmsg
	
    banksel      TXREG          
    movwf        TXREG			;envoi du message dans le registre TXREG
	
	verif        
		banksel      TXSTA
		btfsc        TXSTA, TRMT    ;verification si la communication a eu lieu
		goto         verif 			;on boucle tant que TRMT est � 1. TRMT = 1 --> TSR = vide. Quand TMRT = 0 alors communication effectu�e.
		return  
    
 
conversionVal

		banksel       ADRESH                        ;Selection du registre 
		movfw         ADRESH                        ;Envoie dans le registre W la valeur de la conversion Ana/Num de 0 � 5V
		movwf         valBinaire
		movlw         D'0'							;On initialise l'entier et le d�cimal � 0 pour r��crire la nouvelle valeur lue
		movwf         valDecDecimale
		movwf         valDecEntiere
		goto          conversionUnit

	conversionUnit
		movlw        D'51'                          ;51 est la valeur pour l'unit� du V 0,1,2,3,4 ou 5
		subwf        valBinaire,0             		;Calcul de W (=51) - valBinaire. On stocke le r�sultat dans le registre W
		btfss        STATUS,C                       ;Permet de v�rifier si la carry d'overflow=1. Si C = 1 alors on skip l'instruction suivante, si C = 0 alors on continue normalement
						 ;C se trouve dans le registre STATUS
		goto         conversionDec					;Permet d'obtenir la valeur d�cimale
		incf         valDecEntiere
		movwf        valBinaire		 ;
		goto         conversionUnit

	conversionDec
		movlw        D'5'                            ;5 est la valeur pour 0,1V. On soustrait 5 pour avoir les d�cimales
		subwf        valBinaire,0		 	 ;Calcul de W (=5) - valBinaire. On stocke le r�sultat dans le registre W 
		btfss        STATUS,C                ;Permet de v�rifier si la carry d'overflow=1. Si C = 1 alors on skip l'instruction suivante, si C = 0 alors on continue normalement
		continue
		goto         conversionFin
	
		movwf        valBinaire
		movlw        D'9'
		subwf        valDecDecimale,0		 		 ;voir si la partie decimal vaut 9 et lui soustraire 9 car en ascii le caract�re apr�s 9 est ":"
		btfss        STATUS,Z			 			 ;skip si Z = 1 et donc que l'op�ration vaut 0
		incf         valDecDecimale
		goto         conversionUnit

	conversionFin
		movfw        valDecEntiere              
		addlw        0x30				 			;Addition de la valeur dans W de W + 0x30 pour l'avoir en mode ascii 
return                

timer
    banksel	T1CON
    bcf		T1CON, TMR1ON   ; met en arr�t le timer 1
    
    ;initialisation � 3036 du timer1
    banksel     PIR1
    bcf		PIR1, TMR1IF	;supprime le flag du timer1
    
    ;pr�chargement du timer � 3036
    movlw	B'11011100'
    movwf	TMR1L
    movlw	B'00001011'
    movwf	TMR1H
    
    banksel	T1CON
    bsf		T1CON, TMR1ON		;d�marrage le timer1
	    
		
recupValToPrint 							;r�cup�re la valeur de la tension et l'affiche sur le port s�rie du PC 
	banksel ADCON0                          ;On mesure la tension entre 0 et 5V
	bsf         ADCON0,GO			    	;Go est mis � 1 dans le registre ADCON0 pour faire le convertisseur analogique num�rique
	affichemesure
		btfsc       ADCON0,GO
		goto        affichemesure                       ;on boucle sur affichemesure tant qu'on a pas toutes les donn�es de la tension
		call        conversionVal                ;conversion de binaire � ascii dans le cas o� ADCON0 = 0
		call        envoie						 ;affiche l'unit� convertie en ascii
		movlw       ','							 
		call        envoie						 ;affiche la virgule 
		call        conversionVal
		movfw       valDecDecimale				 
		call		envoie						 ;affiche la d�cimale convertie en ascii
		movlw       'V'							 
		call        envoie					     ;affiche l'unit� Volt
		movlw       '\n'						 ;retour � la ligne
		call        envoie						  
		movlw       '\r'						 ;mise du curseur en d�but de ligne
		call        envoie
		
		return

selectionModeA							;Affichage du mode automatique sur le terminal
	movlw 'A'							;permet de connaitre le mode de fonctionnement actuel sur le terminal
	call envoie							;Envoi du caract�re A sur le terminal
	movlw ':'
	call envoie							;Envoi du caract�re ":" sur le terminal
	movlw ' '
	call envoie							;Envoi du caract�re " " sur le terminal
	call recupValToPrint				;affiche la valeur de la tension lue
	return

selectionModeM							;Affichage du mode manuel sur le terminal						
	movlw 'M'							;permet de connaitre le mode de fonctionnement actuel sur le terminal
	call envoie							;Envoi du caract�re M sur le terminal
	movlw ':'
	call envoie							;Envoi du caract�re ":" sur le terminal
	movlw ' '
	call envoie							;Envoi du caract�re " " sur le terminal
	call recupValToPrint				;affiche la valeur de la tension lue
	return

lectureMode
	banksel PIR1				
	btfss PIR1, RCIF			;si le buffer qui recoit les informations USART (RCREG) est plein, alors je passe la prochaine instruction et je traite la demande
	return						;cas o� aucun caract�re n'a �t� rentr�. On boucle jusqu'� obtenir un caract�re
	
	banksel RCREG				;RCIF reset si RCREG est lu et vide  
	
	lectureauto
		movlw 'a'
		subwf RCREG, 0			;soustraire la valeur entr�e par a
		btfss STATUS, Z			;skip si RCREG contient "a" et donc que l'op�ration = 0. Sinon on va tester le mode "� la demande"
		goto lecturedemande
		bsf statbtn, 0			;mise en mode "automatique" en mettant le bit 0 � 1
	return
		
	lecturedemande
		movlw 'r'
		subwf RCREG, 0			;soustraire la valeur entr�e par r
		btfss STATUS, Z			;skip si RCREG contient "r" et donc que l'op�ration = 0. Sinon on regarde si l'utilisateur a rentr� un caract�re
		go to demandeenvoyee	;attente du caract�re "d" entr�e par l'utilisateur pour afficher la tension
		bcf statbtn, 0			;mise en mode "� la demande" en mettant le bit 0 � 0
	return
		
	demandeenvoyee
		btfsc statbtn, 0		;test si le mode est devenu "automatique". Si toujours "� la demande" alors on skip le return
		return
		
		movlw 'd'
		subwf RCREG,0			;soustraire la valeur entr�e par d
		btfss STATUS, Z			;skip si RCREG contient "d" et donc que l'op�ration = 0. Sinon on va tester le mode "� la demande"
		return			;retourne dans le mode automatique si soustraction != 0
		call selectionModeM
		
main
	
	btfss statbtn, 0 					;je test si le mode manuel a �t� activ� ou non
	goto entreemanu
	
	entreeauto
		envoyer
			call selectionModeA			;affichage sur le terminal de "A : " pour dire que le programme est en automatique
			call recupValToPrint		;affichage de la valeur de la tension 
			
			;utilisation du timer pour cadencer l'affichage � 1sec.
			movlw	.2						;comme j'initialise le compteur � 500ms, il faut compter deux fois pour avoir 1sec
			movwf	compteur				
			call	timer
			
		gestiontimermode
			call lectureMode
			btfss statbtn, 0				;si statbtn = 0 alors on repasse en manuel
			goto entreemanu
			
			banksel PIR1
			btfss PIR1, TMR1IF				;v�rification du flag d'overflow si le timer a fini d'incr�menter 62500 fois.
			goto gestiontimermode			;si le timer n'a pas finit, il boucle dans cet �tat.
			decfsz compteur, F				;si il a fini, je d�cr�mente compteur pour r�aliser un deuxi�me d�compte de 500�s
			goto attfintimer				;va rappeler le timer pour compter une deuxi�me fois
			goto envoyer					;retourne � l'�tat initial d'affichage de la tension sur le terminal
			attfintimer
			call timer
			goto gestiontimermode
			
    entreemanu
		call lectureMode
		btfss statbtn, 0									
		goto entreemanu						;reste dans le mode manuel tant que la variable statbtn est en mode manu '0'
		goto entreeauto
		
end                                       

