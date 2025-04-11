extensions [ gis table]

globals [
  initial-trees burned-area
  fire_spread_rate_celsius bf_spread_rate_celsius ignition_lapse elevation slope aspect ;not used
  total-fires fire-locations temp-projection2
  head-fire-turtle heel-fire-turtle left-fire-turtle right-fire-turtle

  fire-table head-fires heel-fires left-fires right-fires
  head-num-change heel-num-change left-num-change right-num-change
  head-rel-change heel-rel-change left-rel-change right-rel-change
  distance-city-fire

  forest_value_loss
  house_loss
  index

  previous-hour-report
  hourly-reports
  numerical-change-rate
  relative-change-rate

  ;for UI
  ff-hours ff-water temp-red ff-fire-ext
  h-hours h-fire-ext
  burned-society-hec

  heli-amount ff-amount

]

breed [fires fire] ; leading edge of the fire
breed [firefighters firefighter]
breed [helicopters helicopter]
breed [ICs IC]
patches-own [p_elevation p_slope p_aspect temperature value houses updated-this-tick updated-this-tick2 patchticks]
helicopters-own [h-temperature-reduction h-cost h-location target previous-target target-sector-string]
firefighters-own [ff-temperature-reduction ff-location target previous-target target-sector-string]
fires-own [alive water sector]

to setup
  clear-all
  setup_GIS
  setup_patches
  init_var
  setup_fire
  reset-ticks
end

to go
  if ticks > 1 and (count fires = 0 or ticks >= 1980) [stop]
  ask patches [set updated-this-tick false]
  ask patches [set updated-this-tick2 false]

  general_fire_spread
  head_fire_spread
  ignite
  fire_dying


  update-fire

  if ticks = response-time or (time-strategy-update = 0) or ((ticks - response-time) mod (time-strategy-update * 60) = 0)  [
    situation-assessment ;based upon when a new strategy is decided: at response time and an interval of "time-strategy-update"
  ]
  if ticks = response-time [
    create-agents
  ]

  agents-set-target  ;set h-location ff-location
  agents-move-and-act


  ;update costs
  ask helicopters [
    if target != nobody and target != 0[
    print (word "ticks " ticks " and my target is " target " in sector " [sector] of target)
  ]]


  tick
end

;---------------SETUP-----------------------------
to setup_GIS
  set elevation gis:load-dataset "heights140Fire2014Netlogo.asc"
  gis:set-world-envelope gis:envelope-of elevation

  let horizontal-gradient gis:convolve elevation 3 3 [ 1 1 1 0 0 0 -1 -1 -1 ] 1 1
  let vertical-gradient gis:convolve elevation 3 3 [ 1 0 -1 1 0 -1 1 0 -1 ] 1 1
  set slope gis:create-raster gis:width-of elevation gis:height-of elevation gis:envelope-of elevation
  set aspect gis:create-raster gis:width-of elevation gis:height-of elevation gis:envelope-of elevation
  let x 0
  repeat (gis:width-of slope)
  [ let y 0
    repeat (gis:height-of slope)
    [ let gx gis:raster-value horizontal-gradient x y
      let gy gis:raster-value vertical-gradient x y
      if ((gx <= 0) or (gx >= 0)) and ((gy <= 0) or (gy >= 0))
      [ let s sqrt ((gx * gx) + (gy * gy))
        gis:set-raster-value slope x y s
        ifelse (gx != 0) or (gy != 0)
        [ gis:set-raster-value aspect x y atan gy gx ]
        [ gis:set-raster-value aspect x y 0 ] ]
      set y y + 1 ]
    set x x + 1 ]
  gis:set-sampling-method aspect "bilinear"

     ; Import elevation data to patches
  gis:apply-raster elevation p_elevation
     ; Import slope data to patches
  gis:apply-raster slope p_slope
     ; Import aspect data to patches
  gis:apply-raster aspect p_aspect
  if show_image[import-drawing "ImageFire2014.png"];
end

to setup_patches
    set-default-shape turtles "square" ;; make some green trees
  ask patches with [(random-float 100) <  90] ; density
    [ set pcolor green ]
  ask patches with [p_elevation < 107 ]   ;; remove trees based on height
    [ set pcolor black ]
  ask patches with [p_elevation < 90 and pxcor < 0 and pycor > -45] ;; lakes
    [ set pcolor blue ]
  ask patches with [pxcor > 17 and pxcor <= 23 and pycor > -23 and pycor <= -17] ;; houses
    [ set pcolor orange ]
  ask patches with [pxcor > 0 and pxcor <= 6 and pycor > -23 and pycor <= -17] ;; houses
    [ set pcolor orange ]

  ask patches with [pcolor = green] ;; set initial state variables
  [ set temperature 28
    set value 53000
    set patchticks 0]

  ask patches with [pcolor = orange] ;; set initial state variables
  [ set temperature 28
    set houses 2
    set patchticks 0]
end


to init_var
  set initial-trees count patches with [pcolor = green] ;; count initial patches of green trees
  set burned-area 0
  set forest_value_loss 0
  set house_loss 0
  set left-fire-turtle nobody
  set heel-fire-turtle nobody
  set left-fire-turtle nobody
  set right-fire-turtle nobody
  set fire-table [] set head-fires 0 set heel-fires 0 set left-fires 0 set right-fires 0
  set head-num-change 0 set heel-num-change 0 set left-num-change 0 set right-num-change 0
  set head-rel-change 0 set heel-rel-change 0 set left-rel-change 0 set right-rel-change 0

  set index 1
  set previous-hour-report false
  set hourly-reports []
  set numerical-change-rate []
  set relative-change-rate []
  set distance-city-fire 100

  set ff-hours 0
  set ff-water 0
  set temp-red 0
  set ff-fire-ext 0
  set h-fire-ext 0

  set h-hours 0
  set burned-society-hec 0

