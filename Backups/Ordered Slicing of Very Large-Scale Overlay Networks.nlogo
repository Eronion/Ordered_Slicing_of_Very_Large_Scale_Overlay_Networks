;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;SIMULAZIONE NETLOGO BASATA SUL PAPER:ORDERING SLICING OF VERY LARGE-SCALE OVERLAY NETWORKS;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;All credits goes to the authors.;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Mark Jelasity;;;;;;;;;;;;;;;;;;;;;;;;Anne-Marie Kermarrec;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;University of Bologna, Italy;;;;;;;;;INRIA/IRISA, Rennes, France;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;jelasity@cs.unibo.it;;;;;;;;;;;;;;;;;akermarr@irisa.fr;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;; 2022 Brandon Willy Viglianisi per Unimore - Progetto per il corso di Distributed Artificial Intelligence;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
extensions [table]

globals [

  num-agents ;;Numero degli agenti

  total-num-gossip ;; Numero totale di gossip scambiati
  total-num-gossip-attivi  ;; Numero totale di gossip attivi scambiato
  total-num-gossip-passivi ;; Numero totale di gossip passivi
  slice ;; partizione del 5% con valore della proprietà più alta
  slice-per-agent
]

turtles-own [
  gossip-attivi     ;; Numero di gossip attivi scambiati dal singolo agente
  gossip-passivi    ;; Numero di gossip passivi scambiati dal singolo agente
  adress            ;; Mio indirizzo che coincide con ID dell'agente
  timestamp         ;; Timestamp da inserire nei messaggi
  proprietà         ;; Proprietà che caratterizza ogni agente
  num-random        ;; Secondo il protocollo ogni agente ha un numero randomi tra 0 e 1 che conserva per l'intera durata
  partenered-passive? ;; Flag per capire che della coppia è il partner passivo
  partnered?        ;; Sonoa accoppiato?
  partner           ;; Descrittore WHO del mio partner (impostato a "nobody" se non sono accoppiato)
  partner-history-active   ;; Una lista contenente l'ID degli agenti con cui ho fatto gossip
  partner-history-passive

  view              ;; Un numero "c" di agenti che conosco
  messaggiate?      ;; Sono stato messaggiato?
  messaggero        ;; Chi mi ha messaggiato?
  i-peer            ;; il peer selezionato per gossip passivo
  partizione?       ;; Secondo la mia previsione appartengo alla slice dei più potenti o meno

  ;; Variabile usate per scambiare il messaggio
  messaggio-num-random
  messaggio-proprietà
  messaggio-timestamp
  messaggio-adress
  messaggio-buffer

]


;;;;;;;;;;;;;;;;;;;;;;;;
;;;Procedure di setup;;;
;;;;;;;;;;;;;;;;;;;;;;;;

to setup
  clear-all
  store-initial-turtle-counts ;;Registra il numerod di agenti
  setup-turtles ;;setup gli agenti e distribuiscili random
  reset-ticks
end

to store-initial-turtle-counts
  set num-agents n-agents
end

;;setup gli agenti e distribuiscili random
to setup-turtles
  make-turtles ;;Crea gli agenti
  setup-common-variables ;; Setta le variabili degli agenti
end

;;crea gli agenti
to make-turtles
  create-turtles num-agents [  set color green ]
end

;;set the variables that all turtles share
to setup-common-variables

  ask turtles [
    set gossip-attivi 0
    set gossip-passivi 0
    set proprietà random 100
    set num-random random-float 1
    set timestamp 0
    set adress who
    set view table:make
    set messaggio-buffer table:make

    set messaggio-num-random 0.0
    set messaggio-proprietà 0
    set messaggio-timestamp 0

    set partnered? false
    set messaggiate? false
    set partner nobody
    set partenered-passive? false
    set messaggero nobody

    set partizione? false

    setxy random-xcor random-ycor

    let i 1
    let dim-view c
    repeat dim-view [
    table:put view (word "proprietà" i) -55
    table:put view (word "num-random" i) -55
    table:put view (word "timestamp" i) -55
    table:put view (word "adress" i) -55
    set i i + 1
  ]




    set partner-history-active []
    set partner-history-passive []
  ]

end


;;;;;;;;;;;;;;;;;;;;;;;;
;;;Runtime Procedures;;;
;;;;;;;;;;;;;;;;;;;;;;;;

to go
  clear-last-round
  ask turtles [ partner-up ]                          ;;Seleziona un partner random dopo un tempo random
  let partnered-turtles turtles with [ partnered? and not partenered-passive? ]
  ask partnered-turtles [ gossip-actively ]       ;;Se ho un partner faccio gossip attivo


  let messaged-turtles turtles with [ messaggiate? ]
  ask messaged-turtles [ gossip-passively (messaggero) ]           ;;Se ho ricevuto un messaggio rispondo con gossip passivo

  do-scoring
  do-calc-slice
  do-calc-slice-per-agent
  ; ask turtles[;;;print(word who ":" proprietà)]
  tick
