extensions [ profiler csv ]        ; needed to load Behaviorsearch results

globals [ fishable-patches ]       ; agentset of fishable patches
breed [ xs x ]                     ; use to mark location of protected area
breed [ ports port ]               ; we have only one port, but we could have more
breed [ fishers fisher ]           ; the folks who catch the fish

patches-own [
  biomass                          ; the amount of fish in the patch, in tonnes
]

fishers-own [
  favourite-destination            ; where I think the best fishing spot is
  profits-at-favourite-destination ; how much money I made on last trip to favourite destination
  current-destination              ; where I'm headed now (fishing spot when going out, port when coming back)
  trip-destination                 ; the fishing spot visited in this trip
  trip-costs                       ; accumulating costs for the current trip
  bank-balance                     ; how much money I have in the bank (can be negative)
  biomass-in-hold                  ; how much fish am I currently carrying, in tonnes
]

to setup
  clear-all
  create-ports 1 [
    setxy max-pxcor (max-pycor - (world-height + 1) / 4)
    set color lime
    set shape "house"
  ]
  set fishable-patches patches
  ask patches [ set biomass carrying-capacity / 2 ]
  recolor-patches
  create-fishers number-of-fishers [
    set shape "boat top"
    set color yellow - random-float 3
    move-to one-of ports
    set favourite-destination patch-here
    pick-destination
  ]
  reset-ticks
end

to setup-mpa
  set-default-shape xs "x"
  ask patches with [
    pxcor >= min-mpa-x and
    pxcor <= max-mpa-x and
    pycor >= min-mpa-y and
    pycor <= max-mpa-y and
    not any? ports-here
  ] [
    sprout-xs 1 [ set color [0 0 0 50] ]
  ]
  set fishable-patches fishable-patches with [ not any? xs-here ]
end

to go
  if ticks = 365 * 24 [ setup-mpa ]
  ask fishers [
    set trip-costs trip-costs + hourly-costs
    ifelse patch-here = current-destination [
      ifelse any? ports-here [ dock ] [ fish ]
    ] [
      face current-destination
      forward speed
    ]
  ]
  update-biology
  tick-advance 1
  if update-plots? [ update-plots ]
end

to update-biology
  diffuse biomass diffusion-rate
  recolor-patches
  if ticks mod (15 * 24) = 0 [
    ask patches [
      set biomass biomass + (
        biomass * growth-rate *
        (1 - (biomass / carrying-capacity))
      )
    ]
  ]
end

to pick-destination ; fisher procedure
  ifelse random-float 1 < exploration-probability [
    ; explore:
    let r 1 + random-poisson exploration-radius
    set trip-destination [ one-of fishable-patches in-radius r ] of favourite-destination
  ] [
    let other-fisher one-of other fishers
    let their-profits [ profits-at-favourite-destination ] of other-fisher
    ifelse profits-at-favourite-destination >= their-profits [
      ; exploit:
      set trip-destination favourite-destination
    ] [
      ; imitate
      set trip-destination [ favourite-destination ] of other-fisher
    ]
  ]
  set current-destination trip-destination
end

to dock ; fisher procedure
  let revenues biomass-in-hold * price-of-fish
  set biomass-in-hold 0
  let profits revenues - trip-costs
  set trip-costs 0
  set bank-balance bank-balance + profits
  (ifelse
    trip-destination = favourite-destination [
      set profits-at-favourite-destination profits
    ]
    profits > profits-at-favourite-destination [
      set favourite-destination trip-destination
      set profits-at-favourite-destination profits
    ]
  )
  if [ any? xs-here ] of favourite-destination [
    set favourite-destination min-one-of fishable-patches [
      distance [ favourite-destination ] of myself
    ]
  ]
  pick-destination
end

to fish ; fisher procedure
  set pcolor red
  let biomass-caught biomass * catchability
  set biomass biomass - biomass-caught
  set biomass-in-hold biomass-in-hold + biomass-caught
  set current-destination [ patch-here ] of one-of ports
end

to recolor-patches
  ask patches [
    set pcolor scale-color blue (biomass / 2) carrying-capacity 0
  ]
end

to experiment [ years ]
  if file-exists? "experiment.csv" [ file-delete "experiment.csv" ]
  file-open "experiment.csv"
  file-print csv:to-row (list "experiment" "ticks" "mean_bank_balance_of_fishers" "biomass")
  repeat 10 [
    set min-mpa-x max-pxcor
    set max-mpa-x 0
    set min-mpa-y min-pycor
    set max-mpa-y max-pycor
    run-experiment years "no_mpa"

    set min-mpa-x min-pxcor
    set max-mpa-x 0
    set min-mpa-y min-pycor
    set max-mpa-y max-pycor
    run-experiment years "half_mpa"

    set min-mpa-x min-pxcor
    set max-mpa-x max-pxcor
    set min-mpa-y min-pycor
    set max-mpa-y max-pycor
    run-experiment years "full_mpa"

    load-bsearch-max "mySearchOutput"
    run-experiment years "best_mpa"


  ]
  file-close

end