end

to setup_fire
  ask patches with [pxcor = 28 and pycor = -40 ] [
    set pcolor green
    ask neighbors [ set pcolor green]
    set temperature 301
  ]
end

;---------------GO----------------------------
to general_fire_spread
  ask fires [
    let my-xcor xcor
    let my-ycor ycor
    ask neighbors with [(pcolor = green or pcolor = orange ) and not updated-this-tick]
      [set temperature temperature + 2.72 ; after 100 minutes, it's spread 100 meters with rate 1 m/s (patch from 28 to 300 degrees)
       set updated-this-tick true

    ]
  ]
end

to head_fire_spread
  ask fires [
    let target-patch patch-at-heading-and-distance wind-angle 1
    ask target-patch
    [ if pcolor = green and not updated-this-tick2
      [ set temperature temperature + 3 * (wind_velocity - 3)
        set updated-this-tick2 true
      ]
    ]
  ]
end

to fire_dying
  ask fires  [
      set alive alive + 1
      if alive > 70 or water >= 2000 or not any? neighbors with [pcolor = green]
      [
      set temperature 28
      set pcolor red - 3

      if any? firefighters-here [
        set ff-fire-ext ff-fire-ext + 1
      ]
      if any? helicopters-here [
        set h-fire-ext h-fire-ext + 1
      ]
      die
    ]
  ]
end

to ignite
  ask patches with [(pcolor = green or pcolor = orange) and temperature > 300] [
    sprout-fires 1
    [
      set shape "default"
      set alive 0
      set size 1
      set forest_value_loss forest_value_loss + value
      set house_loss house_loss + houses
      set temperature 1000
      set sector "head"

      let center-x 28
      let center-y -40

      if not (xcor = center-x and ycor = center-y) [
        let angle-to-center atan (xcor - center-x) (ycor - center-y)
        let direction-to-center (angle-to-center - wind-angle) mod 360

        ; Categorize based on angle relative to the main direction
        ifelse direction-to-center < 20 or direction-to-center > 340
        [
          set sector "head"
          set heading wind-angle
          set color red
        ]

        [
          ifelse direction-to-center >= 20 and direction-to-center <= 120 [
            set sector "right-flank"
            set heading ((wind-angle + 90) mod 360)
            set color blue
          ] [
            ifelse direction-to-center > 120 and direction-to-center < 240 [
              set sector "heel"
              set heading ((wind-angle - 180) mod 360)
              set color yellow
            ] [
              set sector "left-flank"
              set heading ((wind-angle - 90) mod 360)
              set color grey
            ]
          ]
        ]
      ]
    ]
    if pcolor = orange [
      set burned-society-hec burned-society-hec + 1
    ]

    set pcolor red
    set burned-area burned-area + 1

  ]
end

;-----------Create Agents--------
to create-agents

  set heli-amount round (agent-amount * (1 - perc-ground))
  set ff-amount round (agent-amount * perc-ground)

  create-helicopters heli-amount [
    set color blue
    set shape "airplane"
    set size 8;
    setxy 0 0
  ]
  create-firefighters ff-amount [;each firefighting agents is one crew of 5 persons + 1 water truck + 1 fuel truck
    set color orange
    set shape "person"
    set size 8
    setxy 28 -40
  ]
end


;-----------STRATEGY------------

to agents-set-target

  ifelse ticks = response-time or (time-strategy-update = 0) or ((ticks - response-time) mod (time-strategy-update * 60) = 0)  [


    if strategy-choice = "largest-firesector" [ ;do something else here
      strategy-largest-fire
       print(word "update largest rel chaneg ticks: " ticks)
    ]
    if strategy-choice = "largest-rel-change" [
      strategy-largest-relchange

    ]
    if strategy-choice = "spread-agents-equally" [
      strategy-spread-agents ;behöver fixas för de uppdateras varje tick
    ]
    if strategy-choice = "protect-city" [
      strategy-protect-city
    ]
    if strategy-choice = "decentralized-decision" [
      strategy-decentralized-dec
    ]
    if strategy-choice = "go-around" [
      strategy-go-around
    ]
   ; if count fires = 0 [stop]
    ask (turtles with [breed = helicopters or breed = firefighters]) [
      set previous-target target
      set target-sector-string [sector] of target
      print (word "sectorstring in agents-set-traget: " target-sector-string )
    ]
  ]

  [ ask (turtles with [breed = helicopters or breed = firefighters]) [
    ifelse previous-target != nobody and previous-target != 0 [
      set target previous-target
    ]
    [
      if count fires = 0 [stop]
      let sector-target target-sector-string
      set target min-one-of (fires with [sector = sector-target]) [distance myself]
      print (word "sectorstring in agents-set-traget 2: " target-sector-string " or " sector-target)
    ]
    ]
  ]

    ;set target-sector-string [sector] of target ;sector left-flank right-flank heel head
    ;]

;    ask (turtles with [breed = helicopters or breed = firefighters]) [
 ;     if target-sector-string = "head" [
  ;      set target min-one-of (fires with [sector = "head"]) [distance myself]
   ;   ]
    ;  if target-sector-string = "heel" [
     ;   set target min-one-of (fires with [sector = "heel"]) [distance myself]
 ;     ]
  ;    if target-sector-string = "left-flank" [
   ;     set target min-one-of (fires with [sector = "left-flank"]) [distance myself]
    ;  ]
   ;   if target-sector-string = "right-flank" [
    ;    set target min-one-of (fires with [sector = "right-flank"]) [distance myself]
   ;   ]
    ;  print (word "sectorstring in agents-set-traget 3: " [sector] of target)
 ;   ]
  ;]