end

to clear-last-round
  let partnered-turtles turtles with [ partnered? ]
  ask partnered-turtles [ release-partners ]
  ask turtles [ table:clear messaggio-buffer ]
end

;;release partner and turn around to leave
to release-partners
  set partnered? false
  set partner nobody
  set partenered-passive? false
  set messaggiate? False
  set messaggero nobody
  rt 180
  set label ""
end

;;have turtles try to find a partner
;;Since other turtles that have already executed partner-up may have
;;caused the turtle executing partner-up to be partnered,
;;a check is needed to make sure the calling turtle isn't partnered.

to partner-up ;;procedura per cercare un partner in modo casuale
  if (not partnered?) [              ;;Ci assicuriamo che non abbia già trovato un partner
    rt (random-float 90 - random-float 90) fd 1     ;;Ci muoviamo random
    set partner one-of (turtles-at -1 0) with [ not partnered? ]
    if partner != nobody [              ;;Se troviamo un partner ci accoppiamo
      set partnered? true
      set heading 270                   ;;Ci giriamo verso il partner
      ask partner [
        set partnered? true
        set partenered-passive? true
        set partner myself
        set heading 90
      ]
    ]
  ]
end


to gossip-actively ;;turtle procedure
  act-active
  increment-gossip-attivi
  update-history-active
end

to gossip-passively [destinatario] ;;turtle procedure
  print(word "gossip passivo chiamatao da: " destinatario)
  update-history-passive (destinatario)
  act-passive (destinatario)
  increment-gossip-passivi
end

;;update PARTNER-HISTORY
to update-history-active
  set partner-history-active (insert-item 0 partner-history-active ([who] of partner))
end

;;update PARTNER-HISTORY
to update-history-passive [destinatario]
  set partner-history-passive (insert-item 0 partner-history-passive ([who] of destinatario))
end



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;Qui implementiamo le azioni;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