to run-experiment [ years name ]
  setup
  repeat years * 365 * 24 [
    go
    file-print csv:to-row (list
      name
      ticks
      mean [ bank-balance ] of fishers
      sum [ biomass ] of patches
    )
  ]
end

to reset-parameters
  set number-of-fishers 25
  set carrying-capacity 4000
  set growth-rate 0.1
  set diffusion-rate 0.002
  set exploration-probability 0.2
  set exploration-radius 2
  set price-of-fish 80
  set hourly-costs 50
  set speed 0.5
  set catchability 0.2
  set min-mpa-x max-pxcor
  set max-mpa-x 0
  set min-mpa-y min-pycor
  set max-mpa-y max-pycor
end

to load-bsearch-min [ prefix ]
  load-bsearch prefix [ [r1 r2] -> last r1 < last r2 ]
end

to load-bsearch-max [ prefix ]
  load-bsearch prefix [ [r1 r2] -> last r1 > last r2 ]
end

to load-bsearch [ prefix sort-criteria ]
  let rows csv:from-file word prefix ".finalCheckedBests.csv"
  let headers item 0 rows
  let data first sort-by sort-criteria but-first rows
  foreach range length headers [ i ->
    if last item i headers = "*" [
      let param but-last item i headers
      let value item i data
      print (word "set " param " " value)
      run (word "set " param " " value)
    ]
  ]
end


to-report expected-mean-balance [ n ]
  let balances []
  repeat n [
    setup
    repeat 365 * 24 [ go ]
    set balances lput mean [ bank-balance ] of fishers balances
  ]
  report mean balances
end


to profile
  setup
  profiler:start
  repeat 365 * 24 * 4 [ go ]
  profiler:stop
  print profiler:report
  csv:to-file "profiler_data.csv" profiler:data
  profiler:reset
end
@#$#@#$#@
GRAPHICS-WINDOW
455
10
903
459
-1
-1
40.0
1
10
1
1
1
0
0
0
1
-5
5
-5
5
0
0
1
ticks
30.0

SLIDER
10
300
220
333
carrying-capacity
carrying-capacity
0
10000
4000.0
100
1
T
HORIZONTAL

BUTTON
10
10
110
50
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

SLIDER
10
135
220
168
number-of-fishers
number-of-fishers
2
1000
25.0
1
1
NIL
HORIZONTAL

SLIDER
10
175
220
208
exploration-probability
exploration-probability
0
1
0.03
0.01
1
NIL
HORIZONTAL

SLIDER
235
135
445
168
price-of-fish
price-of-fish
0
500
80.0
1
1
£/T
HORIZONTAL

SLIDER
235
175
445
208
hourly-costs
hourly-costs
0
1000
50.0
10
1
£/h
HORIZONTAL

SLIDER
235
215
445
248
speed
speed
0
1
0.5
0.1
1
patch/h
HORIZONTAL

BUTTON
120
10
220
50
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
420
220
453
catchability
catchability
0
1
0.2
0.01
1
NIL
HORIZONTAL

SLIDER
10
380
220
413
diffusion-rate
diffusion-rate
0
0.01
0.002
0.001
1
NIL
HORIZONTAL

PLOT
910
10
1245
230
Mean bank balance of fishers
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
"default" 1.0 0 -16777216 true "" "plot mean [ bank-balance ] of fishers"
"pen-1" 1.0 0 -7500403 true "" "plot 0"

PLOT
910
240
1245
460
Total biomass
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
"default" 1.0 0 -16777216 true "" "plot sum [ biomass ] of patches"

SLIDER
10
215
220
248
exploration-radius
exploration-radius
0
world-width
10.93
0.01
1
NIL
HORIZONTAL

SLIDER
10
340
220
373
growth-rate
growth-rate
0
1
0.1
0.01
1
NIL
HORIZONTAL

MONITOR
236
58
291
103
year
ticks / (365 * 24)
2
1
11

BUTTON
10
55
110
95
go one year
repeat 365 * 24 [ go ]\n
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
0

SLIDER
235
300
445
333
min-mpa-x
min-mpa-x
min-pxcor
max-pxcor
-5.0
1
1
NIL
HORIZONTAL

SLIDER
235
340
445
373
max-mpa-x
max-mpa-x
min-pxcor
max-pxcor
4.0
1
1
NIL
HORIZONTAL

SLIDER
235
380
445
413
min-mpa-y
min-mpa-y
min-pycor
max-pycor
-4.0
1
1
NIL
HORIZONTAL

SLIDER
235
420
445
453
max-mpa-y
max-mpa-y
min-pycor
max-pycor
4.0
1
1
NIL
HORIZONTAL

BUTTON
120
55
220
95
go four years
repeat 365 * 24 * 4 [ go ]
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
0

BUTTON
235
10
445
50
NIL
reset-parameters
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

TEXTBOX
15
270
165
288
Biology
12
0.0
1

TEXTBOX
240
270
390
288
Marine protected area
12
0.0
1

TEXTBOX
15
105
165
123
Fleet
12
0.0
1

SWITCH
304
65
446
99
update-plots?
update-plots?
1
1
-1000