end

to strategy-largest-fire ; put all resources on most spreading sector
  set fire-table table:make

  table:put fire-table "head-fires" head-fires
  table:put fire-table "heel-fires" heel-fires
  table:put fire-table "left-fires" left-fires
  table:put fire-table "right-fires" right-fires

  let fire-values (list head-fires heel-fires left-fires right-fires)
  let largest-value max fire-values
  let fire-names ["head" "heel" "left-flank" "right-flank"]

  let largest-index position largest-value fire-values
  let largest-name item largest-index fire-names
  print (word "largest fire " largest-name)

  ask (turtles with [breed = helicopters or breed = firefighters]) [
    ; if largest-name = "head"
    set target one-of fires with [sector = largest-name]
    print (word"my target sector is: " [sector] of target)
  ]
  ; if largest-name = "heel"
  ;  [ set target heel-fire-turtle]
  ;   if largest-name = "left"
  ;   [ set target left-fire-turtle]
  ;   if largest-name = "right"
  ;   [ set target right-fire-turtle]

  ; ]


end

to strategy-largest-relchange
  ifelse length relative-change-rate > 0 [
    let latest-relative item (length relative-change-rate - 1) relative-change-rate

    ; Initialize variables to store the max value and associated key
    let max-value -10
    let max-key ""

    ; Iterate over each key in the latest-hour table
    foreach (table:keys latest-relative) [
      ?key ->  ; '?' is the current item in the list, here a key in the table
      let current-value table:get latest-relative ?key
      ; Check if the current value is greater than the max-value found so far
      if current-value > max-value [
        set max-value current-value
        set max-key ?key
      ]
    ]
    print (word "Key with the largest value: " max-key " with a value of: " max-value)

    ask (turtles with [breed = helicopters or breed = firefighters]) [
      set target one-of fires with [sector = max-key]

  ;    if max-key = "Head"
  ;    [ set target head-fire-turtle]
  ;    if max-key = "Heel"
 ;     [ set target heel-fire-turtle]
  ;    if max-key = "Left"
  ;    [ set target left-fire-turtle]
  ;    if max-key = "Right"
  ;    [ set target right-fire-turtle]
    ]
  ]
  [ ask (turtles with [breed = helicopters or breed = firefighters]) [
    set target one-of fires]
  ]
end

to strategy-spread-agents
  ask (turtles with [breed = helicopters or breed = firefighters]) [
    let possible-targets (list head-fire-turtle heel-fire-turtle left-fire-turtle right-fire-turtle)
    set target one-of possible-targets
  ]
end


to strategy-protect-city

  strategy-spread-agents

  print (word "Closest fire is " distance-city-fire)
  if distance-city-fire < 10 [ ;[distance closest-fire] of one-of city-patches < 10

    if count helicopters < 10 and count firefighters < 10 [
      create-agents
    ]
    let city-patches patches with [pcolor = 25] ;orange
    let closest-fire min-one-of fires [
      min [distance myself] of city-patches
    ]


    ask (turtles with [breed = helicopters or breed = firefighters]) [
      set target closest-fire
    ]
  ]
  if distance-city-fire < 5 [
    let city-patches patches with [pcolor = 25] ;orange
    let closest-fire min-one-of fires [
      min [distance myself] of city-patches
    ]
    if count helicopters < 10 and count firefighters < 10 [
      create-agents
    ]
    ask (turtles with [breed = helicopters or breed = firefighters]) [
      set target closest-fire
    ]
  ]

end

to strategy-decentralized-dec
  let water-patches patches with [pcolor = 105]

  ; Find the fire turtle closest to any of these blue patches
  let closest-fire min-one-of fires [
    min [distance myself] of water-patches
  ]
  ask helicopters [
    if closest-fire != nobody [
      set target closest-fire
    ]
  ]

  ask firefighters [
    let closest-fire2 min-one-of fires [distance myself]
    set target closest-fire2
  ]
end

to strategy-go-around
  ; helicopters can start at head, to two ways and always go to the closest fire
  ; fire fighters start on heel, go two ways around and always move to the closest fire
  ask firefighters [
    ifelse count fires with [sector = "heel"] > 0 [
            ;let sector-target target-sector-string
      set target min-one-of (fires with [sector = "heel"]) [distance myself]
     ; set target heel-fire-turtle
    ]
    [
      let closest-fire min-one-of fires [distance myself]
      set target closest-fire
    ]
  ]

  ask helicopters [
    ifelse count fires with [sector = "head"] > 0 [
      set target min-one-of (fires with [sector = "head"]) [distance myself]
    ]
    [
      let closest-fire min-one-of fires [distance myself]
      set target closest-fire
    ]
  ]
end