to act-active
  print("-------------------ACT ACTIVE------------------------")
  print(word "SONO LA TURTLE num :" who)

  let buffer table:make
  set buffer view
  table:put buffer "proprietà0" proprietà
  table:put buffer  "num-random0" num-random
  table:put buffer  "timestamp0" ticks
  table:put buffer "adress0" adress

  print(word "invio buffer a partner per farmi rispondere passivamente da " who " :" buffer)
  ask partner [set messaggio-buffer [buffer] of myself]

  ;;Faccio rispondere al partner passivamente
  ;print(word "sono me " who)
  print(word "Chiamata passiva da " who "verso" partner)
  ask partner [ gossip-passively (myself) ]
  print(word "buffer passivo ricevuto  da " who " :" messaggio-buffer)

  ;;QUI ORDINO LA VIEW CON FRESHEST C ENTRIES

  let i 0
  let timestamps []
  let max-timestamps []
  print(word "sono " who)
  print(word "active views prima di timestamp:" view)
  print(word "active buffer prima di timestamp:" messaggio-buffer)
  repeat c + 1 [
    set timestamps (insert-item i timestamps (table:get-or-default messaggio-buffer (word "timestamp" i) -55) )
    print(word "item mess buff: " (table:get-or-default messaggio-buffer (word "timestamp" i) -55))
    if i > 0 [set timestamps (insert-item i timestamps (table:get-or-default view (word "timestamp" i) -55) )]
    print(word "item mess buff: " (table:get-or-default view (word "timestamp" i) -55))
    set i i + 1
    ]
  print(word "active primestam prima di sort:" timestamps)
  set timestamps (sort timestamps)
  print(word "active primesta dopo di sort:" timestamps)

  set i (((table:length view) / 4) - 1)
  repeat (((table:length view) / 4)) [
    print(word "gen" i)
    if (item i timestamps != -55)[
    print(word "iterazione" i "-1")
    set max-timestamps (insert-item 0 max-timestamps (item i timestamps) )
    ]
    if (item i timestamps = -55)[
      print(word "iterazione" i "-1")
      set max-timestamps (insert-item 0 max-timestamps -88 )
    ]
    set i i - 1
    ]
  print(word "max timestamp:" max-timestamps)

  print(word "sono: " who "e le lunghezze di view e buffer sono")
  print(table:length view)
  print(table:length messaggio-buffer)


  set i 0
  let z 0
  let y 0
  let view-temp table:make
  repeat c   [
    set z 0
    repeat c  [
      print(word "i= " i)
      print(word "z= " z)
      print(word "y= " y)
      if y < c  [
        if ((table:get messaggio-buffer (word "timestamp" i)) = (item z max-timestamps))[
          print(word "pass-1: " (table:get-or-default messaggio-buffer (word "proprietà" i) -98))
          print(word "id= " i)
          print(word "zd= " z)
          print(word "zd= " y)
          table:put view-temp (word "proprietà" y) (table:get-or-default messaggio-buffer (word "proprietà" i) -98)
          table:put view-temp (word "num-random" y) (table:get-or-default messaggio-buffer (word "num-random" i) -98)
          table:put view-temp (word "timestamp" y) (table:get-or-default messaggio-buffer (word "timestamp" i) -98)
          table:put view-temp (word "adress" y) (table:get-or-default messaggio-buffer (word "adress" i) -98)
          set y y + 1
        ]
        if ((table:get view (word "timestamp" i)) = (item z max-timestamps))[
           if i > 0 [
          print(word "pass-2: " (table:get-or-default view (word "proprietà" i) -98))
             print(word "id= " i)
          print(word "zd= " z)
          print(word "zd= " y)

          table:put view-temp (word "proprietà" y) (table:get-or-default view (word "proprietà" i) -98)
          table:put view-temp (word "num-random" y)(table:get-or-default view (word "num-random" i) -98)
          table:put view-temp (word "timestamp" y) (table:get-or-default view (word "timestamp" i) -98)
          table:put view-temp (word "adress" y) (table:get-or-default view (word "adress" i) -98)
            ]
          set y y + 1

      ]

      ]
      set z z + 1
    ]
    set i i + 1
  ]


  print(word "sono: " who "e la mia view-temp è " view-temp)
  set i 0
  table:clear view
  repeat c [
    table:put view (word "proprietà" (i + 1)) (table:get-or-default view-temp (word "proprietà" i) -57)
    table:put view (word "num-random" (i + 1)) (table:get-or-default view-temp (word "num-random" i) -57)
    table:put view (word "timestamp" (i + 1)) (table:get-or-default view-temp (word "timestamp" i) -57)
    table:put view (word "adress" (i + 1)) (table:get-or-default view-temp (word "adress" i) -57)
    set i i + 1
      ]
  print(word "Active view da temp-view: " view)

  ;;QUI SELEZIONO IL PEER A CUI INVIARE
  ;;IL PEER SUCH THAT (proprietà_suo - proprietà_mio)*(num_random_suo - num_random_mio)<0
  ;;set i-peer 4 ;;Per ora a caso
  set i 1
  let proprietà-suo -2
  let num-random-suo -3
  repeat c [
    set proprietà-suo (table:get-or-default view (word "proprietà" i) -98)
    set num-random-suo (table:get-or-default view (word "num-random" i) -98)
    print(word "num random suo :" num-random-suo)
    print(word "proprietà suo :" proprietà-suo)
    print(word "num random  :" num-random)
    print(word "proprietà :" proprietà)
    if ((proprietà-suo != -98) and (num-random-suo != -98))[
    if (((proprietà - proprietà-suo) * (num-random - num-random-suo)) < 0) [
      set i-peer (table:get-or-default view (word "adress" i) -77)
    ]]
    set i i + 1
  ]
  print(word "peer selected :" i-peer)
  if ((i-peer != -77) and (i-peer != who))[
    let temp-num-random num-random
    set num-random ([ num-random ] of (turtle i-peer))
    ask (turtle i-peer) [
      print(word "sono il peer: Swap num-random era " num-random)
      set num-random [ temp-num-random ] of myself
      print(word "Sono il peer: ora è " num-random)
]
print(word "Swap num-random era " temp-num-random "ora è " num-random)

    ask partner [ update-view-passive ]
  ]



  ;;QUI INVIO AL PEER LE MIO INFO
  ;;;;print i-peer
;  ask (turtle i-peer) [set messaggio-proprietà [ proprietà ] of myself]
;  ask (turtle i-peer) [set messaggio-num-random [ num-random ] of myself]
;  ask (turtle i-peer) [set messaggio-timestamp ticks]
;  ask (turtle i-peer) [set messaggio-adress [ adress ] of myself]
;  ask (turtle i-peer) [set messaggiate? True]
;  ask (turtle i-peer) [set messaggero myself]
  print("-------------------FINE ACT ACTIVE------------------------")
end

to act-passive [destinatario]
  print("-------------------ACT PASSIVE------------------------")
  print(word "SONO LA TURTLE num :" who)
  print(word "Mi è arrivata questa tabella passivamente e sono chi deve agire pass " who ": " messaggio-buffer)

  ;;QUI SCAMBIO BUFFER E NON SOLO UN MESSAGGIO, QUINDI L'INTERA TABLE + ME
  print (word "destinatario: " destinatario)
