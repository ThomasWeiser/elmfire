-- Basic ElmFire Example App

import Html exposing (Html, div, input, output, label, text, a)
import Html.Events exposing (on, targetValue)
import Html.Attributes exposing (href, target)
import Signal exposing (Signal, Mailbox, mailbox, message)
import Task exposing (Task)
import Json.Encode exposing (string)

import ElmFire exposing
  ( location, set, subscribe, valueChanged, responses
  , Response (..), QueryId, Error
  )

loc = "https://elmfire.firebaseio-demo.com/test"

inputString : Mailbox String
inputString = mailbox ""

port runSet : Signal (Task Error ())
port runSet = Signal.map
  (\str -> set (string str) (location loc))
  inputString.signal

port runQuery : Task Error QueryId
port runQuery = subscribe valueChanged (location loc)

view : Response -> Html
view response =
  let outputText = case response of
    Data dataMsg ->
      Maybe.withDefault "no value" <| Maybe.map toString dataMsg.value
    otherwise -> "no query response"
  in
  div []
  [ text "ElmFire test at: "
  , a [href loc, target "_blank"] [text loc]
  , div []
    [ label []
      [ text "set value: "
      , input [ on "input" targetValue (message inputString.address) ] []
      ]
    ]
  , div []
    [ label []
      [ text "query result: "
      , output [] [ text outputText ]
      ]
    ]
  ]

main = Signal.map view responses