to agents-move-and-act
  ask firefighters [

    ;if previous-target != nobody
    ;[
    ;  set target previous-target
    ;]

    if target = nobody or target = 0 [ ;if one sector is already extinguished for example
      set target one-of fires
      set previous-target target
      print (word "ff target is nobody " )
    ]

    if target != nobody [
      let temp-sect [sector] of target ;can be nobody. maybe should do that if this sector is gone, move on to next sector

      ifelse any? fires-here with [sector = temp-sect] [ ; if they are on a fire in the same sector, stay and put it out
        if any? other firefighters in-radius 2 [ ;make sure firefighters are not in the same place
          let other-fire-turtle min-one-of fires with [patch-here != [patch-here] of myself] [distance myself]
          if other-fire-turtle != nobody [
            face other-fire-turtle
            fd 1
          ]
        ]
        ask fires-here [
          set water water + 120 ;this water is the capacity  of firefighters per minute
        ]
      ]
      [
        face target
        if ticks mod 8 = 0 [ fd 1 ]
      ]
    ]

    set ff-hours ff-hours + (1 / 60)
  ]

  ask helicopters [
    if ticks mod h-turnaroundtime = 0 [ ;it moves to a new location each time it has gotten water
      if previous-target != nobody
      [
        set target previous-target
      ]

      if target = nobody or target = 0 [
        set target one-of fires
        print (word "h target is nobody " )
      ]

      if target != nobody [
        move-to target

        if any? helicopters-here [

          let other-fire-turtle min-one-of fires with [patch-here != [patch-here] of myself] [distance myself]
          if other-fire-turtle != nobody [
            move-to other-fire-turtle
          ]
          ask fires-here [
            set water water + 1000 * 0.7 ;this water is the capacity of helicopters per drop. 0.7 efficiency
          ]
        ]
      ]
    ]
    set previous-target target
    set h-hours h-hours + (1 / 60)
  ]
end


to move-to-location ;not used yet
  ask helicopters [
    if h-location != 0 and h-location != nobody [
      move-to h-location

      if h-tactic = "indirect" [
        let local-fire one-of turtles-here with [breed = fires]
        ifelse [sector] of local-fire = "head" [
          set heading wind-angle  ; For head, align with wind direction
        ] [
          ifelse [sector] of local-fire = "right-flank" [
            set heading (wind-angle + 90) mod 360  ; For right flank
          ] [
            ifelse [sector] of local-fire = "heel" [
              set heading (wind-angle + 180) mod 360  ; or [heading] of local-fire ;
            ] [
              if [sector] of local-fire = "left-flank" [
                set heading (wind-angle - 90) mod 360  ; For left flank
              ]
            ]
          ]
        ]
        fd 2
        ;h-reduce-temperature
      ]

      set h-hours h-hours + (1 / 60)
    ]
  ]

  ask firefighters [
    if ff-location != 0 and ff-location != nobody [
      move-to ff-location
      ;ff-perform

      if ff-tactic = "indirect" [
        let local-fire one-of turtles-here with [breed = fires]
        ifelse [sector] of local-fire = "head" [
          set heading wind-angle  ; For head, align with wind direction
        ] [
          ifelse [sector] of local-fire = "right-flank" [
            set heading (wind-angle + 90) mod 360  ; For right flank
          ] [
            ifelse [sector] of local-fire = "heel" [
              set heading (wind-angle + 180) mod 360  ; or [heading] of local-fire
            ] [
              if [sector] of local-fire = "left-flank" [
                set heading (wind-angle - 90) mod 360  ; For left flank
              ]
            ]
          ]
        ]
        fd 2
        ;h-reduce-temperature
      ]

      set ff-hours ff-hours + (1 / 60)
    ]
  ]
end

to perform-strategy ;not used
ask helicopters [
    ;let local-fire one-of turtles-here with [breed = fires]

    if ticks mod (h-turnaroundtime * 3) = 0 [ ; drops water in 30X5 meters and extinhuish fire line. Needs three times to do one side (100 m) of a hectar
        ask patch-here [
          if pcolor = red [
            set temperature temperature - 900 ;it dies if less than 300 degrees
          ]
        if pcolor = green [
          set pcolor brown ;no forest - can also be done by reducing the temperature alot
        ]
      ]
      ;set temperature temperature - 20
      ;set h-temperature-reduction h-temperature-reduction + 20
    ]

  ]

  ask firefighters [
    if ff-tactic = "direct" [
      if ticks mod 8 = 0 [ ;eight minutes to remove fire from here
        ask patch-here [
          if pcolor = red [
            set temperature temperature - 900 ;it dies if less than 300 degrees
      ]]]
      set ff-temperature-reduction ff-temperature-reduction + 10 ;keeping track
      set temp-red temp-red + 10 ;keeping track
    ]

    if ff-tactic = "indirect-water" [
      if ticks mod 8 = 0 [ ;eight minutes to remove fire from here
        ask patch-here [
          if pcolor = green [
            set pcolor brown
      ]]]
      set ff-temperature-reduction ff-temperature-reduction + 10 ;keeping track
      set temp-red temp-red + 10 ;keeping track
    ]


    if ff-tactic = "indirect-fuel" [
      ;set-heading
      ff-removefuel
      set ff-temperature-reduction ff-temperature-reduction + 5
      set temp-red temp-red + 5 ;total temperature reduction shows in UI
    ]

    if ff-tactic = "indirect-water-standingstill" [

      if ticks = 40 [
        ;set-heading

        ifelse who mod 2 = 0 [ ;if the number is even
          show "i am an even turtle!"
          show heading
          show (word "xcor: " xcor " ycor: " ycor)

          ;show index
        ]
        [
          show "i am an uneven turtle!"
          show heading
          show (word "xcor: " xcor " ycor: " ycor)

        ]
      ]
    ]
  ]


end

;------HELICOPTERS-----------