;  ask destinatario [set messaggio-proprietà [ proprietà ] of myself]
;  ask destinatario [set messaggio-num-random [ num-random ] of myself]
;  ask destinatario [set messaggio-timestamp ticks]
;  ask destinatario [set messaggio-adress myself]
  let buffer table:make
  set buffer view
  table:put buffer "proprietà0" proprietà
  table:put buffer  "num-random0" num-random
  table:put buffer  "timestamp0" ticks
  table:put buffer "adress0" adress
  ask destinatario [
    set messaggio-buffer ([buffer] of myself)
    print(word "Mi è arrivata questa tabella passivamente e sono il destinarario " who ": " messaggio-buffer)
  ]

  print(word "Invio tabella passivamente a" destinatario ":" buffer)
  print(word "MEntre da passivo questa è la mia view " view)
  print("-------------------FINE ACT Passive------------------------")
end

to update-view-passive
  print("-------------------UPDATE VIEW PASSIVE------------------------")
  ;;QUI AGGIORNO LA VIEW COME LE FRESHEST C ENTRIES DEL MIO BUFFER-RIVEVUTO UNITO ALLA MIA VIEW
  let i 0
  let timestamps []
  let max-timestamps []
  print(word "sono " who)
  print(word "Passive views prima di timestamp:" view)
  print(word "Passive buffer prima di timestamp:" messaggio-buffer)
  print(word "lunghezza messaggio buffer: " table:length  messaggio-buffer)
  print(word "lunghezza view: " table:length  view)
  repeat c + 1 [
    set timestamps (insert-item i timestamps (table:get-or-default messaggio-buffer (word "timestamp" i) -55) )
    print(word "item mess buff: " (table:get-or-default messaggio-buffer (word "timestamp" i) -55))
    if i > 0 [set timestamps (insert-item i timestamps (table:get-or-default view (word "timestamp" i) -55) )]
    print(word "item mess buff: " (table:get-or-default view (word "timestamp" i) -55))
    set i i + 1
    ]
  print(word "Passive primestam prima di sort:" timestamps)
  set timestamps (sort timestamps)
  print(word "Passive primesta dopo di sort:" timestamps)

  set i (((table:length view) / 4) - 1)
  repeat (((table:length view) / 4)) [
    print(word "gen" i)
    if (item i timestamps != -55)[
    print(word "iterazione" i "-1")
    set max-timestamps (insert-item 0 max-timestamps (item i timestamps) )
    ]
    if (item i timestamps = -55)[
      print(word "iterazione" i "-1")
      set max-timestamps (insert-item 0 max-timestamps -88 )
    ]
    set i i - 1
    ]
  print(word "Passive max timestamp:" max-timestamps)

  print(word "sono: " who)
  print(table:length view)
  print(table:length messaggio-buffer)

  set i 0
  let z 0
  let y 0
  let view-temp table:make
  repeat c   [
    set z 0
    repeat c  [
      if y < c  [
        if ((table:get messaggio-buffer (word "timestamp" i)) = (item z max-timestamps))[
          print(word "pass-1: " (table:get-or-default messaggio-buffer (word "proprietà" i) -98))
          table:put view-temp (word "proprietà" y) (table:get-or-default messaggio-buffer (word "proprietà" i) -98)
          table:put view-temp (word "num-random" y) (table:get-or-default messaggio-buffer (word "num-random" i) -98)
          table:put view-temp (word "timestamp" y) (table:get-or-default messaggio-buffer (word "timestamp" i) -98)
          table:put view-temp (word "adress" y) (table:get-or-default messaggio-buffer (word "adress" i) -98)
          set y y + 1
        ]
        if ((table:get view (word "timestamp" i)) = (item z max-timestamps))[
           if i > 0 [
          print(word "pass-2: " (table:get-or-default view (word "proprietà" i) -98))

          table:put view-temp (word "proprietà" y) (table:get-or-default view (word "proprietà" i) -98)
          table:put view-temp (word "num-random" y)(table:get-or-default view (word "num-random" i) -98)
          table:put view-temp (word "timestamp" y) (table:get-or-default view (word "timestamp" i) -98)
          table:put view-temp (word "adress" y) (table:get-or-default view (word "adress" i) -98)
            ]
          set y y + 1

      ]

      ]
      set z z + 1
    ]
    set i i + 1
  ]
print(word "Passive temp view " view-temp)
  set i 0
  table:clear view
  repeat c [
    table:put view (word "proprietà" (i + 1)) (table:get-or-default view-temp (word "proprietà" i) -57)
    table:put view (word "num-random" (i + 1)) (table:get-or-default view-temp (word "num-random" i) -57)
    table:put view (word "timestamp" (i + 1)) (table:get-or-default view-temp (word "timestamp" i) -57)
    table:put view (word "adress" (i + 1)) (table:get-or-default view-temp (word "adress" i) -57)
    set i i + 1
      ]
  print(word "Passive temp view to view " view)
  print("-------------------FINE UPDATE VIEW PASSIVE------------------------")
end


to increment-gossip-attivi
    set gossip-attivi gossip-attivi + 1
end

to increment-gossip-passivi
    set gossip-passivi gossip-passivi + 1
end

