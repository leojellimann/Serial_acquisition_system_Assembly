;Réalisation d'un système d'acquisiton série pour PC
;Programme réalisé par Léo Jellimann
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
    movlw         B'00100110'	;autorisation de la transmission TXEN, vitesse des bauds haute en asynchrone, bit TMRT à 1 pour vider le registre TSR
    movwf        TXSTA  		;ajout de la configuration

    banksel SPBRG							;configuration de la fréquence d'envoi des données au port série
    movlw         B'0000000000011001'		;SPBRG = 25 pour une fréquence à 4MHz à 9600 bauds en asynchrone
    movwf         SPBRG  
    
    banksel RCSTA				;configuration de la reception des status et le controle des registres pour USART
    movlw         B'10000000'	;autorisation du bit du port série SPEN
    movwf         RCSTA 
       
    ;configuration du convertisseur analogique/numérique
	banksel ADCON0        
    movlw        B'01000001'        	;Utilisation de Fosc/8 et autorisation de l'utilisation du convertisseur analogique/numérique
    movwf        ADCON0
	
    banksel ADCON1
    movlw        B'00001110'        	;Configuration du convertisseur pour avoir 7 ports numériques et les tensions de référence Vref+ = VDD et Vref- = VSS
    movwf        ADCON1                 

  
    ;configuration du timer 1 pour compter 1sec
    banksel T1CON
    movlw	B'00110000'	    	;selection du prescaler 1:8 pour pouvoir compter assez longtemps pour 1sec
    movwf T1CON
    
    banksel PIR1
    bcf 	PIR1, TMR1IF
    
    
	bsf statbtn, 0				;initialisation du mode automatique
	call envoie					;on veut démarrer la communication USART
    goto         main
    

;fonctions
    
envoie                            
    banksel PIR1                ;démarrage de la communication USART
	verifmsg
    btfss        PIR1, TXIF     ;verification si la communication est libre. Le flag du bit TXIF est mis à 0 en chargeant TXREG
    goto         verifmsg
	
    banksel      TXREG          
    movwf        TXREG			;envoi du message dans le registre TXREG
	
	verif        
		banksel      TXSTA
		btfsc        TXSTA, TRMT    ;verification si la communication a eu lieu
		goto         verif 			;on boucle tant que TRMT est à 1. TRMT = 1 --> TSR = vide. Quand TMRT = 0 alors communication effectuée.
		return  
    
 
conversionVal

		banksel       ADRESH                        ;Selection du registre 
		movfw         ADRESH                        ;Envoie dans le registre W la valeur de la conversion Ana/Num de 0 à 5V
		movwf         valBinaire
		movlw         D'0'							;On initialise l'entier et le décimal à 0 pour réécrire la nouvelle valeur lue
		movwf         valDecDecimale
		movwf         valDecEntiere
		goto          conversionUnit

	conversionUnit
		movlw        D'51'                          ;51 est la valeur pour l'unité du V 0,1,2,3,4 ou 5
		subwf        valBinaire,0             		;Calcul de W (=51) - valBinaire. On stocke le résultat dans le registre W
		btfss        STATUS,C                       ;Permet de vérifier si la carry d'overflow=1. Si C = 1 alors on skip l'instruction suivante, si C = 0 alors on continue normalement
						 ;C se trouve dans le registre STATUS
		goto         conversionDec					;Permet d'obtenir la valeur décimale
		incf         valDecEntiere
		movwf        valBinaire		 ;
		goto         conversionUnit

	conversionDec
		movlw        D'5'                            ;5 est la valeur pour 0,1V. On soustrait 5 pour avoir les décimales
		subwf        valBinaire,0		 	 ;Calcul de W (=5) - valBinaire. On stocke le résultat dans le registre W 
		btfss        STATUS,C                ;Permet de vérifier si la carry d'overflow=1. Si C = 1 alors on skip l'instruction suivante, si C = 0 alors on continue normalement
		continue
		goto         conversionFin
	
		movwf        valBinaire
		movlw        D'9'
		subwf        valDecDecimale,0		 		 ;voir si la partie decimal vaut 9 et lui soustraire 9 car en ascii le caractère après 9 est ":"
		btfss        STATUS,Z			 			 ;skip si Z = 1 et donc que l'opération vaut 0
		incf         valDecDecimale
		goto         conversionUnit

	conversionFin
		movfw        valDecEntiere              
		addlw        0x30				 			;Addition de la valeur dans W de W + 0x30 pour l'avoir en mode ascii 
return                

timer
    banksel	T1CON
    bcf		T1CON, TMR1ON   ; met en arrêt le timer 1
    
    ;initialisation à 3036 du timer1
    banksel     PIR1
    bcf		PIR1, TMR1IF	;supprime le flag du timer1
    
    ;préchargement du timer à 3036
    movlw	B'11011100'
    movwf	TMR1L
    movlw	B'00001011'
    movwf	TMR1H
    
    banksel	T1CON
    bsf		T1CON, TMR1ON		;démarrage le timer1
	    
		