to h-perform ; not used
  let local-fire one-of turtles-here with [breed = fires]

  if h-tactic = "direct" [
    h-reduce-temperature
  ]
  if h-tactic = "indirect" [
    if local-fire != nobody [
      ifelse [sector] of local-fire = "head" [
        set heading wind-angle  ; For head, align with wind direction
      ] [
        ifelse [sector] of local-fire = "right-flank" [
          set heading (wind-angle + 90) mod 360  ; For right flank
        ] [
          ifelse [sector] of local-fire = "heel" [
            set heading (wind-angle + 180) mod 360  ; or [heading] of local-fire ;
          ] [
            if [sector] of local-fire = "left-flank" [
              set heading (wind-angle - 90) mod 360  ; For left flank
            ]
          ]
        ]
      ]
      fd 8
      h-reduce-temperature
      ]
    ]
end

to h-reduce-temperature ;not used
  if ticks mod (h-turnaroundtime * 3) = 0 [ ; drops water in 30X5 meters and extinhuish fire line. Needs three times to do one side (100 m) of a hectar
    ask patch-here [
     if pcolor = red [
        set pcolor red - 3 ;amber
      ]
      if pcolor = green [
        set pcolor brown ;no forest
      ]
    ]
    ;set temperature temperature - 20
    ;set h-temperature-reduction h-temperature-reduction + 20
  ]
end

;------------FIREFIGHTERS----------
to ff-act
  ask firefighters [
    if ff-location != 0 and ff-location != nobody [
      move-to ff-location
      ff-perform

      set ff-hours ff-hours + (1 / 60)
    ]
  ]

end

to ff-perform ;not used

  if ff-tactic = "direct" [
    ;ff-reduce-temperature  ; Direct tactic reduces temperature directly
  ]

  if ff-tactic = "indirect-fuel" [
    ;set-heading
    ff-removefuel
    set ff-temperature-reduction ff-temperature-reduction + 5
    set temp-red temp-red + 5 ;total temperature reduction shows in UI
  ]
  if ff-tactic = "indirect-water" [
    ;set-heading
    ;ff-reduce-temperature
  ]
  if ff-tactic = "indirect-water-standingstill" [

    if ticks = 40 [
      ;set-heading

      ifelse who mod 2 = 0 [ ;if the number is even
        show "i am an even turtle!"
        show heading
        show (word "xcor: " xcor " ycor: " ycor)

        ;show index
      ]
      [
        show "i am an uneven turtle!"
        show heading
        show (word "xcor: " xcor " ycor: " ycor)

      ]
    ]

    ;set index (index + 1)


    ;if tick is start tick
    ;go to the right position
    ;every second time this is run, turn 90 degrees left or right

    ;until the fire comes closer than 300 meters
    ;ff-reduce-temperature
    ;until the patch is <-100 degrees, if it is then
    ;move one step forward, ff-reduce-temperature

  ]

end


to ff-removefuel ;not used
  ask patch-here [
    set patchticks patchticks + 1
    set temperature temperature - 5
    if patchticks >= 150 [
      set pcolor brown] ;every 150 minutes
  ]
end



;---------FIRE----------------

to update-fire
  set total-fires count fires
    set fire-locations []
  ask fires [
    set fire-locations lput (list xcor ycor) fire-locations
  ]

  set-lead-turtles
end

to set-lead-turtles
  ask fires [set label ""]
  set head-fire-turtle median-fire-turtle-by-sector "head";set head-fire-turtle median-head-fire-turtle
  set heel-fire-turtle median-fire-turtle-by-sector "heel"
  set right-fire-turtle median-right-fire-turtle
  set left-fire-turtle median-left-fire-turtle

  if head-fire-turtle != nobody [
    ask head-fire-turtle [ set label "Head" ]]
  if heel-fire-turtle != nobody [ ask heel-fire-turtle [ set label "Heel" ]]
  if right-fire-turtle != nobody [ask right-fire-turtle [ set label "Right" ]]
  if left-fire-turtle != nobody [ask left-fire-turtle [ set label "Left" ]]
end

to-report median-fire-turtle-by-sector [sector-name]
  if not any? fires with [sector = sector-name] [
    report min-one-of fires [who];report one-of fires
  ]
  if not any? fires [user-message (word "no fires")]
  ; Get all turtles in the specified sector
  let sector-turtles fires with [sector = sector-name]
  ; Collect Y values (assuming Y is relevant for both head and heel sectors)
  let y-values [ycor] of sector-turtles
  ; Use NetLogo's median primitive to find the median Y value
  let median-y median y-values
  ; Find the turtle with the Y value closest to the median
  let target-turtle min-one-of sector-turtles [abs(ycor - median-y)]
  report target-turtle
end

to-report median-left-fire-turtle
  if not any? fires with [sector = "left-flank"] [ report one-of fires ] ; If no left sector turtles, exit.
  let left-turtles fires with [sector = "left-flank"]
  let x-values [xcor] of left-turtles
  let median-x median x-values
  let target-turtle min-one-of left-turtles [abs(xcor - median-x)]
  report target-turtle
end

to-report median-right-fire-turtle
  if not any? fires with [sector = "right-flank"] [ report one-of fires ] ; If no left sector turtles, exit.
  let right-turtles fires with [sector = "right-flank"]
  let y-values [ycor] of right-turtles
  let median-y median y-values
  let target-turtle min-one-of right-turtles [abs(ycor - median-y)]
  report target-turtle
end

;---------REPORTS--------------
to-report num-head-fires
  report count fires with [sector = "head"]
end

to-report num-right-flank-fires
  report count fires with [sector = "right-flank"]
end

to-report num-left-flank-fires
  report count fires with [sector = "left-flank"]
end

to-report num-heel-fires
  report count fires with [sector = "heel"]
end