;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;Calcoli per i grafici;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;Calcola il numero di gossi
to do-scoring
  set total-num-gossip (calc-gossip)
  set total-num-gossip-attivi (calc-gossip-attivi)
  set total-num-gossip-passivi (calc-gossip-passivi)
end

;; Calcola il numero totale di gossip effettuati
to-report calc-gossip []
    report (sum [ gossip-attivi + gossip-passivi ] of turtles) / 2
end

;; Calcola il numero totale di gossip effettuati
to-report calc-gossip-attivi []
    report (sum [ gossip-attivi] of turtles) / 2
end

;; Calcola il numero totale di gossip effettuati
to-report calc-gossip-passivi []
    report (sum [ gossip-passivi ] of turtles) / 2
end

;; Calcolo la partizione
to do-calc-slice
  set slice (calc-slice)
  ask slice [ask self [set shape "circle"]]
end

to do-calc-slice-per-agent
  set slice-per-agent (calc-slice-per-agent)
  ask slice-per-agent [ask self [set color red]]
  let not-slice-per-agent turtles with [not member? self slice-per-agent]
  ask not-slice-per-agent [ask self [set color green]]
end

;; reporto la percentuale di agenti con la priprietà max
to-report calc-slice []
    report max-n-of ((num-agents / 100) * 50) turtles [proprietà]
end

to-report calc-slice-per-agent []
    report min-n-of ((num-agents / 100) * 50) turtles [num-random]
end



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;2022 Brandon Willy Viglianisi per Unimore - Progetto per il corso di Distributed Artificial Intelligence;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
@#$#@#$#@
GRAPHICS-WINDOW
733
32
1042
342
-1
-1
60.2
1
10
1
1
1
0
1
1
1
-2
2
-2
2
1
1
1
ticks
10.0

BUTTON
8
19
86
62
NIL
setup
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
85
19
174
62
NIL
go
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
0

SLIDER
10
79
266
112
n-agents
n-agents
2
1000
2.0
2
1
NIL
HORIZONTAL

BUTTON
174
19
260
63
go once
go
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
0

PLOT
10
173
590
421
Grafico
tempo
numero gossip
0.0
10.0
0.0
10.0
true
true
"" ""
PENS
"Totali" 1.0 1 -13840069 true "" "plot total-num-gossip"
"Attivi" 1.0 0 -13345367 true "" "plot total-num-gossip-attivi"
"Passivi" 1.0 0 -2674135 true "" "plot total-num-gossip-passivi"

MONITOR
306
74
462
123
Numero totali di gossip
total-num-gossip
1
1
12

SLIDER
11
121
183
154
c
c
0
20
2.0
1
1
NIL
HORIZONTAL

@#$#@#$#@
## WHAT IS IT?



## HOW IT WORKS

The PD TWO PERSON ITERATED model demonstrates an interesting concept: When interacting with someone over time in a prisoner's dilemma scenario, it is possible to tune your strategy to do well with theirs. Each possible strategy has unique strengths and weaknesses that appear through the course of the game. For instance, always defect does best of any against the random strategy, but poorly against itself. Tit-for-tat does poorly with the random strategy, but well with itself.

This makes it difficult to determine a single "best" strategy. One such approach to doing this is to create a world with multiple agents playing a variety of strategies in repeated prisoner's dilemma situations. This model does just that. The turtles with different strategies wander around randomly until they find another turtle to play with. (Note that each turtle remembers their last interaction with each other turtle. While some strategies don't make use of this information, other strategies do.)

Payoffs

When two turtles interact, they display their respective payoffs as labels.

Each turtle's payoff for each round will determined as follows:

```text
             | Partner's Action
  Turtle's   |
   Action    |   C       D
 ------------|-----------------
       C     |   3       0
 ------------|-----------------
       D     |   5       1
 ------------|-----------------
  (C = Cooperate, D = Defect)
```

(Note: This way of determining payoff is the opposite of how it was done in the PD BASIC model. In PD BASIC, you were awarded something bad- jail time. In this model, something good is awarded- money.)

## HOW TO USE IT

### Buttons

SETUP: Setup the world to begin playing the multi-person iterated prisoner's dilemma. The number of turtles and their strategies are determined by the slider values.

GO: Have the turtles walk around the world and interact.

GO ONCE: Same as GO except the turtles only take one step.

### Sliders

N-STRATEGY: Multiple sliders exist with the prefix N- then a strategy name (e.g., n-cooperate). Each of these determines how many turtles will be created that use the STRATEGY. Strategy descriptions are found below:

### Strategies

RANDOM - randomly cooperate or defect

COOPERATE - always cooperate

DEFECT - always defect

TIT-FOR-TAT - If an opponent cooperates on this interaction cooperate on the next interaction with them. If an opponent defects on this interaction, defect on the next interaction with them. Initially cooperate.

UNFORGIVING - Cooperate until an opponent defects once, then always defect in each interaction with them.