@#$#@#$#@
## WHAT IS IT?

(a general understanding of what the model is trying to show or explain)

## HOW IT WORKS

(what rules the agents use to create the overall behavior of the model)

## HOW TO USE IT

(how to use the model, including a description of each of the items in the Interface tab)

## THINGS TO NOTICE

(suggested things for the user to notice while running the model)

## THINGS TO TRY

(suggested things for the user to try to do (move sliders, switches, etc.) with the model)

## EXTENDING THE MODEL

(suggested things to add or change in the Code tab to make the model more complicated, detailed, accurate, etc.)

## NETLOGO FEATURES

(interesting or unusual features of NetLogo that the model uses, particularly in the Code tab; or where workarounds were needed for missing features)

## RELATED MODELS

(models in the NetLogo Models Library and elsewhere which are of related interest)

## CREDITS AND REFERENCES

(a reference to the model's URL on the web if it has one, as well as any other necessary credits, citations, and links)
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

boat top
true
0
Polygon -7500403 true true 150 1 137 18 123 46 110 87 102 150 106 208 114 258 123 286 175 287 183 258 193 209 198 150 191 87 178 46 163 17
Rectangle -16777216 false false 129 92 170 178
Rectangle -16777216 false false 120 63 180 93
Rectangle -7500403 true true 133 89 165 165
Polygon -11221820 true false 150 60 105 105 150 90 195 105
Polygon -16777216 false false 150 60 105 105 150 90 195 105
Rectangle -16777216 false false 135 178 165 262
Polygon -16777216 false false 134 262 144 286 158 286 166 262
Line -16777216 false 129 149 171 149
Line -16777216 false 166 262 188 252
Line -16777216 false 134 262 112 252
Line -16777216 false 150 2 149 62

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

sheep
false
15
Circle -1 true true 203 65 88
Circle -1 true true 70 65 162
Circle -1 true true 150 105 120
Polygon -7500403 true false 218 120 240 165 255 165 278 120
Circle -7500403 true false 214 72 67
Rectangle -1 true true 164 223 179 298
Polygon -1 true true 45 285 30 285 30 240 15 195 45 210
Circle -1 true true 3 83 150
Rectangle -1 true true 65 221 80 296
Polygon -1 true true 195 285 210 285 210 240 240 210 195 210
Polygon -7500403 true false 276 85 285 105 302 99 294 83
Polygon -7500403 true false 219 85 210 105 193 99 201 83

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

wolf
false
0
Polygon -16777216 true false 253 133 245 131 245 133
Polygon -7500403 true true 2 194 13 197 30 191 38 193 38 205 20 226 20 257 27 265 38 266 40 260 31 253 31 230 60 206 68 198 75 209 66 228 65 243 82 261 84 268 100 267 103 261 77 239 79 231 100 207 98 196 119 201 143 202 160 195 166 210 172 213 173 238 167 251 160 248 154 265 169 264 178 247 186 240 198 260 200 271 217 271 219 262 207 258 195 230 192 198 210 184 227 164 242 144 259 145 284 151 277 141 293 140 299 134 297 127 273 119 270 105
Polygon -7500403 true true -1 195 14 180 36 166 40 153 53 140 82 131 134 133 159 126 188 115 227 108 236 102 238 98 268 86 269 92 281 87 269 103 269 113

x
false
0
Polygon -7500403 true true 270 75 225 30 30 225 75 270
Polygon -7500403 true true 30 75 75 30 270 225 225 270
@#$#@#$#@
NetLogo 6.3.0
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
<experiments>
  <experiment name="exploration-prob" repetitions="5" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="8760"/>
    <metric>mean [ bank-balance ] of fishers</metric>
    <enumeratedValueSet variable="min-mpa-x">
      <value value="5"/>
    </enumeratedValueSet>
    <steppedValueSet variable="exploration-probability" first="0.01" step="0.01" last="1"/>
    <enumeratedValueSet variable="number-of-fishers">
      <value value="25"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="hourly-costs">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="min-mpa-y">
      <value value="-5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="diffusion-rate">
      <value value="0.002"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="growth-rate">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="price-of-fish">
      <value value="80"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max-mpa-x">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="carrying-capacity">
      <value value="4000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max-mpa-y">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="catchability">
      <value value="0.2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="speed">
      <value value="0.5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="exploration-radius">
      <value value="10.93"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="exploration-radius" repetitions="5" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="8760"/>
    <metric>mean [ bank-balance ] of fishers</metric>
    <enumeratedValueSet variable="min-mpa-x">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="exploration-probability">
      <value value="0.03"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number-of-fishers">
      <value value="25"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="hourly-costs">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="min-mpa-y">
      <value value="-5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="diffusion-rate">
      <value value="0.002"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="growth-rate">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="price-of-fish">
      <value value="80"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max-mpa-x">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="carrying-capacity">
      <value value="4000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max-mpa-y">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="catchability">
      <value value="0.2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="speed">
      <value value="0.5"/>
    </enumeratedValueSet>
    <steppedValueSet variable="exploration-radius" first="1" step="0.1" last="11"/>
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
1
@#$#@#$#@