to situation-assessment

  let current-hour-report table:make
  table:put current-hour-report "head" num-head-fires
  table:put current-hour-report "heel" num-heel-fires
  table:put current-hour-report "left-flank" num-left-flank-fires
  table:put current-hour-report "right-flank" num-right-flank-fires

  ; Add the current hour's report to the list of hourly reports
  set hourly-reports lput current-hour-report hourly-reports

  ; Calculate absolute change if it's not the first report
  if length hourly-reports > 1 [
    let last-hour-report item (length hourly-reports - 2) hourly-reports
    let current-change-report table:make
    let current-rel-change-report table:make

    ; Define a list of sectors
    let sectors ["head" "heel" "left-flank" "right-flank"]

    ;use foreach to iterate over the sectors
    foreach sectors [sector2 ->
      let last-count table:get last-hour-report sector2
      let current-count table:get current-hour-report sector2
      let change current-count - last-count  ; Calculate numerical change

      if last-count = 0 [ set last-count 100 ]
      let change-rel change / last-count  ; Calculate relative change

      table:put current-change-report sector2 change
      table:put current-rel-change-report sector2 change-rel
    ]

    ; Add the current change report to the numerical-change-rate list
    set numerical-change-rate lput current-change-report numerical-change-rate
    set relative-change-rate lput current-rel-change-report relative-change-rate
  ]

  print (word "hourly reports: " hourly-reports)
  print (word "numerical change rate: " numerical-change-rate)
  print (word "relative change rate: " relative-change-rate)

  if length hourly-reports > 0 [
    let latest-hour item (length hourly-reports - 1) hourly-reports
    set-current-plot "Fire Spread Sectors"
    set-current-plot-pen "Head"
    set head-fires table:get latest-hour "head"
    plotxy ticks head-fires
    set-current-plot-pen "Heel"
    set heel-fires table:get latest-hour "heel"
    plotxy ticks heel-fires
    set-current-plot-pen "Left"
    set left-fires table:get latest-hour "left-flank"
    plotxy ticks left-fires
    set-current-plot-pen "Right"
    set right-fires table:get latest-hour "right-flank"
    plotxy ticks right-fires
  ]

  ; Assuming the last entries in numerical-change-rate and relative-change-rate lists
  ; contain the latest change information for all sectors
  if length numerical-change-rate > 0 [
    let latest-numerical item (length numerical-change-rate - 1) numerical-change-rate
    let latest-relative item (length relative-change-rate - 1) relative-change-rate

    ; Update the numerical change rate plot
    set-current-plot "Numerical Change Rate of Fires"
    set-current-plot-pen "Head"
    set head-num-change table:get latest-numerical "head"
    plotxy ticks head-num-change
    set-current-plot-pen "Heel"
    set heel-num-change table:get latest-numerical "heel"
    plotxy ticks heel-num-change
    set-current-plot-pen "Left"
    set left-num-change table:get latest-numerical "left-flank"
    plotxy ticks left-num-change
    set-current-plot-pen "Right"
    set right-num-change table:get latest-numerical "right-flank"
    plotxy ticks right-num-change

    ; Update the relative change rate plot
    set-current-plot "Relative Change Rate of Fires"
    set-current-plot-pen "Head"
    set head-rel-change table:get latest-relative "head"
    plotxy ticks head-rel-change
    set-current-plot-pen "Heel"
    set heel-rel-change table:get latest-relative "heel"
    plotxy ticks heel-rel-change
    set-current-plot-pen "Left"
    set left-rel-change table:get latest-relative "left-flank"
    plotxy ticks left-rel-change
    set-current-plot-pen "Right"
    set right-rel-change table:get latest-relative "right-flank"
    plotxy ticks right-rel-change
  ]

  ;check fire close to cities
  let city-patches patches with [pcolor = 25] ;orange
  let closest-fire min-one-of fires [
    min [distance myself] of city-patches
  ]
  if closest-fire != nobody [
    set distance-city-fire min [distance closest-fire] of city-patches
  ]


end
@#$#@#$#@
GRAPHICS-WINDOW
211
12
609
411
-1
-1
2.0
1
10
1
1
1
0
0
0
1
-97
97
-97
97
1
1
1
ticks
30.0

BUTTON
110
344
179
380
go
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

BUTTON
30
344
100
380
setup
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

SWITCH
268
497
394
530
show_image
show_image
1
1
-1000

PLOT
682
191
842
311
Burnt area
Ticks
Hectares
0.0
50.0
0.0
1000.0
true
false
"" ""
PENS
"Hectares" 1.0 0 -16777216 true "" "plot burned-area"

MONITOR
1038
211
1209
256
Million SEK forest_value_loss
forest_value_loss / 1000000
17
1
11

PLOT
14
623
214
772
count fire turtles
NIL
NIL
0.0
10.0
0.0
10.0
true
false
"" ""
PENS
"fire" 1.0 0 -2674135 true "" "plot count fires"

PLOT
7
472
243
622
Fire turtle sectors
NIL
NIL
0.0
10.0
0.0
10.0
true
true
"" ""
PENS
"head" 100.0 0 -2674135 true "" "plot num-head-fires\n"
"left" 100.0 0 -7500403 true "" "plot num-left-flank-fires\n"
"right" 100.0 0 -14070903 true "" "plot num-right-flank-fires\n"
"heel" 100.0 0 -1184463 true "" "plot num-heel-fires"

SLIDER
763
802
935
835
h-turnaroundtime
h-turnaroundtime
1
30
4.0
1
1
NIL
HORIZONTAL

CHOOSER
984
684
1122
729
wind_velocity
wind_velocity
5
0

CHOOSER
983
738
1121
783
wind-angle
wind-angle
45 -45
0