UNKNOWN - This strategy is included to help you try your own strategies. It currently defaults to Tit-for-Tat.

### Plots

AVERAGE-PAYOFF - The average payoff of each strategy in an interaction vs. the number of iterations. This is a good indicator of how well a strategy is doing relative to the maximum possible average of 5 points per interaction.

## THINGS TO NOTICE

Set all the number of player for each strategy to be equal in distribution.  For which strategy does the average-payoff seem to be highest?  Do you think this strategy is always the best to use or will there be situations where other strategy will yield a higher average-payoff?

Set the number of n-cooperate to be high, n-defects to be equivalent to that of n-cooperate, and all other players to be 0.  Which strategy will yield the higher average-payoff?

Set the number of n-tit-for-tat to be high, n-defects to be equivalent to that of n-tit-for-tat, and all other playerst to be 0.  Which strategy will yield the higher average-payoff?  What do you notice about the average-payoff for tit-for-tat players and defect players as the iterations increase?  Why do you suppose this change occurs?

Set the number n-tit-for-tat to be equal to the number of n-cooperate.  Set all other players to be 0.  Which strategy will yield the higher average-payoff?  Why do you suppose that one strategy will lead to higher or equal payoff?

## THINGS TO TRY

1. Observe the results of running the model with a variety of populations and population sizes. For example, can you get cooperate's average payoff to be higher than defect's? Can you get Tit-for-Tat's average payoff higher than cooperate's? What do these experiments suggest about an optimal strategy?

2. Currently the UNKNOWN strategy defaults to TIT-FOR-TAT. Modify the UNKOWN and UNKNOWN-HISTORY-UPDATE procedures to execute a strategy of your own creation. Test it in a variety of populations.  Analyze its strengths and weaknesses. Keep trying to improve it.

3. Relate your observations from this model to real life events. Where might you find yourself in a similar situation? How might the knowledge obtained from the model influence your actions in such a situation? Why?

## EXTENDING THE MODEL

Relative payoff table - Create a table which displays the average payoff of each strategy when interacting with each of the other strategies.

Complex strategies using lists of lists - The strategies defined here are relatively simple, some would even say naive.  Create a strategy that uses the PARTNER-HISTORY variable to store a list of history information pertaining to past interactions with each turtle.

Evolution - Create a version of this model that rewards successful strategies by allowing them to reproduce and punishes unsuccessful strategies by allowing them to die off.

Noise - Add noise that changes the action perceived from a partner with some probability, causing misperception.

Spatial Relations - Allow turtles to choose not to interact with a partner.  Allow turtles to choose to stay with a partner.

Environmental resources - include an environmental (patch) resource and incorporate it into the interactions.

## NETLOGO FEATURES

Note the use of the `to-report` keyword in the `calc-score` procedure to report a number.

Note the use of lists and turtle ID's to keep a running history of interactions in the `partner-history` turtle variable.

Note how agentsets that will be used repeatedly are stored when created and reused to increase speed.

## RELATED MODELS

PD Basic, PD Two Person Iterated, PD Basic Evolutionary

## HOW TO CITE

If you mention this model or the NetLogo software in a publication, we ask that you include the citations below.

For the model itself:

* Wilensky, U. (2002).  NetLogo PD N-Person Iterated model.  http://ccl.northwestern.edu/netlogo/models/PDN-PersonIterated.  Center for Connected Learning and Computer-Based Modeling, Northwestern University, Evanston, IL.

Please cite the NetLogo software as:

* Wilensky, U. (1999). NetLogo. http://ccl.northwestern.edu/netlogo/. Center for Connected Learning and Computer-Based Modeling, Northwestern University, Evanston, IL.

## COPYRIGHT AND LICENSE

Copyright 2002 Uri Wilensky.