recupValToPrint 							;récupère la valeur de la tension et l'affiche sur le port série du PC 
	banksel ADCON0                          ;On mesure la tension entre 0 et 5V
	bsf         ADCON0,GO			    	;Go est mis à 1 dans le registre ADCON0 pour faire le convertisseur analogique numérique
	affichemesure
		btfsc       ADCON0,GO
		goto        affichemesure                       ;on boucle sur affichemesure tant qu'on a pas toutes les données de la tension
		call        conversionVal                ;conversion de binaire à ascii dans le cas où ADCON0 = 0
		call        envoie						 ;affiche l'unité convertie en ascii
		movlw       ','							 
		call        envoie						 ;affiche la virgule 
		call        conversionVal
		movfw       valDecDecimale				 
		call		envoie						 ;affiche la décimale convertie en ascii
		movlw       'V'							 
		call        envoie					     ;affiche l'unité Volt
		movlw       '\n'						 ;retour à la ligne
		call        envoie						  
		movlw       '\r'						 ;mise du curseur en début de ligne
		call        envoie
		
		return

selectionModeA							;Affichage du mode automatique sur le terminal
	movlw 'A'							;permet de connaitre le mode de fonctionnement actuel sur le terminal
	call envoie							;Envoi du caractère A sur le terminal
	movlw ':'
	call envoie							;Envoi du caractère ":" sur le terminal
	movlw ' '
	call envoie							;Envoi du caractère " " sur le terminal
	call recupValToPrint				;affiche la valeur de la tension lue
	return

selectionModeM							;Affichage du mode manuel sur le terminal						
	movlw 'M'							;permet de connaitre le mode de fonctionnement actuel sur le terminal
	call envoie							;Envoi du caractère M sur le terminal
	movlw ':'
	call envoie							;Envoi du caractère ":" sur le terminal
	movlw ' '
	call envoie							;Envoi du caractère " " sur le terminal
	call recupValToPrint				;affiche la valeur de la tension lue
	return

lectureMode
	banksel PIR1				
	btfss PIR1, RCIF			;si le buffer qui recoit les informations USART (RCREG) est plein, alors je passe la prochaine instruction et je traite la demande
	return						;cas où aucun caractère n'a été rentré. On boucle jusqu'à obtenir un caractère
	
	banksel RCREG				;RCIF reset si RCREG est lu et vide  
	
	lectureauto
		movlw 'a'
		subwf RCREG, 0			;soustraire la valeur entrée par a
		btfss STATUS, Z			;skip si RCREG contient "a" et donc que l'opération = 0. Sinon on va tester le mode "à la demande"
		goto lecturedemande
		bsf statbtn, 0			;mise en mode "automatique" en mettant le bit 0 à 1
	return
		
	lecturedemande
		movlw 'r'
		subwf RCREG, 0			;soustraire la valeur entrée par r
		btfss STATUS, Z			;skip si RCREG contient "r" et donc que l'opération = 0. Sinon on regarde si l'utilisateur a rentré un caractère
		go to demandeenvoyee	;attente du caractère "d" entrée par l'utilisateur pour afficher la tension
		bcf statbtn, 0			;mise en mode "à la demande" en mettant le bit 0 à 0
	return
		
	demandeenvoyee
		btfsc statbtn, 0		;test si le mode est devenu "automatique". Si toujours "à la demande" alors on skip le return
		return
		
		movlw 'd'
		subwf RCREG,0			;soustraire la valeur entrée par d
		btfss STATUS, Z			;skip si RCREG contient "d" et donc que l'opération = 0. Sinon on va tester le mode "à la demande"
		return			;retourne dans le mode automatique si soustraction != 0
		call selectionModeM
		
main
	
	btfss statbtn, 0 					;je test si le mode manuel a été activé ou non
	goto entreemanu
	
	entreeauto
		envoyer
			call selectionModeA			;affichage sur le terminal de "A : " pour dire que le programme est en automatique
			call recupValToPrint		;affichage de la valeur de la tension 
			
			;utilisation du timer pour cadencer l'affichage à 1sec.
			movlw	.2						;comme j'initialise le compteur à 500ms, il faut compter deux fois pour avoir 1sec
			movwf	compteur				
			call	timer
			
		gestiontimermode
			call lectureMode
			btfss statbtn, 0				;si statbtn = 0 alors on repasse en manuel
			goto entreemanu
			
			banksel PIR1
			btfss PIR1, TMR1IF				;vérification du flag d'overflow si le timer a fini d'incrémenter 62500 fois.
			goto gestiontimermode			;si le timer n'a pas finit, il boucle dans cet état.
			decfsz compteur, F				;si il a fini, je décrémente compteur pour réaliser un deuxième décompte de 500µs
			goto attfintimer				;va rappeler le timer pour compter une deuxième fois
			goto envoyer					;retourne à l'état initial d'affichage de la tension sur le terminal
			attfintimer
			call timer
			goto gestiontimermode
			
    entreemanu
		call lectureMode
		btfss statbtn, 0									
		goto entreemanu						;reste dans le mode manuel tant que la variable statbtn est en mode manu '0'
		goto entreeauto
		
end                                       