TEXTBOX
639
238
677
257
Burnt
15
0.0
1

TEXTBOX
629
77
667
95
Costs
15
0.0
1

MONITOR
675
65
781
110
Total costs (k SEK)
(( ff-hours * 1800 ) + ( h-hours * 18000 )) / 1000
1
1
11

MONITOR
820
135
925
180
Firefighters Cost
(ff-hours * 1800 )
0
1
11

MONITOR
1001
136
1105
181
Helicopter costs
h-hours * 18000
0
1
11

PLOT
789
10
949
130
ff-costs
NIL
NIL
0.0
10.0
0.0
10.0
true
false
"" ""
PENS
"default" 1.0 0 -16777216 true "" "plot (ff-hours * 1800 )"

PLOT
959
10
1119
130
h-costs
NIL
NIL
0.0
10.0
0.0
10.0
true
false
"" ""
PENS
"default" 1.0 0 -16777216 true "" "plot (h-hours * 18000 )"

MONITOR
726
318
808
363
NIL
burned-area
17
1
11

TEXTBOX
641
401
706
420
General
15
0.0
1

MONITOR
739
383
832
428
Fire CO2 [ton]
burned-area * 170
17
1
11

TEXTBOX
640
528
736
566
Operational\nEffectiveness
15
0.0
1

PLOT
738
501
898
621
temp-red
NIL
NIL
0.0
10.0
0.0
10.0
true
false
"" ""
PENS
"default" 1.0 0 -16777216 true "" "plot temp-red"

TEXTBOX
816
480
966
498
Total
11
0.0
1

PLOT
949
502
1109
622
agents-amounts
NIL
NIL
0.0
10.0
0.0
10.0
true
true
"" ""
PENS
"heli" 1.0 0 -16777216 true "" "plot count helicopters\n"
"firefigh" 1.0 0 -7500403 true "" "plot count firefighters"

PLOT
253
721
453
871
Numerical Change Rate of Fires
NIL
NIL
0.0
10.0
0.0
10.0
true
false
"" ""
PENS
"Head" 1.0 0 -2674135 true "" ""
"Left" 1.0 0 -7500403 true "" ""
"Right" 1.0 0 -14070903 true "" ""
"Heel" 1.0 0 -1184463 true "" ""

PLOT
248
570
448
720
Relative Change Rate of Fires
ticks
NIL
0.0
10.0
0.0
6.0
true
false
"" ""
PENS
"Head" 1.0 0 -2674135 true "" ""
"Left" 1.0 0 -7500403 true "" ""
"Right" 1.0 0 -14070903 true "" ""
"Heel" 1.0 0 -1184463 true "" ""

MONITOR
1039
296
1219
341
House losses (2 per hectare)
house_loss
17
1
11

INPUTBOX
24
78
96
138
agent-amount
4.0
1
0
Number

CHOOSER
761
691
853
736
input-h-location
input-h-location
"left" "right" "head" "heel"
2

CHOOSER
761
737
853
782
input-ff-location
input-ff-location
"left" "right" "head" "heel"
0

CHOOSER
853
693
945
738
h-tactic
h-tactic
"direct" "indirect"
0

CHOOSER
853
741
945
786
ff-tactic
ff-tactic
"direct" "indirect-fuel" "indirect-water"
0

PLOT
466
573
666
723
fire-ext
NIL
NIL
0.0
10.0
0.0
10.0
true
true
"" ""
PENS
"firefighters" 1.0 0 -16777216 true "" "plot ff-fire-ext"
"helictopters" 1.0 0 -7500403 true "" "plot h-fire-ext"

PLOT
472
739
672
889
Fire Spread Sectors
NIL
NIL
0.0
10.0
0.0
10.0
true
true
"" ""
PENS
"Head" 1.0 0 -2674135 true "" ""
"Left" 1.0 0 -7500403 true "" ""
"Right" 1.0 0 -13345367 true "" ""
"Heel" 1.0 0 -1184463 true "" ""

CHOOSER
23
282
189
327
strategy-choice
strategy-choice
"largest-firesector" "largest-rel-change" "spread-agents-equally" "protect-city" "decentralized-decision" "go-around"
1

MONITOR
887
293
1010
338
burned-society-hec
burned-society-hec
17
1
11

INPUTBOX
24
10
115
70
response-time
400.0
1
0
Number

INPUTBOX
23
211
147
271
time-strategy-update
2.0
1
0
Number

INPUTBOX
22
145
177
205
perc-ground
0.5
1
0
Number

@#$#@#$#@
## WHAT IS IT?

This project simulates the spread of a fire through a forest.  It shows that the fire's chance of reaching the right edge of the forest depends critically on the density of trees. This is an example of a common feature of complex systems, the presence of a non-linear threshold or critical parameter.

## HOW IT WORKS

The fire starts on the left edge of the forest, and spreads to neighboring trees. The fire spreads in four directions: north, east, south, and west.

The model assumes there is no wind.  So, the fire must have trees along its path in order to advance.  That is, the fire cannot skip over an unwooded area (patch), so such a patch blocks the fire's motion in that direction.

## HOW TO USE IT

Click the SETUP button to set up the trees (green) and fire (red on the left-hand side).

Click the GO button to start the simulation.

The DENSITY slider controls the density of trees in the forest. (Note: Changes in the DENSITY slider do not take effect until the next SETUP.)

## THINGS TO NOTICE

When you run the model, how much of the forest burns. If you run it again with the same settings, do the same trees burn? How similar is the burn from run to run?