![CC BY-NC-SA 3.0](http://ccl.northwestern.edu/images/creativecommons/byncsa.png)

This work is licensed under the Creative Commons Attribution-NonCommercial-ShareAlike 3.0 License.  To view a copy of this license, visit https://creativecommons.org/licenses/by-nc-sa/3.0/ or send a letter to Creative Commons, 559 Nathan Abbott Way, Stanford, California 94305, USA.

Commercial licenses are also available. To inquire about commercial licenses, please contact Uri Wilensky at uri@northwestern.edu.

This model was created as part of the projects: PARTICIPATORY SIMULATIONS: NETWORK-BASED DESIGN FOR SYSTEMS LEARNING IN CLASSROOMS and/or INTEGRATED SIMULATION AND MODELING ENVIRONMENT. The project gratefully acknowledges the support of the National Science Foundation (REPP & ROLE programs) -- grant numbers REC #9814682 and REC-0126227.

<!-- 2002 -->
@#$#@#$#@
default
true
0
Polygon -7500403 true true 150 5 40 250 150 205 260 250

airplane
true
0
Polygon -7500403 true true 150 0 135 15 120 60 120 105 15 165 15 195 120 180 135 240 105 270 120 285 150 270 180 285 210 270 165 240 180 180 285 195 285 165 180 105 180 60 165 15

arrow
true
0
Polygon -7500403 true true 150 0 0 150 105 150 105 293 195 293 195 150 300 150

box
false
0
Polygon -7500403 true true 150 285 285 225 285 75 150 135
Polygon -7500403 true true 150 135 15 75 150 15 285 75
Polygon -7500403 true true 15 75 15 225 150 285 150 135
Line -16777216 false 150 285 150 135
Line -16777216 false 150 135 15 75
Line -16777216 false 150 135 285 75

bug
true
0
Circle -7500403 true true 96 182 108
Circle -7500403 true true 110 127 80
Circle -7500403 true true 110 75 80
Line -7500403 true 150 100 80 30
Line -7500403 true 150 100 220 30

butterfly
true
0
Polygon -7500403 true true 150 165 209 199 225 225 225 255 195 270 165 255 150 240
Polygon -7500403 true true 150 165 89 198 75 225 75 255 105 270 135 255 150 240
Polygon -7500403 true true 139 148 100 105 55 90 25 90 10 105 10 135 25 180 40 195 85 194 139 163
Polygon -7500403 true true 162 150 200 105 245 90 275 90 290 105 290 135 275 180 260 195 215 195 162 165
Polygon -16777216 true false 150 255 135 225 120 150 135 120 150 105 165 120 180 150 165 225
Circle -16777216 true false 135 90 30
Line -16777216 false 150 105 195 60
Line -16777216 false 150 105 105 60

car
false
0
Polygon -7500403 true true 300 180 279 164 261 144 240 135 226 132 213 106 203 84 185 63 159 50 135 50 75 60 0 150 0 165 0 225 300 225 300 180
Circle -16777216 true false 180 180 90
Circle -16777216 true false 30 180 90
Polygon -16777216 true false 162 80 132 78 134 135 209 135 194 105 189 96 180 89
Circle -7500403 true true 47 195 58
Circle -7500403 true true 195 195 58

circle
false
0
Circle -7500403 true true 0 0 300

circle 2
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240

cow
false
0
Polygon -7500403 true true 200 193 197 249 179 249 177 196 166 187 140 189 93 191 78 179 72 211 49 209 48 181 37 149 25 120 25 89 45 72 103 84 179 75 198 76 252 64 272 81 293 103 285 121 255 121 242 118 224 167
Polygon -7500403 true true 73 210 86 251 62 249 48 208
Polygon -7500403 true true 25 114 16 195 9 204 23 213 25 200 39 123

cylinder
false
0
Circle -7500403 true true 0 0 300

dot
false
0
Circle -7500403 true true 90 90 120

face happy
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 255 90 239 62 213 47 191 67 179 90 203 109 218 150 225 192 218 210 203 227 181 251 194 236 217 212 240

face neutral
false
0
Circle -7500403 true true 8 7 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Rectangle -16777216 true false 60 195 240 225

face sad
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 168 90 184 62 210 47 232 67 244 90 220 109 205 150 198 192 205 210 220 227 242 251 229 236 206 212 183

fish
false
0
Polygon -1 true false 44 131 21 87 15 86 0 120 15 150 0 180 13 214 20 212 45 166
Polygon -1 true false 135 195 119 235 95 218 76 210 46 204 60 165
Polygon -1 true false 75 45 83 77 71 103 86 114 166 78 135 60
Polygon -7500403 true true 30 136 151 77 226 81 280 119 292 146 292 160 287 170 270 195 195 210 151 212 30 166
Circle -16777216 true false 215 106 30

flag
false
0
Rectangle -7500403 true true 60 15 75 300
Polygon -7500403 true true 90 150 270 90 90 30
Line -7500403 true 75 135 90 135
Line -7500403 true 75 45 90 45

flower
false
0
Polygon -10899396 true false 135 120 165 165 180 210 180 240 150 300 165 300 195 240 195 195 165 135
Circle -7500403 true true 85 132 38
Circle -7500403 true true 130 147 38
Circle -7500403 true true 192 85 38
Circle -7500403 true true 85 40 38
Circle -7500403 true true 177 40 38
Circle -7500403 true true 177 132 38
Circle -7500403 true true 70 85 38
Circle -7500403 true true 130 25 38
Circle -7500403 true true 96 51 108
Circle -16777216 true false 113 68 74
Polygon -10899396 true false 189 233 219 188 249 173 279 188 234 218
Polygon -10899396 true false 180 255 150 210 105 210 75 240 135 240

house
false
0
Rectangle -7500403 true true 45 120 255 285
Rectangle -16777216 true false 120 210 180 285
Polygon -7500403 true true 15 120 150 15 285 120
Line -16777216 false 30 120 270 120

leaf
false
0
Polygon -7500403 true true 150 210 135 195 120 210 60 210 30 195 60 180 60 165 15 135 30 120 15 105 40 104 45 90 60 90 90 105 105 120 120 120 105 60 120 60 135 30 150 15 165 30 180 60 195 60 180 120 195 120 210 105 240 90 255 90 263 104 285 105 270 120 285 135 240 165 240 180 270 195 240 210 180 210 165 195
Polygon -7500403 true true 135 195 135 240 120 255 105 255 105 285 135 285 165 240 165 195

line
true
0
Line -7500403 true 150 0 150 300

line half
true
0
Line -7500403 true 150 0 150 150

pentagon
false
0
Polygon -7500403 true true 150 15 15 120 60 285 240 285 285 120

person
false
0
Circle -7500403 true true 110 5 80
Polygon -7500403 true true 105 90 120 195 90 285 105 300 135 300 150 225 165 300 195 300 210 285 180 195 195 90
Rectangle -7500403 true true 127 79 172 94
Polygon -7500403 true true 195 90 240 150 225 180 165 105
Polygon -7500403 true true 105 90 60 150 75 180 135 105

plant
false
0
Rectangle -7500403 true true 135 90 165 300
Polygon -7500403 true true 135 255 90 210 45 195 75 255 135 285
Polygon -7500403 true true 165 255 210 210 255 195 225 255 165 285
Polygon -7500403 true true 135 180 90 135 45 120 75 180 135 210
Polygon -7500403 true true 165 180 165 210 225 180 255 120 210 135
Polygon -7500403 true true 135 105 90 60 45 45 75 105 135 135
Polygon -7500403 true true 165 105 165 135 225 105 255 45 210 60
Polygon -7500403 true true 135 90 120 45 150 15 180 45 165 90

square
false
0
Rectangle -7500403 true true 30 30 270 270

square 2
false
0
Rectangle -7500403 true true 30 30 270 270
Rectangle -16777216 true false 60 60 240 240

star
false
0
Polygon -7500403 true true 151 1 185 108 298 108 207 175 242 282 151 216 59 282 94 175 3 108 116 108

target
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240
Circle -7500403 true true 60 60 180
Circle -16777216 true false 90 90 120
Circle -7500403 true true 120 120 60

tree
false
0
Circle -7500403 true true 118 3 94
Rectangle -6459832 true false 120 195 180 300
Circle -7500403 true true 65 21 108
Circle -7500403 true true 116 41 127
Circle -7500403 true true 45 90 120
Circle -7500403 true true 104 74 152

triangle
false
0
Polygon -7500403 true true 150 30 15 255 285 255

triangle 2
false
0
Polygon -7500403 true true 150 30 15 255 285 255
Polygon -16777216 true false 151 99 225 223 75 224

truck
false
0
Rectangle -7500403 true true 4 45 195 187
Polygon -7500403 true true 296 193 296 150 259 134 244 104 208 104 207 194
Rectangle -1 true false 195 60 195 105
Polygon -16777216 true false 238 112 252 141 219 141 218 112
Circle -16777216 true false 234 174 42
Rectangle -7500403 true true 181 185 214 194
Circle -16777216 true false 144 174 42
Circle -16777216 true false 24 174 42
Circle -7500403 false true 24 174 42
Circle -7500403 false true 144 174 42
Circle -7500403 false true 234 174 42

turtle
true
0
Polygon -10899396 true false 215 204 240 233 246 254 228 266 215 252 193 210
Polygon -10899396 true false 195 90 225 75 245 75 260 89 269 108 261 124 240 105 225 105 210 105
Polygon -10899396 true false 105 90 75 75 55 75 40 89 31 108 39 124 60 105 75 105 90 105
Polygon -10899396 true false 132 85 134 64 107 51 108 17 150 2 192 18 192 52 169 65 172 87
Polygon -10899396 true false 85 204 60 233 54 254 72 266 85 252 107 210
Polygon -7500403 true true 119 75 179 75 209 101 224 135 220 225 175 261 128 261 81 224 74 135 88 99

wheel
false
0
Circle -7500403 true true 3 3 294
Circle -16777216 true false 30 30 240
Line -7500403 true 150 285 150 15
Line -7500403 true 15 150 285 150
Circle -7500403 true true 120 120 60
Line -7500403 true 216 40 79 269
Line -7500403 true 40 84 269 221
Line -7500403 true 40 216 269 79
Line -7500403 true 84 40 221 269

x
false
0
Polygon -7500403 true true 270 75 225 30 30 225 75 270
Polygon -7500403 true true 30 75 75 30 270 225 225 270
@#$#@#$#@
NetLogo 6.2.0
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
default
0.0
-0.2 0 0.0 1.0
0.0 1 1.0 0.0
0.2 0 0.0 1.0
link direction
true
0
Line -7500403 true 150 150 90 180
Line -7500403 true 150 150 210 180
@#$#@#$#@
0
@#$#@#$#@