Each turtle that represents a piece of the fire is born and then dies without ever moving. If the fire is made of turtles but no turtles are moving, what does it mean to say that the fire moves? This is an example of different levels in a system: at the level of the individual turtles, there is no motion, but at the level of the turtles collectively over time, the fire moves.

## THINGS TO TRY

Set the density of trees to 55%. At this setting, there is virtually no chance that the fire will reach the right edge of the forest. Set the density of trees to 70%. At this setting, it is almost certain that the fire will reach the right edge. There is a sharp transition around 59% density. At 59% density, the fire has a 50/50 chance of reaching the right edge.

Try setting up and running a BehaviorSpace experiment (see Tools menu) to analyze the percent burned at different tree density levels. Plot the burn-percentage against the density. What kind of curve do you get?

Try changing the size of the lattice (`max-pxcor` and `max-pycor` in the Model Settings). Does it change the burn behavior of the fire?

## EXTENDING THE MODEL

What if the fire could spread in eight directions (including diagonals)? To do that, use `neighbors` instead of `neighbors4`. How would that change the fire's chances of reaching the right edge? In this model, what "critical density" of trees is needed for the fire to propagate?

Add wind to the model so that the fire can "jump" greater distances in certain directions.

Add the ability to plant trees where you want them. What configurations of trees allow the fire to cross the forest? Which don't? Why is over 59% density likely to result in a tree configuration that works? Why does the likelihood of such a configuration increase so rapidly at the 59% density?

The physicist Per Bak asked why we frequently see systems undergoing critical changes. He answers this by proposing the concept of [self-organzing criticality] (https://en.wikipedia.org/wiki/Self-organized_criticality) (SOC). Can you create a version of the fire model that exhibits SOC?

## NETLOGO FEATURES

Unburned trees are represented by green patches; burning trees are represented by turtles.  Two breeds of turtles are used, "fires" and "embers".  When a tree catches fire, a new fire turtle is created; a fire turns into an ember on the next turn.  Notice how the program gradually darkens the color of embers to achieve the visual effect of burning out.

The `neighbors4` primitive is used to spread the fire.

You could also write the model without turtles by just having the patches spread the fire, and doing it that way makes the code a little simpler.   Written that way, the model would run much slower, since all of the patches would always be active.  By using turtles, it's much easier to restrict the model's activity to just the area around the leading edge of the fire.

See the "CA 1D Rule 30" and "CA 1D Rule 30 Turtle" for an example of a model written both with and without turtles.

## RELATED MODELS

* Percolation
* Rumor Mill

## CREDITS AND REFERENCES

https://en.wikipedia.org/wiki/Forest-fire_model

## HOW TO CITE

If you mention this model or the NetLogo software in a publication, we ask that you include the citations below.

For the model itself:

* Wilensky, U. (1997).  NetLogo Fire model.  http://ccl.northwestern.edu/netlogo/models/Fire.  Center for Connected Learning and Computer-Based Modeling, Northwestern University, Evanston, IL.

Please cite the NetLogo software as:

* Wilensky, U. (1999). NetLogo. http://ccl.northwestern.edu/netlogo/. Center for Connected Learning and Computer-Based Modeling, Northwestern University, Evanston, IL.

## COPYRIGHT AND LICENSE

Copyright 1997 Uri Wilensky.

![CC BY-NC-SA 3.0](http://ccl.northwestern.edu/images/creativecommons/byncsa.png)

This work is licensed under the Creative Commons Attribution-NonCommercial-ShareAlike 3.0 License.  To view a copy of this license, visit https://creativecommons.org/licenses/by-nc-sa/3.0/ or send a letter to Creative Commons, 559 Nathan Abbott Way, Stanford, California 94305, USA.

Commercial licenses are also available. To inquire about commercial licenses, please contact Uri Wilensky at uri@northwestern.edu.

This model was created as part of the project: CONNECTED MATHEMATICS: MAKING SENSE OF COMPLEX PHENOMENA THROUGH BUILDING OBJECT-BASED PARALLEL MODELS (OBPML).  The project gratefully acknowledges the support of the National Science Foundation (Applications of Advanced Technologies Program) -- grant numbers RED #9552950 and REC #9632612.

This model was developed at the MIT Media Lab using CM StarLogo.  See Resnick, M. (1994) "Turtles, Termites and Traffic Jams: Explorations in Massively Parallel Microworlds."  Cambridge, MA: MIT Press.  Adapted to StarLogoT, 1997, as part of the Connected Mathematics Project.

This model was converted to NetLogo as part of the projects: PARTICIPATORY SIMULATIONS: NETWORK-BASED DESIGN FOR SYSTEMS LEARNING IN CLASSROOMS and/or INTEGRATED SIMULATION AND MODELING ENVIRONMENT. The project gratefully acknowledges the support of the National Science Foundation (REPP & ROLE programs) -- grant numbers REC #9814682 and REC-0126227. Converted from StarLogoT to NetLogo, 2001.

<!-- 1997 2001 MIT -->
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
NetLogo 6.4.0
@#$#@#$#@
set density 60.0
setup
repeat 180 [ go ]
@#$#@#$#@
@#$#@#$#@
<experiments>
  <experiment name="experiment" repetitions="5" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <metric>burned-area</metric>
    <metric>ff-hours</metric>
    <metric>h-hours</metric>
    <enumeratedValueSet variable="h-turnaroundtime">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="wind-angle">
      <value value="45"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="strategy">
      <value value="&quot;2014&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="show_image">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="wind_velocity">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="response-time">
      <value value="&quot;0&quot;"/>
    </enumeratedValueSet>
  </experiment>
</experiments>
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
